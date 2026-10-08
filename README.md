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

```bash
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak
bash install.sh
```

The installer builds and installs the Flatpak for your user and installs
`~/.local/bin/pycab-steam`, the host-side Steam launcher. Tcl, Tk, and
Python are compiled inside the Flatpak build; the first build may take time.
You do not need a host Python environment or a PyLegacy checkout.

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

The installer reinstalls the user Flatpak and refreshes the Steam launcher.
Existing Steam shortcuts continue pointing to the same launcher path.

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

## Packaging notes

The Flatpak currently allows network access during its build to resolve
Python dependencies from PyPI. The top-level package is pinned to
`pytrain-ogr-deck==2.12.0`, **but transitive dependencies are not yet
hash-locked**. This is a working repeatable source-build installer, not yet a
fully offline/reproducible binary distribution. The next packaging milestone
is a complete platform-specific wheel lock and prebuilt Flatpak bundle.

The Flatpak intentionally grants broad device access: pygame/SDL reads the
Steam virtual controller while PyCab also uses `/dev/hidraw*` for
Steam Deck-specific controls.
