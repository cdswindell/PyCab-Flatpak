# Installing PyCab on a new Steam Deck

This guide installs the **prebuilt PyCab Flatpak** as a Lionel/PyTrain controller on a new Steam Deck (SteamOS). It does **not** require Docker, a Python virtual environment, PyLegacy source, Flatpak Builder, or compiling software. You need a published [PyCab release](https://github.com/cdswindell/PyCab-Flatpak/releases), internet access, and either a reachable PyTrain server (client mode) or a Lionel Base 3 (server mode). The recommended installer includes automatic Steam Library integration and artwork.

## 1. Prepare the Deck

1. Complete initial SteamOS setup, sign in to Steam, connect to Wi-Fi, and let SteamOS finish updates.
2. Press **STEAM > Power > Switch to Desktop**.
3. Open **Konsole** from the application launcher. All shell commands below run as the default `deck` user; **do not run them with sudo**.
4. Confirm networking and tools:

   ```bash
   whoami                  # normally deck
   curl --version
   unzip -v | head -n 2
   flatpak --version
   ```

   Curl, unzip, and Flatpak are normally available on SteamOS. If a command is missing, stop and resolve that first; do not disable SteamOS's read-only filesystem or use `pacman` just for this installation.

## 2. Optional: enable SSH for administration from your Mac

**SSH is optional.** You can complete every installation step in Konsole on the Deck. SSH is useful if you prefer typing on your Mac or copying logs.

In **Konsole on the Deck**, set a password for the `deck` account if you have not already:

```bash
passwd
```

Type a new password twice; characters will not echo. This is also the password used for administrative actions on the Deck. Use a strong, unique password.

Enable and start the built-in OpenSSH server:

```bash
sudo systemctl enable --now sshd
systemctl is-active sshd
```

The second command should print `active`. No separate SSH package installation is normally necessary.

Find the Deck's IP address on your Wi-Fi network:

```bash
hostname -I
```

Use the appropriate LAN IPv4 address (ignore any unrelated virtual-network addresses). From **Terminal on your Mac**, while on the same reachable network:

```bash
ssh deck@DECK_IP_ADDRESS
```

Replace `DECK_IP_ADDRESS` with the Deck's address. On the first connection, check and accept the host-key prompt if it matches the Deck you intend to access, then enter the `deck` password. You can also configure SSH public-key authentication later.

**Security:** Do not forward port 22 from your router to the Internet. For occasional use, start SSH only when needed with `sudo systemctl start sshd`; stop it with `sudo systemctl stop sshd`. If you enabled it persistently and no longer want that, use `sudo systemctl disable --now sshd`.

## 3. Exit Steam before installing

While in Desktop Mode, select **Steam > Exit** and wait for Steam to close completely. The installer edits Steam's local non-Steam shortcut file; Steam may overwrite those edits if it is running.

Verify in Konsole or over SSH:

```bash
pgrep -a -x steam
```

**No output** means Steam is stopped. Do not terminate the Steam client from an SSH session while it is running in Gaming Mode; switch to Desktop Mode and exit normally first.

## 4. Download and install the complete release bundle

Run these commands **on the Deck**, either in Konsole or over SSH. You do not need to clone the Git repository:

```bash
cd ~
curl -fL -o PyCab-Installer.zip https://github.com/cdswindell/PyCab-Flatpak/releases/latest/download/PyCab-Installer.zip
unzip -o PyCab-Installer.zip
cd PyCab-Installer
bash install-bundle.sh
```

The ZIP includes `PyCab.flatpak`, `PyCab.flatpak.sha256`, `install-bundle.sh`, `pycab-steam`, the Steam shortcut helper, and five artwork assets. The installer:

1. Checks the Flatpak's SHA-256 checksum before installing.
2. Installs PyCab as a **user Flatpak** (no `sudo`).
3. Installs `~/.local/bin/pycab-steam`, the Steam-compatible host launcher.
4. Adds PyCab to **Library > Non-Steam** automatically, preserving existing shortcuts and backing up `shortcuts.vdf`.
5. Installs landscape, portrait, hero, logo, and sidebar icon assets.

If Steam was not closed, the installer **defers** shortcut creation and prints a command to run once Steam is exited. The Flatpak installation itself can still succeed.

If Flatpak reports a missing runtime, check that the Flathub remote is configured, then rerun the bundled installer:

```bash
flatpak remotes
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
bash install-bundle.sh
```

Confirm the installation:

```bash
flatpak info --user io.github.cdswindell.PyCab
test -x ~/.local/bin/pycab-steam && echo "Steam launcher installed"
```

## 5. Start Steam and test PyCab

Restart Steam in Desktop Mode, or choose **Return to Gaming Mode**. Open **Library > Non-Steam > PyCab**. Its artwork and shortcut should already be present; **do not manually add a second shortcut**.

Select **Play**. If Deck controls do not work, open **PyCab > Properties > Controller** and enable **Steam Input**. The shortcut's target should be `/home/deck/.local/bin/pycab-steam`, not `/usr/bin/flatpak`. The host launcher avoids the white Tk window observed with direct Flatpak launching from Steam.

For a separate graphical Desktop Mode test (not over SSH), run:

```bash
flatpak run io.github.cdswindell.PyCab
```

Verify PyCab can connect to your PyTrain server or Base 3, as appropriate. Client and server modes have both been tested on the Steam Deck.

## Select client or server mode using Steam Launch Options

One PyCab installation supports both operating modes. In Steam Desktop Mode, open **PyCab > Properties > Shortcut** and edit **Launch Options**:

| Launch Options | Behavior |
| --- | --- |
| *(empty)* | Existing client mode; connects to a separate PyTrain server. |
| `-base` | Server mode; PyTrain discovers the Base 3 automatically. |
| `-base 192.168.4.100` | Server mode; PyTrain uses the specified Base 3 address (replace with yours). |

The launcher passes PyTrain's native `-base` option (with an optional IP address) for server mode, or uses `-client` when no `-base` option is supplied.

For command-line testing:

```bash
flatpak run io.github.cdswindell.PyCab
flatpak run io.github.cdswindell.PyCab -base
flatpak run io.github.cdswindell.PyCab -base 192.168.4.100
```

Server mode requires a reachable Base 3 and network discovery must work for the automatic option. Client and server modes were validated with PyTrain 2.12.3; verify both again after installing a newer Flatpak.

## 6. Updating an existing Deck

The simplest supported update is to download the latest `PyCab-Installer.zip` again and run `bash install-bundle.sh` as in section 4, **with Steam completely exited**. The installer reinstalls the Flatpak without deleting application data, preserves an existing PyCab shortcut's controller settings, and refreshes its artwork.

If you already have a Git checkout, you can alternatively update from the latest published release:

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

This downloads the latest release Flatpak and checksum, verifies SHA-256, reinstalls the user Flatpak, and refreshes the launcher and Steam integration (when Steam is stopped). The Deck does not need GitHub CLI (`gh`). For a **new Deck**, prefer the self-contained ZIP; `install-release.sh` requires a checkout.

### Verify the unified cache location (PyTrain 2.12.4+)

The Flatpak launcher sets `PYTRAIN_CACHE_DIR` to the persistent application
cache root (normally
`~/.var/app/io.github.cdswindell.PyCab/data/cache`). The cache contains
`engine_images/`, `engine_info/`, and `config/` for accessory configuration.
Existing cache contents survive reinstallations. On a new installation,
PyCab creates the directories as needed.

After installing a release containing PyTrain 2.12.4 or newer, test engine
images, product information, and configured accessories in both client and
server modes. If migrating from a development installation that used a
temporary `~/cache` symlink, remove it **only after** confirming those
features work from persistent Flatpak storage.

## 7. Troubleshooting

- **Steam shortcut missing:** Ensure Steam was completely exited during installation. From the extracted `~/PyCab-Installer` directory, with Steam closed, run `python3 scripts/install-steam-shortcut.py`; then restart Steam.
- **Existing shortcut duplicated:** Do not manually add a new shortcut after the installer has already created one. Remove the unwanted duplicate in Steam.
- **Release download fails (HTTP 404):** Confirm the latest published [GitHub release](https://github.com/cdswindell/PyCab-Flatpak/releases/latest) includes `PyCab-Installer.zip`. A tag alone is not a completed release.
- **Checksum verification fails:** Do not bypass it. Download a fresh ZIP and rerun the installer.
- **Missing Flatpak runtime:** Check `flatpak remotes`, configure Flathub as shown in section 4, and retry.
- **GUI works in Konsole but is white in Steam:** Verify the shortcut's **Target** is `/home/deck/.local/bin/pycab-steam`.
- **Controls do not respond:** Enable **Steam Input** under PyCab's Controller properties and relaunch.
- **Cannot connect to PyTrain:** Check server/Base 3 reachability and Wi-Fi isolation; try a direct IP if discovery is blocked.
- **SSH connection refused:** Check `systemctl is-active sshd` and the Deck's current IP address.
- **Logs:** Run `flatpak run io.github.cdswindell.PyCab` from the Deck's graphical Konsole.

## 8. Removing PyCab

Remove the PyCab non-Steam shortcut from Steam, then uninstall the user Flatpak:

```bash
flatpak uninstall --user io.github.cdswindell.PyCab
rm -f ~/.local/bin/pycab-steam
```

If you have a repository checkout, `bash uninstall.sh` performs those two host-side actions. Application data is retained; Steam artwork may remain in Steam's `grid` directory until removed separately.

For maintainer and developer scripts, see [RELEASE_AUTOMATION.md](RELEASE_AUTOMATION.md#script-reference).

---

**Maintainer note:** GitHub Actions builds the published Flatpak and complete installer ZIP. Digital Dream font redistribution permission must be confirmed before publishing any bundle containing that font.
