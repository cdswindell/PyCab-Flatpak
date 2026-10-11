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

**Recommended for new users:** Download the latest release's `PyCab-Installer.zip` and run `bash install-bundle.sh` from its extracted `PyCab-Installer/` directory. Exit Steam fully first. This installs the Flatpak, creates the Steam Library shortcut, and installs all custom artwork without requiring a Git checkout. See [INSTALL_STEAM_DECK.md](INSTALL_STEAM_DECK.md).

For maintainers with an existing checkout, the network-based installer is also supported:

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

It downloads the latest published Flatpak and checksum, verifies SHA-256, reinstalls the user Flatpak, prints the installed PyTrain version, refreshes the host launcher, and invokes Steam shortcut/artwork integration when Steam is stopped. GitHub CLI is **not** required on the Deck. It supports legacy release checksum manifests containing an absolute CI path.

The Flatpak app may be installed over SSH. Steam must be exited for automatic shortcut creation; run the GUI in a local graphical Deck session, not SSH.

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

## Script reference

The scripts below are in the repository root unless a subdirectory is shown. **Normal users should use the release ZIP and `install-bundle.sh`**, not the developer build tools.

| Script | Runs on | Purpose |
| --- | --- | --- |
| `install-bundle.sh` | Steam Deck (Desktop Mode/SSH) | **Recommended release ZIP installer.** Verifies bundled SHA-256, installs/reinstalls the user Flatpak, installs host launcher, creates or refreshes Steam shortcut and artwork if Steam is closed. |
| `install-release.sh` | Steam Deck (repository checkout) | Fetches latest published Flatpak and checksum from GitHub Releases, verifies, installs, reports PyTrain version, refreshes launcher and Steam integration. |
| `install.sh` | Steam Deck (repository checkout) | Alternative development installer: downloads latest Flatpak by default; `--build` builds/installs from source with Flatpak Builder. **Default download does not verify a checksum**; prefer the two installers above. |
| `uninstall.sh` | Steam Deck (repository checkout) | Removes user Flatpak and host launcher; retains app data; instructs user to remove Steam shortcut manually. |
| `pycab-steam` | Steam Deck (Steam launcher) | Host-side shell launcher for `flatpak run io.github.cdswindell.PyCab`; Steam shortcut targets this file to avoid white Tk windows. |
| `scripts/install-steam-shortcut.py` | Steam Deck (Steam exited) | Python helper, not a shell script: safely adds/updates PyCab non-Steam shortcut, backs up `shortcuts.vdf`, preserves other entries/controller settings, installs artwork; supports `--dry-run`. |
| `scripts/environment.sh` | Sourced by scripts | Shared macOS/SteamOS and local graphical-console checks; not meant to be run independently. |
| `publish-release.sh` | macOS (maintainer) | Checks versions/PyPI, regenerates dependency lock via CI if needed, confirms and pushes immutable release tag; `--rebuild` creates a new packaging revision; `--dry-run` previews. |
| `update-lock.sh` | Maintainer machine with `gh` | Manually dispatches Linux Python dependency-lock workflow for a specified PyTrain version; instructions explain how to retrieve the generated artifact. |
| `build-release.sh` | Linux CI/developer build host | Builds Flatpak from manifest, retries transient failures, writes `dist/PyCab.flatpak` and SHA-256 manifest. Requires Flatpak Builder/runtime. |
| `package-installer.sh` | Linux CI/developer build host | Takes built Flatpak/checksum, validates them, adds installer scripts, host launcher and artwork, produces `dist/PyCab-Installer.zip`. |
| `build-installer-bundle.sh` | macOS (optional) | Downloads/verifies the latest published Flatpak and repackages it with **local checkout** scripts/artwork into a standalone ZIP. Not the main CI release path. |

### GitHub Actions workflows

- `.github/workflows/release.yml`: Validates tagged release/version lock, installs Flatpak build prerequisites, runs `build-release.sh` and `package-installer.sh`, uploads CI artifacts, and publishes all three release assets for tags.
- `.github/workflows/update-lock.yml`: Resolves pinned Linux/x86_64 Python dependencies and uploads `requirements-lock.txt` as a workflow artifact.

### Steam shortcut behavior

Both `install-bundle.sh` and `install-release.sh` call the shortcut helper only when Steam is **not running**. Otherwise they print the manual follow-up command. Never edit `shortcuts.vdf` while Steam is running. Existing PyCab shortcuts and their controller settings are preserved when possible; other Steam shortcuts are not intentionally modified. The helper installs custom landscape, portrait, hero, and logo images plus the sidebar icon.

### Tested release baseline

`v2.12.4-3` (PyTrain `2.12.4`) was successfully built and installed from the complete ZIP via SSH on a Steam Deck, automatically created its Steam Library entry, displayed the custom artwork, and launched from Gaming Mode.
