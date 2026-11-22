# Install Micro-Pandora

Micro-Pandora is an Omarchy shell plugin. It needs **Pithos** (Pandora login and
audio) and **cava** (the Now Playing visualizer).

## 1. Omarchy

You need a working Omarchy desktop (Hyprland + `omarchy-shell`). Check:

```bash
omarchy plugin list
```

## 2. Dependencies

For a guided installation, clone [Micro-Pandora](https://github.com/micro23/Micro-Pandora) and run `./scripts/setup.sh`. That command installs missing dependencies, installs the plugin, and adds Micro-Pandora to the app launcher. For manual package installation:

```bash
omarchy pkg add cava python-pillow python-gobject libsecret
omarchy pkg aur add pithos
```

Pithos is only in the AUR, not the official Arch repos, so it installs with
`omarchy pkg aur add`. Both commands skip anything already installed.
Install `gnome-keyring` if the session has no existing Secret Service provider.

Confirm:

```bash
command -v pithos
command -v cava
```

Details: [dependencies.md](dependencies.md)

## 3. Add the plugin

### From GitHub

```bash
omarchy plugin add https://github.com/micro23/Micro-Pandora.git --enable
```

That clones into `~/.config/omarchy/plugins/io.github.micro23.micro-pandora/`
and puts the widget on the bar.

### From a git clone (local development)

```bash
git clone https://github.com/micro23/Micro-Pandora.git
cd Micro-Pandora
./scripts/install.sh
omarchy plugin enable io.github.micro23.micro-pandora left
omarchy restart shell
```

That copies `manifest.json`, the versioned QML directory, and `helpers/` only. Do **not** symlink
the plugin folder. Omarchy rejects plugin trees that are symlinks.

`install.sh` only replaces a plugin folder it created itself that still holds
exactly what it put there. The `.omapandora-dev-install` marker lists each
installed file with its SHA-256. If the folder has a file that is not on that
list, a listed file was changed, or you installed from GitHub first, it stops
without touching the folder and lists what it found. Move your files out, or run
`omarchy plugin remove io.github.micro23.micro-pandora`, then `install.sh`.

## 4. Optional window rules

In `~/.config/hypr/hyprland.lua` you can park Pithos off-screen and float the
player:

```lua
o.window("^(io\\.github\\.Pithos|[Pp]ithos)$", {
  workspace = "special:pithos silent",
  no_initial_focus = true,
})

o.window({ title = "^Micro-Pandora$" }, {
  float = true,
  center = true,
})
```

Then:

```bash
hyprctl reload
```

## 5. Sign in

1. Click the music-note icon on the bar (opens Micro-Pandora).
2. Open **Settings** and enter the email and password for your Pandora account.
3. Choose **Save and connect**. Your password is stored in the desktop keyring on this machine.
4. **Show Pithos window** is available in Settings if you need Pithos’s native interface.

Next: [first-run.md](first-run.md)

## Upgrade from v0.5.9 or earlier

Micro-Pandora v0.5.10 uses `io.github.micro23.micro-pandora`. To move an
existing Micro-Pandora installation from the former OmaPandora ID:

1. Disable the old player with `omarchy plugin disable io.github.dankestrick.omapandora`.
2. Clone the current Micro-Pandora repository (or update your existing
   checkout) and run `./scripts/setup.sh`. This enables the new ID and
   updates the launcher entry.
3. If you customized the old bar widget, reapply those settings to the new
   widget. In custom shortcuts for Micro-Pandora, replace
   `io.github.dankestrick.omapandora` with `io.github.micro23.micro-pandora`.
   For Omarchy Config Sync, sync the new plugin and updated bindings from
   the upgraded device, then apply them on the other devices.
4. Once you have verified the new player, remove the old plugin with
   `omarchy plugin remove io.github.dankestrick.omapandora` if you no
   longer use it.

The new player reads the same pinned-station file and Pithos credentials.
