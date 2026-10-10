# PyCab Flatpak

**New Steam Deck?** Follow [the complete installation guide](INSTALL_STEAM_DECK.md), including optional SSH setup, Flatpak installation, Steam shortcut configuration, and controller testing.

Steam Deck Flatpak packaging for PyCab, the PyTrain controller. The Flatpak
installs the `pytrain-ogr-deck` Python distribution rather than building
PyLegacy source. The release automation pins the PyTrain version in `requirements-lock.txt`;
the currently packaged release is **2.12.4**.

## Requirements

- Steam Deck in Desktop Mode with internet access.
- Flatpak and Git (provided by SteamOS).
- Access to your PyTrain server on the network.

Flatpak Builder is needed only for the optional developer source build (`bash install.sh --build`), not for installing a published release.

## Install

For normal installations, clone this small packaging repository and run the
installer:

```bash
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak
bash install.sh
```

The installer downloads the latest prebuilt `PyCab.flatpak` from GitHub
Releases, installs it for the current user, and installs the host-side Steam
launcher at `~/.local/bin/pycab-steam`. The Deck does **not** compile Tcl,
Tk, Python, or PyTrain during a normal install.

Developers can still force the validated local source build:

```bash
bash install.sh --build
```

Test in Desktop Mode:

```bash
flatpak run io.github.cdswindell.PyCab
```

### Add to Steam

In Desktop Mode, choose **Steam > Games > Add a Non-Steam Game to My Library**.
Add a shortcut for PyCab (you may add any executable initially) and set its
Properties > Shortcut fields to:

```text
Name:           PyCab
Target:         /home/deck/.local/bin/pycab-steam
Start In:       /home/deck/
Launch Options: (empty)
```

Under **Properties > Controller**, set **Override for PyCab** to
**Enable Steam Input**. Launch from Steam Desktop Mode, then Gaming Mode.

**Important:** Do not use `/usr/bin/flatpak` directly as the Steam shortcut
target. On the tested Deck, that launch path produced a white Tk window. The
host-side shell launcher is the verified workaround.

## Update

To update an existing Flatpak installation to the latest **published** release,
use the checksum-verifying installer (GitHub CLI is not required on the Deck):

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

This verifies `PyCab.flatpak.sha256`, reinstalls the user Flatpak without
deleting app data, and reports the installed PyTrain version. The existing
Steam shortcut remains valid. For a first-time install or to refresh the
host-side `pycab-steam` launcher, use `bash install.sh` instead.

## Uninstall / clean-install test

First, in Steam Desktop Mode, remove the **PyCab** non-Steam shortcut from
your library. This is a Steam library action, not a Flatpak operation.

From the PyCab-Flatpak checkout:

```bash
bash uninstall.sh
```

This uninstalls only the **user** installation of
`io.github.cdswindell.PyCab` and removes
`~/.local/bin/pycab-steam`. It does not delete application data or remove
Flatpak Builder, SDKs, runtimes, source files, or any old PyLegacy environment.

Verify removal:

```bash
flatpak list --app --user | grep io.github.cdswindell.PyCab || echo "PyCab is not installed"
test ! -e ~/.local/bin/pycab-steam && echo "Steam launcher removed"
```

For a clean-install test, run `bash install.sh` again, recreate the Steam
shortcut, enable Steam Input, and test in Gaming Mode. Avoid deleting app data
until you've decided whether you want to preserve configuration.

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
pushing the PyCab release tag. GitHub Actions builds and publishes the Flatpak.

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

A developer can also build locally with `bash build-release.sh`.

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
