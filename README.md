# PyCab Flatpak

**New Steam Deck?** Follow [the complete installation guide](INSTALL_STEAM_DECK.md), including optional SSH setup, Flatpak installation, Steam shortcut configuration, and controller testing.

Steam Deck Flatpak packaging for PyCab, the PyTrain controller. The Flatpak
installs the `pytrain-ogr-deck` Python distribution rather than building
PyLegacy source. The release automation pins the PyTrain version in `requirements-lock.txt`;
the currently packaged release is **2.12.4**.

## Requirements

- Steam Deck running SteamOS, with internet access and enough free storage for the Flatpak and its runtime.
- Access to a Lionel Base 3 (server mode) or reachable PyTrain server (client mode).
- Desktop Mode for exiting Steam during initial installation. The installer itself can run in Konsole or over SSH.

No Git checkout, Python virtual environment, Flatpak Builder, or compilation is needed to install a published release.

## Install on a new Steam Deck (recommended)

Download **`PyCab-Installer.zip`** from the [latest GitHub release](https://github.com/cdswindell/PyCab-Flatpak/releases/latest). It contains the prebuilt Flatpak, checksum, launcher, Steam shortcut helper, and artwork.

**First switch to Desktop Mode and fully exit Steam** (Steam > Exit). This matters: Steam can overwrite changes to its shortcuts while running.

On the Deck, in Konsole or via SSH:

```bash
cd ~
curl -fL -o PyCab-Installer.zip https://github.com/cdswindell/PyCab-Flatpak/releases/latest/download/PyCab-Installer.zip
unzip -o PyCab-Installer.zip
cd PyCab-Installer
bash install-bundle.sh
```

The installer verifies the Flatpak's SHA-256 checksum, installs the user Flatpak and host-side launcher, adds PyCab as a **Non-Steam Game**, and installs the custom Steam artwork. It preserves other shortcuts and backs up `shortcuts.vdf` before modifying it. If Steam is still running, it installs the Flatpak but defers shortcut creation and prints the command to run after exiting Steam.

Restart Steam or return to Gaming Mode, open **Library > Non-Steam > PyCab**, and select **Play**. Under **Properties > Controller**, enable Steam Input if needed. For client/server launch options and SSH setup, see [INSTALL_STEAM_DECK.md](INSTALL_STEAM_DECK.md).

**Do not target `/usr/bin/flatpak` directly from Steam.** The installer configures the tested host launcher at `~/.local/bin/pycab-steam`, avoiding the white-window issue seen with a direct Flatpak Steam shortcut.

## Update an existing installation

For the simplest update, download the latest installer ZIP and rerun `bash install-bundle.sh` **with Steam exited**. The helper updates an existing PyCab shortcut while preserving its controller settings, and refreshes artwork.

If you maintain a checkout of this repository, the network-based release installer is also supported:

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

`install-release.sh` downloads the latest release's Flatpak and checksum, verifies them, reinstalls the application, refreshes the launcher, and configures the shortcut/artwork when Steam is closed. It requires a repository checkout; the ZIP-based installer does not. Both retain Flatpak application data.

## Developer installation and removal

`install.sh` is a **developer/checkout-oriented** alternative, not the recommended first-install procedure. By default it downloads the latest Flatpak without the release checksum verification performed by `install-release.sh` or `install-bundle.sh`. With `--build`, it builds locally using Flatpak Builder.

```bash
# On Steam Deck, from a repository checkout:
bash install.sh --build
```

To uninstall, remove the PyCab shortcut from Steam manually, then run `bash uninstall.sh` from a checkout, or `flatpak uninstall --user io.github.cdswindell.PyCab` if you only have the ZIP. Uninstalling the Flatpak does not remove its application data or Steam artwork automatically.

## Script reference

See [RELEASE_AUTOMATION.md — Script reference](RELEASE_AUTOMATION.md#script-reference) for the purpose, host requirements, and usage of every repository shell script, including the CI build and packaging scripts.

## Creating a release

See [RELEASE_AUTOMATION.md](RELEASE_AUTOMATION.md) for the full workflow.

On the development Mac, after tagging PyLegacy and publishing both PyPI
distributions:

```bash
./publish-release.sh --dry-run
./publish-release.sh
```

The script checks both PyPI distributions, regenerates the Linux dependency
lock if the PyTrain version changed, and asks for explicit confirmation before
pushing the PyCab release tag. GitHub Actions builds and publishes the Flatpak, checksum, and complete `PyCab-Installer.zip`.

For **PyCab packaging-only changes** (documentation, launchers, manifest,
installer, etc.) that do not change PyTrain, commit and push those changes to
`master`, then run:

```bash
./publish-release.sh --rebuild --dry-run
./publish-release.sh --rebuild
```

This creates a new immutable packaging revision such as `v2.12.4-1`
without changing the pinned `pytrain-ogr-deck==2.12.4` version. Never move
an existing release tag.

A developer can also build locally with `bash build-release.sh` on a Linux host with Flatpak Builder.

## Packaging and cache notes

`requirements-lock.txt` pins the exact Linux/x86_64 Python environment used
by GitHub Actions (Python 3.14.8). PyLegacy's `pyproject.toml` specifies the
supported dependency ranges; the Flatpak lock pins the resolved versions.
These are version locks, **not a hash-locked dependency set**.

The Flatpak includes Tcl/Tk, Python, and PyTrain, so installation on the Deck
does not compile them. It grants broad device access so pygame/SDL and
Deck-specific controls can access the required devices.

From PyTrain 2.12.4 onward, the launcher sets `PYTRAIN_CACHE_DIR` to
persistent Flatpak application storage. Engine images, product metadata,
and accessory configuration use its `engine_images/`, `engine_info/`,
and `config/` subdirectories. Raspberry Pi installations without that
variable retain their existing relative cache paths.

## Digital Dream font

The Flatpak build copies Digital Dream TTF files from the installed `pytrain.gui/fonts` Python package into `/app/share/fonts/truetype/pycab`, refreshes fontconfig, and fails if the font is absent or not recognized. Users do not need to install the font on SteamOS.

**Redistribution permission is pending.** Do not publish a new Flatpak bundle containing Digital Dream until the font author grants permission. Retain the author's written permission and attribution alongside the source font in PyLegacy. The existing PyPI package may already contain the font and should be reviewed for compliance.
