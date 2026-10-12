# PyCab release automation

PyCab releases package a pinned `pytrain-ogr-deck` version into a prebuilt
Steam Deck Flatpak. Run publication commands on the development Mac; run
installation commands on the Steam Deck. Neither operation requires Docker.

## Development and validation workflows

**Fast iteration (Conda on Steam Deck):** Edit PyLegacy on the Mac, run tests,
commit and push the changes, then use the Conda-based PyCab update workflow on
the Steam Deck to pull and run that source. For branch work, check out the
corresponding branch in the Deck's PyLegacy checkout before updating. Verify
that the updater preserves the selected branch and updates source rather than
installing a PyPI release. This path avoids a Flatpak rebuild for each GUI
change.

**Flatpak integration test (before publishing):** From the PyCab-Flatpak
checkout on the Mac, run `./build-dev.sh` (or `bash build-dev.sh`).
This dispatches `build-development.yml` using the selected PyCab and PyLegacy
refs (defaults: `master`), waits for CI, and downloads the development
`PyCab.flatpak` and checksum to `dist/`. It does **not** create a tag,
publish to PyPI, or publish a GitHub release. For branch builds, set
`PYCAB_REF` and/or `PYLEGACY_REF` before running it.

Copy the bundle to the Steam Deck and install it there:

```bash
# Mac:
scp dist/PyCab.flatpak deck@steamdeck:~/

# Steam Deck (SSH or Desktop Konsole):
flatpak install --user --reinstall -y ~/PyCab.flatpak
```

The Conda and Flatpak environments should be kept as similar as practical:
Python and package versions, Tk/Tcl, pygame, GuiZero, Pillow, font family
(Noto Sans for the Steam Deck), resource paths, and runtime configuration.
Use the Flatpak build as the final integration check because different Tk
builds can still render widgets differently.

## New PyTrain version

After tagging PyLegacy (numeric tag, for example `2.12.4`) and starting
its PyPI publication workflow, use the PyCab-Flatpak checkout on your Mac:

```bash
git switch master
git pull --ff-only origin master
./publish-release.sh --dry-run
./publish-release.sh
```

The publication script finds the highest stable numeric PyLegacy tag and checks
that **both** `pytrain-ogr` and `pytrain-ogr-deck` exist on PyPI as
non-yanked releases. If either is missing, it stops safely; rerun after the
PyLegacy publication finishes.

If the pinned version has changed, the script dispatches `update-lock.yml`
on GitHub Actions, waits for the Linux/x86_64 Python 3.14.8 lock artifact,
checks its PyTrain version, and updates `requirements-lock.txt`. It shows the
diff, then requires you to type the exact PyCab release tag. On confirmation,
it commits and pushes the updated lock (if changed), creates and pushes the
tag, and triggers `release.yml`. The workflow builds the Flatpak and attaches
`PyCab.flatpak`, `PyCab.flatpak.sha256`, and `PyCab-Installer.zip` to the GitHub Release.

`--dry-run` does not modify files, tags, remote refs, or workflows. It
describes any lock regeneration that would be required.

## Packaging-only rebuild (PyTrain unchanged)

When PyCab-Flatpak files change but PyTrain does not, **do not retag PyLegacy
or overwrite an existing PyCab tag**. Commit and push the packaging changes
to PyCab-Flatpak `master`, then run:

```bash
git switch master
git pull --ff-only origin master
./publish-release.sh --rebuild --dry-run
./publish-release.sh --rebuild
```

`--rebuild` retains the version pinned in `requirements-lock.txt` and
allocates the next unused immutable packaging revision, such as
`v2.12.4-1`, then `v2.12.4-2`. It verifies both PyPI distributions and
asks for the exact new tag before pushing. No lock regeneration is needed
when the pinned PyTrain version is unchanged.

**Important:** A pushed tag is not itself a completed release. Wait for
`release.yml` to succeed and publish its downloadable assets.

```bash
gh run list --repo cdswindell/PyCab-Flatpak --workflow release.yml --limit 5
```

## Install or update on Steam Deck

**Recommended for new users and future updates:** Keep a Git checkout of the packaging repository on the Deck. This allows users to update installation scripts and artwork with `git pull` before installing the latest published Flatpak.

