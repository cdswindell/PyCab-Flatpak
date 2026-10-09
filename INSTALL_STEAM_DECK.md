# Installing PyCab on a new Steam Deck

This guide installs the **prebuilt PyCab Flatpak** as a Lionel/PyTrain controller on a new Steam Deck (SteamOS). It does **not** require Docker, a Python virtual environment, PyLegacy source, Flatpak Builder, or compiling software. You need a published [PyCab release](https://github.com/cdswindell/PyCab-Flatpak/releases), internet access, and a reachable PyTrain server.

## 1. Prepare the Deck

1. Complete initial SteamOS setup, sign in to Steam, connect to Wi-Fi, and let SteamOS finish updates.
2. Press **STEAM > Power > Switch to Desktop**.
3. Open **Konsole** from the application launcher. All shell commands below run as the default `deck` user; **do not run them with sudo**.
4. Confirm networking and tools:

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

## 3. Install the prebuilt PyCab Flatpak

Run the following **on the Deck** (either in Konsole or in your SSH session):

```bash
cd ~
git clone https://github.com/cdswindell/PyCab-Flatpak.git
cd PyCab-Flatpak
bash install.sh
```

The installer downloads `PyCab.flatpak` from the latest published GitHub Release, installs it for the `deck` user, and installs a Steam-compatible host launcher at:

```text
/home/deck/.local/bin/pycab-steam
```

If Flatpak reports a missing runtime, ensure the **Flathub** remote is configured, then rerun the installer:

```bash
flatpak remotes
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
bash install.sh
```

Do **not** use `bash install.sh --build` for a normal installation; that is a developer-only source build requiring Flatpak Builder.

Confirm installation:

```bash
flatpak info --user io.github.cdswindell.PyCab
test -x ~/.local/bin/pycab-steam && echo "Steam launcher installed"
```

## 4. Test PyCab in Desktop Mode

With the PyTrain server running and reachable over the network:

```bash
flatpak run io.github.cdswindell.PyCab
```

The PyCab GUI should open. Check that it can discover/connect to the PyTrain server and control a safe test device. Server discovery depends on your network allowing the necessary communication between Deck and server. Close the application before continuing.

## 5. Add PyCab to the Steam library

While still in **Desktop Mode**:

1. Open Steam.
2. Select **Games > Add a Non-Steam Game to My Library**. If PyCab is not listed, use **Browse** to select `/home/deck/.local/bin/pycab-steam`. If the chooser hides dot-directories, enable **Show Hidden Files**. You may also add any executable temporarily and then edit the shortcut.
3. Open the new game's **Properties > Shortcut** and set:

   ```text
   Name:           PyCab
   Target:         /home/deck/.local/bin/pycab-steam
   Start In:       /home/deck/
   Launch Options: (leave empty)
   ```

4. Under **Properties > Controller**, set **Override for PyCab** to **Enable Steam Input**.

**Important:** Use the `pycab-steam` shell launcher as the Steam shortcut target, **not** `/usr/bin/flatpak`. Launching Flatpak directly from Steam produced a white Tk window on the tested Deck; the host-side launcher avoids that issue.

Launch PyCab from Steam in Desktop Mode and confirm that the Steam Deck buttons, sticks, and other supported controls work.

## Select client or server mode using Steam Launch Options

One PyCab installation supports both operating modes. In Steam Desktop Mode, open **PyCab > Properties > Shortcut** and edit **Launch Options**:

| Launch Options | Behavior |
| --- | --- |
| *(empty)* | Existing client mode; connects to a separate PyTrain server. |
| `--server` | Server mode; PyTrain discovers the Base 3 automatically. |
| `--server --base-ip 192.168.4.100` | Server mode; PyTrain uses the specified Base 3 address (replace with yours). |

Under the hood, the launcher maps these to PyTrain's `-client`, `-base`, and `-base <ip>` flags. **Do not enter `-base` directly as a Steam option**; use the documented `--server` form.

For command-line testing:

```bash
flatpak run io.github.cdswindell.PyCab
flatpak run io.github.cdswindell.PyCab --server
flatpak run io.github.cdswindell.PyCab --server --base-ip 192.168.4.100
```

Server mode requires a reachable Base 3 and network discovery must work for the automatic option. This new launch-mode behavior must be tested in a newly built Flatpak; existing published bundles do not contain it.

## 6. Test in Gaming Mode

1. On the Desktop, choose **Return to Gaming Mode**.
2. Open **Library > Non-Steam** (location can vary by Steam UI version).
3. Select **PyCab > Play**.
4. Confirm that the GUI appears, controls respond, and the PyTrain server is reachable.

Once these checks pass, PyCab is ready to use as a handheld controller.

## 7. Updating an existing Deck

After a new GitHub Release is published, switch to Desktop Mode and run:

```bash
cd ~/PyCab-Flatpak
git pull
bash install.sh
```

This downloads and installs the latest prebuilt release and refreshes the launcher. The existing Steam shortcut normally requires no changes. Recheck Steam Input and functionality after an update.

## 8. Troubleshooting

- **`git clone` says directory already exists:** run `cd ~/PyCab-Flatpak && git pull`, then `bash install.sh`.
- **Release download fails (HTTP 404):** confirm a published GitHub Release has a `PyCab.flatpak` asset. Repository commits or tags alone do not guarantee a finished bundle.
- **`flatpak` cannot find a runtime:** check `flatpak remotes`, add Flathub as shown above, and retry.
- **GUI works in Konsole but is white in Steam:** verify the Steam shortcut **Target** is `/home/deck/.local/bin/pycab-steam`, **Start In** is `/home/deck/`, and launch options are empty.
- **Buttons do not respond:** enable **Steam Input** under the game's Controller override, then relaunch.
- **Cannot connect to the server:** verify the PyTrain server is running and that Deck/server devices can reach each other on the network. Try a direct connection if discovery is blocked by Wi-Fi isolation.
- **SSH connection refused:** check `systemctl is-active sshd` on the Deck and confirm the Deck's current IP address and network reachability.
- **To inspect logs:** launch from Konsole with `flatpak run io.github.cdswindell.PyCab` and copy the terminal output.

## 9. Removing PyCab

Remove the PyCab shortcut from Steam manually, then run:

```bash
cd ~/PyCab-Flatpak
bash uninstall.sh
```

This removes the user Flatpak and `~/.local/bin/pycab-steam` but retains application data. It does not remove SteamOS packages or change your SSH settings.

---

**Maintainer note:** New releases are built by GitHub Actions; the instructions above install only the latest *published* bundle. If the Digital Dream font redistribution permission is still pending, do not publish a new bundle containing it until permission has been granted.
