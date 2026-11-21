# Dependencies

Declared in `manifest.json` as well.

| Name | Package | Required | Why |
| --- | --- | --- | --- |
| [**Pithos**](https://github.com/pithos/pithos) | `pithos` | Yes | Pandora has no public hobby OAuth like Spotify. Pithos logs in, holds the station list, and plays audio. Micro-Pandora talks to it over MPRIS. |
| [**cava**](https://github.com/karlstav/cava) | `cava` | For the visualizer | Samples Pithos’s audio output. |
| **Pillow** | `python-pillow` | For album theming | Extracts the artwork palette. |
| **Omarchy** | Omarchy desktop | Yes | Quickshell host (`omarchy-shell`), bar, theme colors. |
| **PipeWire / Pulse** | already on Omarchy | Yes | Pithos playback and cava capture. |

## Install

```bash
omarchy pkg add cava python-pillow
omarchy pkg aur add pithos
```

Pithos is only in the AUR, not the official Arch repos, so it installs with
`omarchy pkg aur add`. Both commands skip anything already installed.

## Runtime extras (usually already installed)

- `pactl` (libpulse) and `jq` — cava-run finds Pithos’s sink monitor or the default output
- `stdbuf` (coreutils) — line-buffered cava output
- Python 3 + PyGObject (`gi.repository.Gio`) — `pithosctl`
- Desktop keyring — Pithos saves the Pandora password

## What Micro-Pandora does **not** use

- Spotify / OmaSpotify AuthManager
- A Pandora developer client id
- Chromium or a webview