First installation (switch to Desktop Mode and **exit Steam** first):

```bash
cd ~
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak
./install-release.sh
```

Subsequent updates (exit Steam first):

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

`install-release.sh` fetches the latest published release Flatpak and checksum, verifies SHA-256, reinstalls the user Flatpak, reports its PyTrain version, refreshes the host launcher, and installs/updates the Steam shortcut and artwork when Steam is stopped. It supports legacy checksum manifests containing an absolute CI path. GitHub CLI is **not** needed on the Deck, and no compilation is involved.

**Alternative without Git:** Download `PyCab-Installer.zip` from the latest release and run `bash install-bundle.sh` from its extracted directory. Repeat the download for future updates.

The Flatpak can be installed over SSH, but Steam must be exited for shortcut changes and the GUI must be launched from a local graphical session. See [INSTALL_STEAM_DECK.md](INSTALL_STEAM_DECK.md).

## Cache layout

Starting with PyTrain 2.12.4, the Flatpak launcher exports
`PYTRAIN_CACHE_DIR` pointing at the app's persistent data `cache` folder.
The shared root contains `engine_images/`, `engine_info/`, and `config/`.
The default Raspberry Pi relative cache behavior remains unchanged when the
variable is unset. Existing explicit component-specific environment variables
continue to take precedence.

Do not remove any legacy cache symlink used during development until the
newly built Flatpak has been installed and the image, product metadata, and
accessory configuration paths have been verified without it.

## Installation verification and in-app update diagnostics

Published bundles include a matching copy of `pycab-steam` at
`/app/share/pycab/pycab-steam`, plus a text release summary at
`/app/share/pycab/build-info` (PyCab release, pinned PyTrain version,
runtime, user installation, Steam Deck platform).

`install-release.sh` installs the **bundled** host launcher and verifies
the installed release tag, runtime, persistent-working-directory entry
point, and host-launcher identity. It prints build metadata. When Steam
is closed, it also runs the Steam shortcut helper in dry-run mode;
shortcut inspection is deferred while Steam is running.

The Gaming Mode host launcher now records in-app update attempts,
checksum/install results, and relaunch attempts in persistent
`~/.var/app/io.github.cdswindell.PyCab/data/runtime/pycab-update.log`.
After a successful update it atomically replaces the host-side
`~/.local/bin/pycab-steam` with the version bundled in the new Flatpak.
Replacing the file does not interrupt the running Bash process; the
replacement is used on the next Steam launch. Older Flatpaks without a
bundled host launcher leave the current host launcher untouched.

```bash
# Steam Deck, during or after a Gaming Mode update:
tail -f ~/.var/app/io.github.cdswindell.PyCab/data/runtime/pycab-update.log

# Read installed build metadata:
flatpak run --command=cat io.github.cdswindell.PyCab /app/share/pycab/build-info
```

**Rollback:** From the Deck checkout, run `./install-release.sh --version vX.Y.Z-N`
to install a specific previously published stable GitHub release. The script
fetches that release's assets from GitHub, verifies SHA-256, requires typing
the exact requested tag to confirm the downgrade, and verifies the installed
tag. Persistent application data is retained. Older releases without bundled
host launcher or build metadata remain installable; the existing host launcher
is retained in that case. Note that older PyTrain versions might not understand
configuration written by newer versions. Run `./install-release.sh` without
arguments to return to the latest published release.

**Deferred improvement:** Further optimize GitHub Actions Flatpak build times.

## Persistent runtime logs and files

The Flatpak launcher changes PyTrain's working directory to persistent
application data **before** starting Python:

```text
~/.var/app/io.github.cdswindell.PyCab/data/runtime/
    pytrain.log
    pytrain.log.1
    pytrain.log.2
    pytrain.log.3
    pytrain.log.4
```

PyTrain's default logger writes `pytrain.log` relative to the working
directory. On startup it rotates an existing log to `.1` and keeps up to
four backups. The log therefore remains available **during execution and
after PyCab exits**, including after Flatpak updates. The directory is on
the Steam Deck host, outside the sandbox's ephemeral filesystem.

