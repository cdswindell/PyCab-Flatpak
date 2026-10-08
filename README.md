# PyCab Flatpak

Flatpak packaging for the PyTrain Steam Deck controller (PyCab).

PyCab itself is distributed by the `pytrain-ogr-deck` package on PyPI. This
repository contains only the Flatpak packaging needed to run that package on
SteamOS without modifying the immutable host operating system.

## Build on Steam Deck

```bash
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak

flatpak run org.flatpak.Builder \
    --user \
    --install \
    --force-clean \
    build-dir \
    io.github.cdswindell.PyCab.yml
```

Run from Steam Deck Desktop Mode:

```bash
flatpak run io.github.cdswindell.PyCab
```

## Add PyCab to Steam

SteamOS currently behaves differently when Steam launches the Flatpak command
directly: PyCab can open as a white window even though the same Flatpak runs
normally from a terminal. Use the host-side `pycab-steam` wrapper when adding
PyCab as a non-Steam game.

Install the wrapper:

```bash
install -Dm755 pycab-steam ~/.local/bin/pycab-steam
```

In Steam choose **Games -> Add a Non-Steam Game to My Library**, then configure
the PyCab shortcut as:

```text
Target:         /home/deck/.local/bin/pycab-steam
Start In:       /home/deck/
Launch Options:
```

Under **Properties -> Controller**, set **Override for PyCab** to
**Enable Steam Input**.

With Steam Input enabled, pygame/SDL receives the Steam Deck controls through
Steam's normalized game controller while PyCab can continue reading Deck-specific
controls such as the trackpads through `/dev/hidraw*`.

The prototype deliberately retains broad device access because PyCab uses both
SDL/pygame controller input and direct `/dev/hidraw*` access for Steam Deck
controls.

The build currently allows network access while pip installs
`pytrain-ogr-deck` from PyPI. A production/distributable manifest should
replace this with fixed wheel URLs and SHA-256 hashes.
