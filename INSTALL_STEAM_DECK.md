# Installing PyCab on a new Steam Deck

This guide installs the **prebuilt PyCab Flatpak** as a Lionel/PyTrain controller on a new Steam Deck (SteamOS). It does **not** require Docker, a Python virtual environment, PyLegacy source, Flatpak Builder, or compiling software. You need a published [PyCab release](https://github.com/cdswindell/PyCab-Flatpak/releases), internet access, and either a reachable PyTrain server (client mode) or a Lionel Base 3 (server mode). The recommended Git-based installer includes automatic Steam Library integration and artwork and makes future updates straightforward.

## 1. Prepare the Deck

1. Complete initial SteamOS setup, sign in to Steam, connect to Wi-Fi, and let SteamOS finish updates.
2. While in **Gaming Mode**, press the physical **STEAM** button on the left side of the Steam Deck.
3. Select **Power**.
4. Select **Switch to Desktop** and wait for the KDE desktop to load. This is the Linux desktop, not a separate SteamOS installation.

   <img src="docs/images/switch-to-desktop.jpg" alt="Steam Deck Power menu showing Switch to Desktop" width="360">

5. Click or tap the **application launcher** at the bottom-left of the desktop and open **Konsole** (the terminal). You can use the touchscreen, trackpads, or a connected keyboard/mouse. All shell commands below run as the default `deck` user; **do not run them with sudo**.
6. Confirm networking and tools:

   ```bash
   whoami                  # normally deck
   git --version
   curl --version
   flatpak --version
   ```

   Git, curl, and Flatpak are normally available on SteamOS. If a command is missing, stop and resolve that first; do not disable SteamOS's read-only filesystem or use `pacman` just for this installation.

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

While in Desktop Mode, open the **Steam desktop app's menu** (not the physical STEAM button menu), select **Steam > Exit**, and wait for Steam to close completely. The installer edits Steam's local non-Steam shortcut file; Steam may overwrite those edits if it is running.

Verify in Konsole or over SSH:

```bash
pgrep -a -x steam
```

**No output** means Steam is stopped. Do not terminate the Steam client from an SSH session while it is running in Gaming Mode; switch to Desktop Mode and exit normally first.

## 4. Clone the repository and install the latest release (recommended)

Run these commands **on the Deck**, either in Konsole or over SSH:

```bash
cd ~
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak
./install-release.sh
```

Cloning this repository downloads the installation scripts and Steam artwork; it **does not compile PyTrain**. The script:

1. Finds the latest **published** PyCab GitHub release and downloads its prebuilt Flatpak and checksum.
2. Verifies SHA-256 before installing.
3. Installs PyCab as a **user Flatpak** (no `sudo`), retaining existing application data.
4. Installs the host launcher at `~/.local/bin/pycab-steam`.
5. Automatically adds PyCab to **Library > Non-Steam** and installs its custom artwork if Steam is fully closed. It backs up `shortcuts.vdf` and preserves other shortcuts.

If Steam is running, the Flatpak installs but shortcut creation is deferred. Exit Steam completely and run the printed `python3 scripts/install-steam-shortcut.py` command.

If Flatpak reports a missing runtime, check the Flathub remote and retry:

```bash
flatpak remotes
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
./install-release.sh
```

Verify installation:

```bash
flatpak info --user io.github.cdswindell.PyCab
test -x ~/.local/bin/pycab-steam && echo "Steam launcher installed"
```

### Alternative: standalone installer ZIP

Users who prefer not to use Git can download the latest release's `PyCab-Installer.zip`, extract it, and run `bash install-bundle.sh` (with Steam exited):

```bash
cd ~
curl -fL -o PyCab-Installer.zip https://github.com/cdswindell/PyCab-Flatpak/releases/latest/download/PyCab-Installer.zip
unzip -o PyCab-Installer.zip
cd PyCab-Installer
bash install-bundle.sh
```

This also verifies the checksum, installs the Flatpak, creates the shortcut, and installs artwork. Updating later requires downloading a new ZIP, whereas the recommended Git approach only requires `git pull` and rerunning `install-release.sh`.

## 5. Start Steam and test PyCab

Restart Steam in Desktop Mode, or choose **Return to Gaming Mode**. Open **Library > Non-Steam > PyCab**. Its artwork and shortcut should already be present; **do not manually add a second shortcut**.

Select **Play**. If Deck controls do not work, open **PyCab > Properties > Controller** and enable **Steam Input**. The shortcut's target should be `/home/deck/.local/bin/pycab-steam`, not `/usr/bin/flatpak`. The host launcher avoids the white Tk window observed with direct Flatpak launching from Steam.

For a separate graphical Desktop Mode test (not over SSH), run:

```bash
flatpak run io.github.cdswindell.PyCab
```

Verify PyCab can connect to your PyTrain server or Base 3, as appropriate. Client and server modes have both been tested on the Steam Deck; see the recommended architecture and server-mode options below.

## Client and server modes

**Recommended: client mode with a dedicated PyTrain server.** Leave Steam's **PyCab > Properties > Shortcut > Launch Options** empty (the default). PyCab then connects to a separate PyTrain server. For the most complete Lionel control setup, run that server on a dedicated computer (such as a Raspberry Pi) connected to **both the Lionel Base 3 over Wi-Fi/network and an LCS Ser2 over USB**. This arrangement avoids relying on the Base 3 alone for functions that require the LCS connection and keeps the Steam Deck focused on being a handheld controller.

**Alternative: run PyCab in server mode on the Steam Deck.** In Steam, open **PyCab > Properties > Shortcut** and set **Launch Options** to:

| Launch Options | Mode |
| --- | --- |
| *(empty)* | **Client (recommended):** connect to your separate PyTrain server. |
| `-base` | **Server:** connect to a Base 3 discovered on the network. |
| `-base 192.168.4.100` | **Server:** connect to a Base 3 at that IP address (replace with yours). |

The Deck must be able to reach the Base 3; automatic discovery also requires compatible network settings. A Deck running server mode with only a Base 3 connection may not offer the same coverage as a dedicated server with both Base 3 and LCS Ser2 connections.

For a local graphical Konsole test (not over SSH):

```bash
flatpak run io.github.cdswindell.PyCab              # client mode
flatpak run io.github.cdswindell.PyCab -base        # server; discover Base 3
flatpak run io.github.cdswindell.PyCab -base 192.168.4.100  # server; specific Base 3
```

## 6. Updating an existing Deck

When a new PyCab release is published, switch to Desktop Mode, **exit Steam completely**, and run (locally or over SSH):

```bash
cd ~/PyCab-Flatpak
git pull --ff-only origin master
./install-release.sh
```

`git pull` retrieves the latest installer scripts and artwork. `install-release.sh` downloads and verifies the latest published Flatpak, reinstalls it without deleting application data, and refreshes the Steam shortcut and artwork while preserving existing controller settings. GitHub CLI (`gh`) is not needed on the Deck. Updates do **not** occur automatically.

If you installed using the standalone ZIP instead, download the newest ZIP and rerun `bash install-bundle.sh` with Steam closed.

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

- **Steam shortcut missing:** Ensure Steam was completely exited during installation. From `~/PyCab-Flatpak` (or the extracted `~/PyCab-Installer` directory), with Steam closed, run `python3 scripts/install-steam-shortcut.py`; then restart Steam.
- **Existing shortcut duplicated:** Do not manually add a new shortcut after the installer has already created one. Remove the unwanted duplicate in Steam.
- **Release download fails (HTTP 404):** Confirm the latest published [GitHub release](https://github.com/cdswindell/PyCab-Flatpak/releases/latest) includes `PyCab.flatpak` and `PyCab.flatpak.sha256` (or `PyCab-Installer.zip` for the standalone alternative). A tag alone is not a completed release.
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