```bash
# Steam Deck (SSH or Desktop Konsole):
tail -f ~/.var/app/io.github.cdswindell.PyCab/data/runtime/pytrain.log
ls -lah ~/.var/app/io.github.cdswindell.PyCab/data/runtime/
```

PyTrain's `.pytrain.history` is also a working-directory-relative file,
but **PyCab runs PyTrain with `-headless`**, and the PyTrain CLI writes
readline history only in interactive mode. Thus the directory is ready for
history if that mode is used, but a normal PyCab session does **not**
produce `.pytrain.history`.

This affects new Flatpak builds only: installing an older already-published
Flatpak does not change its embedded launcher. The existing
`PYTRAIN_CACHE_DIR` layout is unchanged. The runtime directory is not
deleted by a normal application exit or reinstall; deleting Flatpak app
data explicitly would remove it.

## Environment rules

- Publish: macOS only; requires Git, GitHub CLI (`gh`), curl, and Python 3.
- Install release: SteamOS only; SSH or local console.
- GUI: graphical Steam Deck session.
- Local packaging build: `build-release.sh`; CI uses `release.yml`.

## The three primary scripts

For the normal PyCab build, release, and installation workflow, **use these
three scripts**. They are the recommended entry points; the other shell
scripts are supporting build tools or alternative installation methods.

