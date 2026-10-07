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

The prototype deliberately retains broad device access because PyCab uses both
SDL/pygame controller input and direct `/dev/hidraw*` access for Steam Deck
controls.

The build currently allows network access while pip installs
`pytrain-ogr-deck` from PyPI. A production/distributable manifest should
replace this with fixed wheel URLs and SHA-256 hashes.
