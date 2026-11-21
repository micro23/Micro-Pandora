# Contributing

Read [LAYOUT.md](LAYOUT.md) first. New files go in the folder that table names.

1. Edit in your clone of this repo (`qml/` for UI, `helpers/` for pithosctl/cava).
2. Copy into the live plugin folder:

   ```bash
   ./scripts/install.sh
   ```

   Do not symlink. Omarchy rejects a plugin folder that is a symlink.
3. `omarchy restart shell` if the keepLoaded service looks stale.
4. Run `./scripts/test.sh` before you push. It checks the helper contracts and runs the QML smoke tests on an isolated D-Bus session.

Playback goes through Pithos because Pandora has no public login for apps
like this one. Please keep Pithos as the backend rather than swapping it out.

Check both the full-size and compact layout and use the mini and full player on a running Omarchy shell before publishing a release.
