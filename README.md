# Micro-Pandora

Micro-Pandora is a Pandora player for the Omarchy shell. It puts a mini player on the bar and opens a full player with a station browser, a playback deck, and a live spectrum. Both players use the current album’s artwork and colors. Pithos handles sign-in and playback.

![Micro-Pandora full player with demo artwork and stations](docs/preview.webp)

## Install

On a current Omarchy desktop, install the dependencies and add the plugin:

```bash
omarchy pkg add cava python-pillow
omarchy pkg aur add pithos
omarchy plugin add https://github.com/micro23/Micro-Pandora.git --enable
```

The [releases page](https://github.com/micro23/Micro-Pandora/releases) also provides a versioned source archive and its SHA-256 checksum. If you install from an extracted archive, run `./scripts/validate.sh` and `./scripts/install.sh`, then enable the widget with `omarchy bar put io.github.dankestrick.omapandora --section left`. The archive installer checks for existing files before installing.

Micro-Pandora keeps the original `io.github.dankestrick.omapandora` plugin ID for compatibility with existing bar layouts, keyboard shortcuts, and synced installations. Pinned stations remain in `~/.config/omarchy/omapandora-pins.json`. If you already have the player through **Omarchy Config Sync**, apply the incoming **Micro-Pandora** plugin there to update it in place. Restart the Omarchy shell if it is still showing the previous design.

## Use

- Left-click the music note in the bar for the mini player. Right-click for the full player.
- On first use, open Pithos through Settings and sign in. Pithos stores the login in your desktop keyring.
- Select a station in the sidebar. The active station has its own marker. Use the pin next to the station name to keep it in **My list**.
- The full player has play, pause, skip, volume, and mute controls. Progress is read-only because Pandora doesn’t offer seeking here.
- Press **V** or click the visualizer name in the header to cycle Spectrum, Mirror, and Orbit.

See [installation](docs/install.md), [keyboard shortcuts](docs/keyboard.md), and [troubleshooting](docs/troubleshooting.md) for more.

## Credits

Micro-Pandora is based on [OmaPandora by Dankestrick](https://github.com/Dankestrick/OmaPandora), which was built on [OmaSpotify](https://github.com/jeremylanger/omaspotify). See the [MIT license](LICENSE) for the original copyright notices.
