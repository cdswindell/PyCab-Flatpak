# Release automation (development branch)

The release scripts deliberately refuse unsupported hosts.

## Publish from the development Mac

After tagging PyLegacy and publishing both PyPI distributions, sync your local PyCab-Flatpak `master` and run:

```bash
bash publish-release.sh
```

The script selects the highest stable `vX.Y.Z` tag in PyLegacy, verifies both PyPI distributions, regenerates the Linux/x86_64 Python lock on GitHub Actions when needed, commits and pushes the lock, and asks you to type the release tag before pushing it. Pushing the tag triggers `release.yml`, which builds and publishes the GitHub release.

**Do not run this script until the automation changes have been merged to master.** It dispatches the lock workflow on master. This development branch does not publish a release.

For packaging-only changes that retain the latest published PyTrain version, use `bash publish-release.sh --rebuild`. This creates the next immutable PyCab packaging tag (`v2.12.3-1`, `v2.12.3-2`, etc.) while retaining `pytrain-ogr-deck==2.12.3`. Existing tags are never moved.\n\n## Install from Steam Deck SSH or Desktop Mode

```bash
bash install-release.sh
```

This downloads the latest GitHub release, verifies its SHA-256 checksum, reinstalls the Flatpak without deleting persistent application data, and reports the installed PyTrain version. Launch the GUI from Steam Gaming Mode or a local graphical console.

## Environment rules

- Publish: macOS only.
- Install: SteamOS only, either SSH or local console.
- GUI: local graphical Steam Deck session only; never launch it automatically over SSH.

The existing `build-release.sh` remains for packaging development and GitHub Actions. The checksum output has been adjusted to use a relative bundle filename so it can be verified after download.
