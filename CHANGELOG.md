# Changelog

## v0.5.8

- Restore the full-window, softened album backdrop. Keep it visible until the next cover is ready.

## v0.5.7

- Fit the whole original cover into the full-player backdrop and hold it in place until the next cover is ready.

## v0.5.6

- Let the full-player album silhouette show through by fading the stage color wash away when the cover loads.

## v0.5.5

- Rank album hues by their visible area so the dominant color leads the stage and main controls.
- Give playback, stations, progress, volume and artwork their own accent colors. Draw the full five-color palette in Spectrum, Mirror and Orbit.

## v0.5.4

- Keep the backdrop at its intended opacity when switching from the original cover to the high-resolution blur.

## v0.5.3

- Keep the album silhouette visible when Omarchy still holds an older service in memory. Use the original cover until the high-resolution blur is available.

## v0.5.2

- Soften the full-player album silhouette with lower opacity and a high-resolution blur made from the original cover.
- Draw from up to seven album swatches for surfaces, text, stations, playback, volume, and visualizer accents. Limited-color covers keep their own shades.
- Keep the outgoing cover behind the incoming one throughout the fade.
- Center Orbit on a level ring and balance bass peaks and moving arcs across both sides.

## v0.5.1

- Restore the current album cover as a soft, full-window silhouette behind the player, with smooth cover changes and readable controls in all three visualizers.
- Keep the selected station and visualizer labels legible over different album palettes.

## v0.5.0

- Rebuild the full and mini players around album-tinted surfaces, larger artwork, and a unified transport. Crossfade covers once the next image is ready.
- Redesign Spectrum and Mirror with sharper peaks, brighter ribbons, and more visible reflections.
- Make Orbit rotate and lift on bass hits, with counter-rotating sweeps and expanding pulses.
- Add a sliding visualizer picker, album lighting, track transitions, and a labeled Stations control.
- Remember the station sidebar and selected visualizer across restarts.
- Hide and restore the station sidebar from the header or with Ctrl+B.
- Load the updated player and bar widget after an upgrade through versioned QML entry points.

## v0.4.0

- Add Pandora sign-in to Settings using Pithos’s desktop keyring format.
- Start Pithos on a hidden workspace and add a persistent show/hide control.
- Register a Micro-Pandora app launcher with a Settings action and add one-command dependency setup.
- Give Spectrum shaded peaks, Mirror a pair of animated ribbons, and Orbit a set of segmented rings that respond to playback.
- Carry the album palette through the mini player, artwork frame, station list, and playback controls. Keep the last cover visible until the next one is ready.

## v0.3.0

- Add Mirror and Orbit visualizers. Press V or click the visualizer name to cycle through views without interrupting playback.
- Follow Pithos’s audio output when it differs from the default or changes during a song.
- Fix station search and keyboard volume shortcuts, and add feedback for playback and visualizer errors.
- Switch between the mini and full player from either view. Give the mini player the same typography and album accents.

## v0.2.0

- Rename the player to Micro-Pandora. Keep the plugin ID, pins, and IPC targets compatible with existing installs.
- Theme both players from the current cover, with readable cover-derived text and accents, a blurred cover backdrop, and gradient artwork frames.
- Center the larger artwork and track details over a shaded spectrum that rises around the cover.
- Restyle the station sidebar, active station indicator, and playback deck with the album palette.
- Prefer packaged Cava on Arch so a synced older user binary cannot shadow it.

## 0.1.2

- New look: a faint OMAPANDORA, in the font of the Omarchy logo, repeats
  in diagonal rows behind the full player and the mini player. It uses the
  theme's accent color, so it changes with the theme.
- Fixed: the full player could get stuck open but treated as closed (no big
  album art, flat visualizer, Esc not closing, the bar icon opening the mini
  player on top). Moving the window to another monitor briefly hides it, and
  that hide was taken as a close. The window now moves only when it is on the
  wrong monitor, and a hide during the move no longer closes the player.
- `scripts/install.sh` only replaces a plugin folder it created itself. It no
  longer writes into or deletes files from an `omarchy plugin add` checkout or
  any other folder at the plugin path.
- `scripts/install.sh` also stops if its own folder has a file it did not
  install or a file changed since, so nothing you added there is deleted. It
  records each installed file's SHA-256 in `.omapandora-dev-install` and removes
  only those files from the old copy.
- Pinned stations: if `omapandora-pins.json` exists but can't be read, pinning
  is paused and the player says so, instead of replacing the file.
- `docs/uninstall.md` removes the plugin with `omarchy plugin remove` instead
  of `rm -rf`.
- Pins are saved by the helper as a private (0600) file, and it also refuses
  to replace a pins file it can't read.
- Album art loads only from Pithos's local cache (`file://`), with a size
  limit on every image; the shell never fetches art over the network.
- Pithos is started from `/usr/bin/pithos` instead of the first `pithos` on
  `$PATH`.
- Fixed: opening the player twice while Pithos was still starting could
  record the PID of a second copy that exits at once, so X only paused the
  Pithos OmaPandora had started. The helper no longer starts a second copy
  and records a PID only if that process keeps running.
- `cava-run` gives `pactl` a 3-second time limit, and pipes cava its config
  instead of writing a temp file, so a shell restart can't leave one behind.
- Docs: the command to quit Pithos uses its real bus name,
  `org.mpris.MediaPlayer2.io.github.Pithos`.
- `scripts/uninstall.sh` runs `omarchy plugin remove` once and shows its errors.

## 0.1.1

- The full player opens on the monitor your mouse is on, not always workspace 3.
- Scrolling on the bar icon skips to the next song while the mini player is open.
- README: bar clicks, bar settings, keybind commands, and troubleshooting.

## 0.1.0

- First public layout: `qml/`, `helpers/`, `docs/`, `scripts/`.
- Bar widget, mini player, full player, Pithos backend, cava visualizer.
