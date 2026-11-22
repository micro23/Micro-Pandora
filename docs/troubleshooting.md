# Troubleshooting

## Bar icon does nothing

The panel must implement `open()`. Restart the shell:

```bash
omarchy restart shell
```

Confirm the plugin is enabled:

```bash
omarchy plugin list
```

## Hover still says the old tooltip / UI looks stale

`keepLoaded` services do not always pick up QML until a shell restart. Also
make sure the panel entry point listed in the installed `manifest.json`
is **not** zero bytes (that happened during development).

## Visualizer is still / not bouncing

Cava samples the output Pithos is playing through. If the Pithos stream
cannot be identified, the visualizer uses your default output. Start playback
and check the selected monitor:

```bash
~/.config/omarchy/plugins/io.github.dankestrick.omapandora/helpers/cava-run --monitor
pgrep -a cava
```

## Pithos window keeps popping up

Choose **Settings → Hide Pithos window** in Micro-Pandora. The preference applies the next time Micro-Pandora starts the backend, too. Opening Pithos directly from the desktop can show its window.

## X does not stop the music

X calls `stopAndQuit`, which pauses and then quits Pithos only if Micro-Pandora
started it. A Pithos you opened yourself is paused and left running. To close
it by hand:

```bash
gdbus call --session --dest org.mpris.MediaPlayer2.io.github.Pithos --object-path /org/mpris/MediaPlayer2 --method org.mpris.MediaPlayer2.Quit
```

## Pins do not save

Check `~/.config/omarchy/omapandora-pins.json`. **C** pins the **highlighted**
row in My list or Your stations, not necessarily the song that is playing.

## Plugin folder as a symlink

Omarchy validation fails if the plugin directory is a symlink. Copy or git
clone into `~/.config/omarchy/plugins/<id>/`.