| Script | Run on | When to use it |
| --- | --- | --- |
| **① [`build-dev.sh`](#build-devsh)** | 🍎 **Mac** | Build an **unpublished development Flatpak** for integration testing. |
| **② [`publish-release.sh`](#publish-releasesh)** | 🍎 **Mac** | Publish a **production release** (or packaging-only rebuild with `--rebuild`). |
| **③ [`install-release.sh`](#install-releasesh)** | 🎮 **Steam Deck** | **Install or update the published Flatpak** on the Deck. |

**For routine source changes**, prefer the Conda-first workflow described
above: push PyLegacy changes from the Mac and update the Conda checkout on
the Deck. You do not need any of these three scripts for each edit.

The remaining scripts stay in their current locations deliberately:
`build-release.sh` and `package-installer.sh` are used by CI;
`scripts/environment.sh` is sourced by other scripts; and the alternative
installers remain useful for standalone ZIP distribution or manual recovery.
Moving them to a `legacy/` directory would require updating callers,
packaging paths, and CI workflows without improving the primary workflow.

## Script reference

The table covers **all 11 `.sh` scripts plus the two extensionless shell launchers** in the repository. Platform symbols:
🍎 macOS; 🎮 Steam Deck / SteamOS; 🐧 Linux build host (including GitHub
Actions). The platform indicates the intended execution environment, not
necessarily a strict guard enforced by every script.

| Script | Platform | Purpose |
| --- | --- | --- |
| **[`build-dev.sh`](#build-devsh)** | 🍎 **Mac** | **Development Flatpak build.** Dispatches `build-development.yml` for selected PyCab/PyLegacy refs, waits for completion, and downloads the resulting bundle to `dist/`; no publication. |
| **[`publish-release.sh`](#publish-releasesh)** | 🍎 **Mac only** | **Production release.** Checks tags and PyPI versions, refreshes the dependency lock when needed, and starts the release pipeline. Supports `--dry-run` and packaging-only `--rebuild`. |
| **[`install-release.sh`](#install-releasesh)** | 🎮 **Steam Deck only** | **Recommended production installation/update.** Downloads the latest published Flatpak and checksum, ensures its runtime, installs PyCab, and refreshes the Steam launcher/shortcut. |
| [`build-release.sh`](#build-releasesh) | 🐧 **Linux / GitHub Actions** | Builds and exports the Flatpak with Flatpak Builder; supports prebuilt development wheels and local PyLegacy source overrides. |
| [`update-lock.sh`](#update-locksh) | 🍎 **Mac / maintainer machine with `gh`** | Requests a Linux/x86_64 Python dependency-lock workflow for a specified PyTrain version; prints instructions to download its artifact. |
| [`build-installer-bundle.sh`](#build-installer-bundlesh) | 🍎 **Mac only** | Downloads and verifies the latest published Flatpak and packages it with checkout scripts/artwork as `PyCab-Installer.zip`, without rebuilding the app. |
| [`package-installer.sh`](#package-installersh) | 🐧 **Linux / GitHub Actions** | Verifies an already-built Flatpak and packages it with its checksum, installation scripts, launcher, and artwork into an installer ZIP. |
| [`install-bundle.sh`](#install-bundlesh) | 🎮 **Steam Deck only** | Installs from an extracted standalone installer ZIP, verifies the checksum, and sets up the host launcher and Steam shortcut when Steam is closed. |
| [`install.sh`](#installsh) | 🎮 **Steam Deck / Linux** | Alternative installer: downloads the latest release by default or builds from source with `--build`. **Default download does not verify a checksum**; prefer `install-release.sh`. |
| [`uninstall.sh`](#uninstallsh) | 🎮 **Steam Deck / Linux** | Uninstalls the user Flatpak and host launcher, preserving app data; Steam shortcut removal remains manual. |
| [`scripts/environment.sh`](#scripts-environmentsh) | 🔧 **Mac / Steam Deck (sourced)** | Shared strict platform/session checks, including macOS, SteamOS, and local graphical-console versus SSH. Not intended to run independently. |
| [`pycab-steam`](#pycab-steam) | 🎮 **Steam Deck host** | Steam Gaming Mode launcher; runs Flatpak, handles exit code `42` to relaunch, and performs verified host-side updates when requested. |
| [`pycab-flatpak`](#pycab-flatpak) | 📦 **Inside Flatpak** | Configures Steam Deck/PyTrain environment and persistent cache, then launches PyTrain in client or Base 3 server mode. |

Both extensionless launchers are shell scripts and are described below.
The Python helper `scripts/install-steam-shortcut.py` manages the Steam shortcut,
backs up `shortcuts.vdf`, and installs artwork while Steam is stopped.

## Script options and environment variables

These are the **options implemented by the scripts**, rather than options
supported by underlying tools such as `flatpak` or `gh`. Unless noted,
there are no script-specific environment variable overrides or command
switches. Run scripts from the repository checkout (they resolve their own
directory).

### build-dev.sh

**🍎 Mac · Development Flatpak · Primary**

- **Command switches:** None.
- **`PYCAB_REF`** (default: `master`): PyCab-Flatpak Git ref checked out by
  the development CI workflow.
- **`PYLEGACY_REF`** (default: `master`): PyLegacy Git ref checked out by CI.
- **Output:** `dist/PyCab.flatpak` and `dist/PyCab.flatpak.sha256`.
  Requires an authenticated `gh` CLI; dispatches the workflow from
  PyCab-Flatpak `master` while its inputs select the source refs.

```bash
PYCAB_REF=my-pycab-branch PYLEGACY_REF=my-pylegacy-branch ./build-dev.sh
```

### publish-release.sh

**🍎 Mac only · Production publishing · Primary**

- **`--dry-run`**: Preview release decisions without modifying files,
  committing, tagging, or dispatching workflows.
- **`--rebuild`**: Keep the currently locked PyTrain version and allocate
  the next unused PyCab packaging revision (`vX.Y.Z-N`).
- **Both switches may be combined**; duplicate or unknown switches are errors.
- **Script-specific environment variables:** None. A real publication requires
  clean, synchronized `master`, authenticated `gh`, and `git`, `curl`,
  and `python3`.

```bash
./publish-release.sh --dry-run
./publish-release.sh --rebuild --dry-run
./publish-release.sh --rebuild
```

### install-release.sh

**🎮 Steam Deck only · Published Flatpak installation · Primary**

- **Command switches / script-specific environment variables:** None.
- Always downloads the **latest published GitHub release**, verifies its
  checksum, ensures the Flathub runtime `org.freedesktop.Platform//26.08`,
  reinstalls the user Flatpak, and updates the host launcher. If Steam is
  running, it prints the command to refresh the Steam shortcut after exit.
- Requires SteamOS, `curl`, `python3`, `flatpak`, and `sha256sum`.

```bash
./install-release.sh
```

### build-release.sh

**🐧 Linux / GitHub Actions · Flatpak builder (supporting tool)**

- **Command switches:** None.
- **`PYCAB_PREBUILT_WHEEL=1`**: Use an already staged wheel in
  `dev-wheels/` instead of clearing it; fails if no wheel is present.
  Default: `0`.
- **`PYCAB_PYLEGACY_SOURCE=/path/to/PyLegacy`**: Build a Deck wheel from
  that local checkout into `dev-wheels/` before building the Flatpak.
- **`PYCAB_RELEASE_TAG=vX.Y.Z[-N]`**: Explicit tag embedded in the bundle.
  Without it, the script uses `GITHUB_REF_NAME` if set, otherwise derives
  `vX.Y.Z` from `requirements-lock.txt`.
- Requires Flatpak and Flatpak Builder (native `flatpak-builder` or
  `org.flatpak.Builder`); exports `dist/PyCab.flatpak` and checksum.

```bash
PYCAB_RELEASE_TAG=v2.12.9-1 ./build-release.sh
PYCAB_PYLEGACY_SOURCE=/path/to/PyLegacy PYCAB_RELEASE_TAG=v2.12.9-1 ./build-release.sh
```

### update-lock.sh

**🍎 Mac / any maintainer host with authenticated `gh` · Lock helper**

- **Required positional argument:** PyTrain version, e.g.
  `./update-lock.sh 2.12.9`.
- **Other command switches / script-specific environment variables:** None.
- Dispatches `update-lock.yml`; **does not automatically download or commit**
  the resulting lock. Follow the printed `gh run download` instructions.

### build-installer-bundle.sh

**🍎 Mac only · Standalone ZIP packaging**

- **Command switches / script-specific environment variables:** None.
- Downloads the **latest published** Flatpak, verifies SHA-256, and packages
  it with the **current checkout's** installation scripts and artwork into
  `dist/PyCab-Installer.zip`. Does not rebuild the Flatpak.

### package-installer.sh

**🐧 Linux / GitHub Actions · Installer ZIP packaging**

- **Command switches / script-specific environment variables:** None.
- Requires an existing `dist/PyCab.flatpak` and matching
  `dist/PyCab.flatpak.sha256`; validates them and produces
  `dist/PyCab-Installer.zip`. Uses `sha256sum` and `zip`.

### install-bundle.sh

**🎮 Steam Deck only · Offline/bundled installer**

- **Command switches / script-specific environment variables:** None.
- Run from the extracted installer directory, alongside `PyCab.flatpak`,
  its checksum, and `pycab-steam`. Verifies and installs the bundled Flatpak
  and Steam launcher; shortcut changes require Steam to be closed.

### install.sh

**🎮 Steam Deck / Linux · Alternative installer**

- **`--build`** (first argument): Build and install the Flatpak from the
  local manifest using `org.flatpak.Builder`.
- **No argument:** Download and install the latest published Flatpak.
  **This path does not verify a checksum**; prefer `install-release.sh`.
- **Script-specific environment variables:** None. Other arguments are not
  explicitly validated; only a first argument of `--build` changes behavior.

```bash
./install.sh
./install.sh --build
```

### uninstall.sh

**🎮 Steam Deck / Linux · Uninstall helper**

- **Command switches / script-specific environment variables:** None.
- Removes the user Flatpak and `~/.local/bin/pycab-steam` but **retains
  application data**. Remove the Steam Library shortcut manually.

### scripts/environment.sh

**🔧 Sourced library · Platform guards**

- **Command switches:** None; this file defines functions, not a standalone
  command-line interface.
- **`pycab_require_mac`**: Requires macOS (`uname -s = Darwin`).
- **`pycab_require_deck`**: Requires Linux with SteamOS identification in
  `/etc/os-release`.
- **`pycab_require_deck_console`**: Additionally requires a local graphical
  session. Rejects sessions with `SSH_CONNECTION` or `SSH_TTY` set, or
  without either `DISPLAY` or `WAYLAND_DISPLAY`.
- These session environment variables are **inspected**, not supported
  user overrides for bypassing checks.

### pycab-steam

**🎮 Steam Deck host · Steam Gaming Mode launcher**

- **Command switches:** No launcher-specific switches. Arguments are passed
  unchanged to `flatpak run io.github.cdswindell.PyCab`, ultimately reaching
  `pycab-flatpak`.
- **Script-specific environment variables:** None. Uses `HOME` to locate
  the persistent update request marker at
  `~/.var/app/io.github.cdswindell.PyCab/data/pycab-update-request`.
- **Behavior:** Launches the Flatpak in a loop. Exit status `42` requests
  relaunch; if the update marker is present, the launcher consumes it,
  downloads the latest stable release and checksum, verifies SHA-256, and
  reinstalls the user Flatpak before relaunching. On an update failure, it
  relaunches the existing installation. On a normal exit, it removes any
  stale update request and returns the application's exit status.
- **Requirements:** Host-side `flatpak`, `curl`, `python3`, and
  `sha256sum`. Steam's shortcut normally invokes this launcher; it is
  not a release publishing or development build script.

### pycab-flatpak

**📦 Inside Flatpak · Application entry-point launcher**

- **Command switches:** `-base [IP]` starts Base 3 **server mode**;
  without `-base`, starts **client mode**. Any remaining arguments are
  forwarded to `/app/bin/pytrain`. `-base` is recognized **only as the
  first argument**.
- **`PYTRAIN_PLATFORM=steamdeck`**: Set by the launcher to select Steam
  Deck behavior.
- **`PYTRAIN_DISABLE_SELF_UPDATE=1`**: Set to prevent in-sandbox updates;
  the host-side launcher/installer handles Flatpak replacement.
- **`PYTHONUNBUFFERED=1`**: Set for immediate Python output.
- **`LD_PRELOAD`**: Explicitly unset to avoid incompatible host preloads.
- **`XDG_DATA_HOME`**: If set, determines the persistent cache root;
  otherwise defaults to
  `$HOME/.var/app/io.github.cdswindell.PyCab/data`. The script creates
  `cache/engine_images`, `cache/engine_info`, and `cache/config`.
- **`PYTRAIN_CACHE_DIR`**: Set to that cache root's `cache` directory,
  shared by client and server modes. An inherited value is overwritten.
- **Working directory**: Changed to persistent `runtime/` beneath the same
  application data root before launching Python, so `pytrain.log` survives
  restarts and is accessible from the Steam Deck host.
- Both modes invoke `/app/bin/pytrain -headless` and load
  `/app/share/pycab/buttons.py`. These are runtime launch options, not
  switches for building or publishing PyCab.

```bash
# Arguments passed to the Flatpak entry point:
flatpak run io.github.cdswindell.PyCab
flatpak run io.github.cdswindell.PyCab -base
flatpak run io.github.cdswindell.PyCab -base 192.168.4.100
```

**Launch chain:** Steam shortcut → `pycab-steam` (SteamOS host) →
`flatpak run` → `pycab-flatpak` (sandbox) → `/app/bin/pytrain`.

### GitHub Actions workflows

- `.github/workflows/build-development.yml`: Builds an unpublished development Flatpak from selected PyCab/PyLegacy refs and uploads a downloadable workflow artifact; no tag or release.
- `.github/workflows/release.yml`: Validates tagged release/version lock, installs Flatpak build prerequisites, runs `build-release.sh` and `package-installer.sh`, uploads CI artifacts, and publishes all three release assets for tags.
- `.github/workflows/update-lock.yml`: Resolves pinned Linux/x86_64 Python dependencies and uploads `requirements-lock.txt` as a workflow artifact.

### Steam shortcut behavior

Both `install-bundle.sh` and `install-release.sh` call the shortcut helper only when Steam is **not running**. Otherwise they print the manual follow-up command. Never edit `shortcuts.vdf` while Steam is running. Existing PyCab shortcuts and their controller settings are preserved when possible; other Steam shortcuts are not intentionally modified. The helper installs custom landscape, portrait, hero, and logo images plus the sidebar icon.

### Tested release baseline

`v2.12.4-3` (PyTrain `2.12.4`) was successfully built and installed from the complete ZIP via SSH on a Steam Deck, automatically created its Steam Library entry, displayed the custom artwork, and launched from Gaming Mode.
