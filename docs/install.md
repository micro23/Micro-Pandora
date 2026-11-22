# Install Micro-Pandora

Micro-Pandora is an Omarchy shell plugin. It needs **Pithos** (Pandora login and
audio) and **cava** (the Now Playing visualizer).

## 1. Omarchy

You need a working Omarchy desktop (Hyprland + `omarchy-shell`). Check:

```bash
omarchy plugin list
```

## 2. Dependencies

For a fresh installation, extract the [release archive](https://github.com/micro23/Micro-Pandora/releases) and run `./scripts/setup.sh`. That command installs missing dependencies, installs the plugin, and adds Micro-Pandora to the app launcher. For manual package installation:

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

That clones into `~/.config/omarchy/plugins/io.github.dankestrick.omapandora/`
and puts the widget on the bar.

### From a git clone (local development)

```bash
git clone https://github.com/micro23/Micro-Pandora.git
cd Micro-Pandora
./scripts/install.sh
omarchy plugin enable io.github.dankestrick.omapandora left
omarchy restart shell
```

That copies `manifest.json`, the versioned QML directory, and `helpers/` only. Do **not** symlink
the plugin folder. Omarchy rejects plugin trees that are symlinks.

`install.sh` only replaces a plugin folder it created itself that still holds
exactly what it put there. The `.omapandora-dev-install` marker lists each
installed file with its SHA-256. If the folder has a file that is not on that
list, a listed file was changed, or you installed from GitHub first, it stops
without touching the folder and lists what it found. Move your files out, or run
`omarchy plugin remove io.github.dankestrick.omapandora`, then `install.sh`.

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
