#!/usr/bin/env python3
"""Safely add PyCab to Steam's non-Steam library (Steam must be exited)."""
import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
import zlib

APP = "PyCab"
APP_ID = "io.github.cdswindell.PyCab"
HOME = Path.home()
LAUNCHER = HOME / ".local/bin/pycab-steam"
ICON = HOME / f".local/share/flatpak/exports/share/icons/hicolor/512x512/apps/{APP_ID}.png"


def read_cstr(raw, offset):
    end = raw.find(b"\0", offset)
    if end < 0:
        raise ValueError("Unterminated VDF string")
    return raw[offset:end].decode("utf-8", "surrogateescape"), end + 1


def parse(raw, offset=0):
    fields = []
    while offset < len(raw):
        kind = raw[offset]
        offset += 1
        if kind == 8:
            return fields, offset
        key, offset = read_cstr(raw, offset)
        if kind == 0:
            value, offset = parse(raw, offset)
        elif kind == 1:
            value, offset = read_cstr(raw, offset)
        elif kind == 2:
            if offset + 4 > len(raw):
                raise ValueError("Truncated VDF integer")
            value = raw[offset:offset + 4]
            offset += 4
        elif kind == 7:
            if offset + 8 > len(raw):
                raise ValueError("Truncated VDF uint64")
            value = raw[offset:offset + 8]
            offset += 8
        else:
            raise ValueError(f"Unsupported VDF type {kind}; no changes made")
        fields.append((kind, key, value))
    raise ValueError("Unterminated VDF object")


def encode(fields):
    result = bytearray()
    for kind, key, value in fields:
        result.append(kind)
        result += key.encode("utf-8", "surrogateescape") + b"\0"
        if kind == 0:
            result += encode(value)
        elif kind == 1:
            result += value.encode("utf-8", "surrogateescape") + b"\0"
        else:
            result += value
    return bytes(result) + b"\x08"


def string(fields, name):
    return next((value for kind, key, value in fields if kind == 1 and key.lower() == name.lower()), None)


def shortcut_id(exe, name):
    return (zlib.crc32((exe + name).encode("utf-8")) | 0x80000000) & 0xffffffff


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0:
        sys.exit("Steam is running. Choose Steam > Exit, then rerun.")
    if not LAUNCHER.is_file() or not ICON.is_file():
        sys.exit(f"Missing launcher or Flatpak icon: {LAUNCHER}, {ICON}")

    configs = sorted(p for p in (HOME / ".local/share/Steam/userdata").glob("*/config")
                     if p.parent.name.isdigit())
    if len(configs) != 1:
        sys.exit(f"Expected one Steam user configuration; found {len(configs)}. No changes made.")
    config = configs[0]
    path = config / "shortcuts.vdf"
    raw = path.read_bytes() if path.exists() else b"\x00shortcuts\x00\x08"
    header = b"\x00shortcuts\x00"
    if not raw.startswith(header):
        sys.exit("Unknown Steam shortcuts format; no changes made.")
    try:
        entries, end = parse(raw, len(header))
        if raw[end:] not in (b"", b"\\x08") or any(kind != 0 for kind, _, _ in entries):
            raise ValueError("Unexpected shortcut structure")
        matches = [(key, fields) for _, key, fields in entries
                   if string(fields, "appname") == APP]
        if len(matches) > 1:
            raise ValueError("Multiple PyCab shortcuts found; no changes made")
    except ValueError as exc:
        sys.exit(f"Cannot safely edit Steam shortcuts: {exc}")

    if matches:
        fields = matches[0][1]
        appid_field = next((value for kind, key, value in fields
                            if kind == 2 and key.lower() == "appid"), None)
        if appid_field is None:
            sys.exit("Existing PyCab shortcut has no appid; no changes made.")
        appid = struct.unpack("<I", appid_field)[0]
        print("Existing PyCab shortcut found; preserving shortcut and controller settings.")
    else:
        exe = f'"{LAUNCHER}"'
        appid = shortcut_id(exe, APP)
        index = str(max((int(key) for _, key, _ in entries), default=-1) + 1)
        def s(key, value):
            return (1, key, value)
        def n(key, value):
            return (2, key, struct.pack("<I", value))
        fields = [
            n("appid", appid), s("appname", APP), s("exe", exe),
            s("StartDir", f'"{HOME}"'), s("icon", str(ICON)),
            s("ShortcutPath", ""), s("LaunchOptions", ""),
            n("IsHidden", 0), n("AllowDesktopConfig", 1),
            n("AllowOverlay", 1), n("OpenVR", 0), n("Devkit", 0),
            s("DevkitGameID", ""), n("DevkitOverrideAppID", 0),
            n("LastPlayTime", 0), (0, "tags", []),
        ]
        entries.append((0, index, fields))
        print("Adding PyCab as a non-Steam game.")

    artwork = config / "grid" / f"{appid}p.png"
    if args.dry_run:
        print(f"DRY RUN: shortcut file {path}; artwork {artwork}")
        return
    if not matches:
        if path.exists():
            backup = path.with_name(f"shortcuts.vdf.backup-{int(time.time())}")
            shutil.copy2(path, backup)
            print(f"Backup: {backup}")
        temp = path.with_name("shortcuts.vdf.pycab-tmp")
        try:
            temp.write_bytes(header + encode(entries) + raw[end:])
            os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)
    artwork.parent.mkdir(parents=True, exist_ok=True)
    if not artwork.exists():
        shutil.copy2(ICON, artwork)
    print("Steam shortcut and grid artwork ready. Restart Steam.")
    print("In Steam: PyCab > Properties > Controller > Enable Steam Input, if needed.")


if __name__ == "__main__":
    main()
