# PyCab release automation

PyCab releases package a pinned `pytrain-ogr-deck` version into a prebuilt
Steam Deck Flatpak. Run publication commands on the development Mac; run
installation commands on the Steam Deck. Neither operation requires Docker.

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
`PyCab.flatpak` and `PyCab.flatpak.sha256` to the GitHub Release.

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

On the Steam Deck (Desktop Mode or SSH), pull the latest installer and run:

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

The installer needs `curl`, `python3`, `flatpak`, and `sha256sum`;
**GitHub CLI is not required on the Deck**. It discovers the latest published
GitHub Release, downloads both assets, checks SHA-256, reinstalls the user
Flatpak without deleting persistent data, and prints the installed PyTrain
version. It also accepts the older release checksum format containing an
absolute CI build path.

`install-release.sh` updates the Flatpak only. For a **new Deck**, or to
install/refresh the host-side Steam launcher
`~/.local/bin/pycab-steam`, run `bash install.sh` as described in
[INSTALL_STEAM_DECK.md](INSTALL_STEAM_DECK.md).

Run the GUI from Gaming Mode or a local graphical Deck session, not over SSH.

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

## Environment rules

- Publish: macOS only; requires Git, GitHub CLI (`gh`), curl, and Python 3.
- Install release: SteamOS only; SSH or local console.
- GUI: graphical Steam Deck session.
- Local packaging build: `build-release.sh`; CI uses `release.yml`.
