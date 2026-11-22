# Uninstall Micro-Pandora

This removes the plugin from Omarchy. Pithos and cava are separate packages;
remove those only if you do not want them for anything else.

## 1. Disable the bar widget

```bash
omarchy plugin disable io.github.micro23.micro-pandora
```

If that command is not available, edit `~/.config/omarchy/shell.json` and
delete the `io.github.micro23.micro-pandora` entry from `bar.layout` (usually
under `left`).

## 2. Remove the plugin files

```bash
omarchy plugin remove io.github.micro23.micro-pandora
omarchy restart shell
```

Pinned stations live outside the plugin:

```bash
rm -f ~/.config/omarchy/omapandora-pins.json
```

## 3. Remove the launcher entry and icon

If you installed the launcher, remove the files under your data directory:

```bash
rm -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/applications/io.github.micro23.MicroPandora.desktop"
rm -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps/io.github.micro23.MicroPandora.png"
```

## 4. Stop Pithos if it is still running

```bash
gdbus call --session --dest org.mpris.MediaPlayer2.io.github.Pithos --object-path /org/mpris/MediaPlayer2 --method org.mpris.MediaPlayer2.Quit
```

## 5. Optional: window rules

If you added Micro-Pandora / Pithos rules to `~/.config/hypr/hyprland.lua`, delete
those `o.window(...)` blocks and run `hyprctl reload`.

## 6. Optional: packages

```bash
omarchy pkg drop pithos cava
```

Only do this if nothing else on the machine needs them.

## 7. Optional: this git checkout

Your git clone of Micro-Pandora is **not** removed by the steps
above. Delete that folder yourself if you want the source gone too.
