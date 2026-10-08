# PyCab Flatpak

Steam Deck Flatpak packaging for PyCab, the PyTrain controller. The Flatpak
installs the `pytrain-ogr-deck` Python distribution rather than building
PyLegacy source. The currently tested PyTrain release is **2.12.0**.

## Requirements

- Steam Deck in Desktop Mode with internet access.
- Flatpak and Git (provided by SteamOS).
- Flatpak Builder from Flathub.
- Access to your PyTrain server on the network.

Install Builder once, if needed:

```bash
flatpak install --user flathub org.flatpak.Builder
```

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

```bash
cd ~/PyCab-Flatpak
git pull
bash install.sh
```

The installer downloads the newest published bundle, updates the user Flatpak, and refreshes the Steam launcher. Existing Steam shortcuts continue pointing to the same launcher path.

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

Release bundles are built by GitHub Actions. Push a version tag such as:

```bash
git tag v2.12.0
git push origin v2.12.0
```

The release workflow builds `dist/PyCab.flatpak`, generates
`PyCab.flatpak.sha256`, and attaches both files to the GitHub Release. Normal
installations then consume that prebuilt bundle.

A local release bundle can also be produced with:

```bash
bash build-release.sh
```

## Packaging notes

The release bundle means an end user's Deck no longer resolves PyPI
dependencies or compiles Tcl/Tk/Python. The bundle itself is still produced
from a manifest whose Python dependency resolution occurs at build time.
`pytrain-ogr-deck` is pinned to 2.12.0, but transitive Python dependencies
are not yet hash-locked. Hash-locking those inputs remains the next
reproducibility improvement.

The Flatpak intentionally grants broad device access: pygame/SDL reads the
Steam virtual controller while PyCab also uses `/dev/hidraw*` for
Steam Deck-specific controls.


## Locked Python dependencies

`requirements-lock.txt` is the exact Python environment installed in the released Flatpak. PyLegacy's `pyproject.toml` remains the source of truth for the dependency ranges supported by PyTrain; this lock records the exact versions selected and tested for PyCab.

For a new PyTrain release, publish `pytrain-ogr-deck` to PyPI first, then deliberately regenerate the lock. `update-lock.sh` uses Docker to resolve dependencies in Linux/x86_64 with Python 3.14.8, matching the Flatpak target rather than the host Mac:

```bash
./update-lock.sh 2.12.1
git diff requirements-lock.txt
```

Build and test the resulting PyCab Flatpak before committing the new lock. Once validated:

```bash
git add requirements-lock.txt
git commit -m "Lock PyCab dependencies for PyTrain 2.12.1"
git push
git tag v2.12.1
git push origin v2.12.1
```

The release workflow refuses to build when the release tag and the locked `pytrain-ogr-deck` version differ, and it verifies that the exact PyTrain version is available on PyPI before starting the Flatpak build.
