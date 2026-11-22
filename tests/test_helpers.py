import colorsys
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("pithosctl", str(ROOT / "helpers/pithosctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
pithosctl = importlib.util.module_from_spec(spec)
loader.exec_module(pithosctl)


class AlbumPaletteTests(unittest.TestCase):
    def test_colorful_album_uses_seven_source_swatches_and_keeps_labels_readable(self):
        with tempfile.TemporaryDirectory() as tmp:
            cover = Path(tmp) / "seven.png"
            image = Image.new("RGB", (84, 84))
            source = ["#dc3348", "#f6b329", "#64b83f", "#2396d0",
                      "#7948b0", "#31414c", "#efe6d4"]
            for index, value in enumerate(source):
                image.paste(value, (index * 12, 0, (index + 1) * 12, 84))
            image.save(cover)
            palette = pithosctl.extract_art_palette(cover.as_uri())

        raw = [(1008, tuple(bytes.fromhex(value[1:]))) for value in source]
        accents, base, surface, text = pithosctl.choose_art_swatches(raw, raw[:5])
        self.assertEqual(len(set([*accents, base, surface, text])), 7)
        roles = ("accent", "accentAlt", "volumeAccent", "detailAccent", "artAccent")
        self.assertEqual(len({palette[role] for role in roles}), len(roles))
        hues = [colorsys.rgb_to_hls(*(value / 255 for value in bytes.fromhex(palette[role][1:])))[0]
                for role in roles]
        for index, hue in enumerate(hues):
            self.assertTrue(all(min(abs(hue - other), 1 - abs(hue - other)) >= 0.053
                                for other in hues[:index]))
        surface_luminance = max(pithosctl.luminance(tuple(bytes.fromhex(palette[role][1:])))
                                for role in ("background", "backgroundAlt"))
        for role in (*roles, "foreground", "muted"):
            ink = pithosctl.luminance(tuple(bytes.fromhex(palette[role][1:])))
            self.assertGreaterEqual((ink + 0.05) / (surface_luminance + 0.05), 5.5, role)

    def test_monochrome_art_keeps_its_neutral_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            cover = Path(tmp) / "gray.png"
            Image.new("L", (20, 20), 235).save(cover)
            palette = pithosctl.extract_art_palette(cover.as_uri())

        self.assertTrue(all(len(set(bytes.fromhex(value[1:]))) == 1
                            for value in palette.values()))

    def test_the_most_prevalent_hue_leads_the_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            cover = Path(tmp) / "prominent.png"
            image = Image.new("RGB", (96, 96), "#527f9a")
            image.paste("#f01e54", (75, 0, 96, 96))
            image.paste("#f2a21c", (60, 0, 75, 96))
            image.paste("#53a633", (51, 0, 60, 96))
            image.paste("#8d52aa", (45, 0, 51, 96))
            image.save(cover)
            palette = pithosctl.extract_art_palette(cover.as_uri())

        for role in ("background", "accent"):
            red, green, blue = bytes.fromhex(palette[role][1:])
            self.assertLess(red, green)
            self.assertLess(green, blue)
        self.assertTrue(len({palette[role] for role in
                             ("accent", "accentAlt", "volumeAccent", "detailAccent", "artAccent")}) == 5)

    def test_sparse_accent_colors_survive_a_white_cover(self):
        with tempfile.TemporaryDirectory() as tmp:
            cover = Path(tmp) / "cover with spaces.png"
            image = Image.new("RGB", (96, 96), "white")
            image.paste("#eb459c", (16, 16, 28, 35))
            image.paste("#29d8f0", (48, 16, 64, 35))
            image.save(cover)

            palette = pithosctl.extract_art_palette(cover.as_uri())

        accents = [tuple(bytes.fromhex(palette[role][1:])) for role in ("accent", "accentAlt")]
        self.assertTrue(any(red > green and red > blue for red, green, blue in accents))
        self.assertTrue(any(red < green and red < blue for red, green, blue in accents))
        lightest = max(pithosctl.luminance(tuple(bytes.fromhex(palette[role][1:])))
                       for role in ("background", "backgroundAlt"))
        for role, minimum in (("foreground", 7), ("muted", 5.5), ("accent", 5.5), ("accentAlt", 5.5)):
            light = pithosctl.luminance(tuple(bytes.fromhex(palette[role][1:])))
            self.assertGreaterEqual((light + 0.05) / (lightest + 0.05), minimum)

    def test_covers_missing_or_outside_the_local_cache_fall_back(self):
        self.assertEqual(pithosctl.extract_art_palette("file:///nonexistent-pithos-test-cover.png"), {})
        self.assertEqual(pithosctl.extract_art_palette("https://example.invalid/cover.png"), {})
        self.assertEqual(pithosctl.extract_art_palette("file://elsewhere/cover.png"), {})

    def test_backdrop_preserves_detail_in_the_source_at_display_resolution(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "album with spaces.png"
            image = Image.new("RGB", (1500, 1000), "#101d4b")
            image.paste("#f09449", (600, 0, 1500, 1000))
            image.save(source)
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR": tmp}):
                url = pithosctl.cover_backdrop_url(source.as_uri())
                self.assertTrue(url.startswith(Path(tmp).as_uri()))
                self.assertEqual(pithosctl.cover_backdrop_url(source.as_uri()), url)
                with Image.open(pithosctl.unquote(pithosctl.urlsplit(url).path)) as blurred:
                    self.assertEqual(blurred.size, (960, 640))
                    self.assertLess(blurred.getpixel((250, 320))[0], 30)
                    self.assertGreater(blurred.getpixel((600, 320))[0], 220)
                    transition = [blurred.getpixel((x, 320))[0] for x in (370, 380, 390, 400)]
                    self.assertEqual(transition, sorted(set(transition)))
                image.rotate(180).save(source)
                self.assertNotEqual(pithosctl.cover_backdrop_url(source.as_uri()), url)
                self.assertEqual(pithosctl.cover_backdrop_url("https://example.invalid/art"), "")


class PlayerCommandTests(unittest.TestCase):
    def test_rating_for_a_stale_track_never_reaches_pithos(self):
        with (
            patch.object(pithosctl, "session_bus", return_value=object()),
            patch.object(pithosctl, "find_bus_name", return_value="org.mpris.MediaPlayer2.io.github.Pithos"),
            patch.object(pithosctl, "get_all", return_value={"Metadata": {"mpris:trackid": "/pithos/new"}}),
            patch.object(pithosctl, "call") as call,
            self.assertRaisesRegex(SystemExit, "track changed"),
        ):
            pithosctl.main(["pithosctl", "ban", "/pithos/old"])
        call.assert_not_called()

    def test_pins_are_private_and_a_corrupt_file_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pins.json"
            pins = [{"path": "/pithos/station", "name": "Station"}]
            with patch.object(pithosctl, "PINS_FILE", str(path)):
                with patch.object(sys, "stdin", io.StringIO(json.dumps(pins))):
                    self.assertEqual(pithosctl.save_pins()["pins"], 1)
                self.assertEqual(json.loads(path.read_text()), pins)
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                path.write_text("unreadable")
                with patch.object(sys, "stdin", io.StringIO("[]")):
                    with self.assertRaisesRegex(SystemExit, "was not replaced"):
                        pithosctl.save_pins()
                self.assertEqual(path.read_text(), "unreadable")


class AccountSetupTests(unittest.TestCase):
    def test_account_records_email_only_after_password_is_in_keyring(self):
        settings = Mock()
        settings.is_writable.return_value = True
        settings.set_string.return_value = True
        operations = []
        settings.set_string.side_effect = lambda key, value: operations.append((key, value)) or True
        payload = {"email": " listener@example.invalid ", "password": 'dummy \\ " unicode é'}
        with (
            patch.object(sys, "stdin", io.StringIO(json.dumps(payload))),
            patch.object(pithosctl, "pithos_settings", return_value=settings),
            patch.object(pithosctl, "store_account_secret",
                         side_effect=lambda email, password: operations.append(("keyring", email, password)) or True),
        ):
            result = pithosctl.save_account()
        self.assertEqual(operations, [
            ("keyring", "listener@example.invalid", payload["password"]),
            ("email", "listener@example.invalid"),
        ])
        self.assertEqual(result, {"saved": True, "email": "listener@example.invalid"})

    def test_locked_keyring_leaves_account_email_unchanged(self):
        settings = Mock()
        settings.is_writable.return_value = True
        payload = {"email": "listener@example.invalid", "password": "dummy"}
        with (
            patch.object(sys, "stdin", io.StringIO(json.dumps(payload))),
            patch.object(pithosctl, "pithos_settings", return_value=settings),
            patch.object(pithosctl, "store_account_secret", return_value=False),
            self.assertRaisesRegex(SystemExit, "Unlock it and try again"),
        ):
            pithosctl.save_account()
        settings.set_string.assert_not_called()

    def test_unconfigured_app_leaves_pithos_unlaunched(self):
        with (
            patch.object(pithosctl.os, "access", return_value=True),
            patch.object(pithosctl, "account_status", return_value={"email": ""}),
            patch.object(pithosctl.subprocess, "Popen") as launch,
        ):
            self.assertTrue(pithosctl.launch_pithos()["needsAccount"])
        launch.assert_not_called()

    def test_hidden_backend_launch_has_a_non_focusing_workspace_rule(self):
        with (
            patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "test"}),
            patch.object(pithosctl.os, "access", return_value=True),
            patch.object(pithosctl, "account_status", return_value={"email": "listener@example.invalid"}),
            patch.object(pithosctl, "backend_visible", return_value=False),
            patch.object(pithosctl, "session_bus", return_value=object()),
            patch.object(pithosctl, "find_bus_name", return_value=None),
            patch.object(pithosctl, "list_names", return_value=[]),
            patch.object(pithosctl, "launched_pid", return_value=None),
            patch.object(pithosctl, "dispatch_hyprland") as dispatch,
        ):
            self.assertTrue(pithosctl.launch_pithos()["launched"])
        expression = dispatch.call_args.args[0]
        self.assertIn("spawn-backend", expression)
        self.assertIn("special:pithos silent", expression)
        self.assertIn("no_initial_focus=true", expression)

    def test_backend_visibility_is_private_and_defaults_to_hidden(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "private/settings.json"
            with patch.object(pithosctl, "STATE_FILE", str(path)):
                self.assertFalse(pithosctl.backend_visible())
                pithosctl.set_backend_visible(True)
                self.assertTrue(pithosctl.backend_visible())
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                pithosctl.set_backend_visible(False)
                self.assertFalse(pithosctl.backend_visible())

    def test_reconnect_waits_for_the_old_backend_before_launching(self):
        events = []
        old = "org.mpris.MediaPlayer2.io.github.Pithos"
        with (
            patch.object(pithosctl, "session_bus", return_value=object()),
            patch.object(pithosctl, "find_bus_name", side_effect=[old, old, None]),
            patch.object(pithosctl, "list_names", return_value=[]),
            patch.object(pithosctl, "launched_pid", return_value=None),
            patch.object(pithosctl.time, "sleep", side_effect=lambda _: events.append("wait")),
            patch.object(pithosctl, "call", side_effect=lambda *args: events.append(args[3])),
            patch.object(pithosctl, "launch_pithos", side_effect=lambda: events.append("launch") or {"launched": True}),
        ):
            self.assertTrue(pithosctl.reconnect_pithos()["launched"])
        self.assertEqual(events, ["Quit", "wait", "launch"])


class LauncherTests(unittest.TestCase):
    def test_launcher_install_is_idempotent_and_uses_the_app_icon(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "XDG_DATA_HOME": tmp}
            arguments = [ROOT / "helpers/setup-deps", "--launcher"]
            subprocess.run(arguments, env=env, check=True)
            entry = Path(tmp) / "applications/io.github.micro23.MicroPandora.desktop"
            modified = entry.stat().st_mtime_ns
            subprocess.run(arguments, env=env, check=True)
            self.assertEqual(entry.stat().st_mtime_ns, modified)
            self.assertIn("openFromLauncher", entry.read_text())
            icon = Path(tmp) / "icons/hicolor/256x256/apps/io.github.micro23.MicroPandora.png"
            self.assertTrue(icon.is_file())

    def test_launcher_preserves_custom_entries_and_migrates_only_the_stock_legacy_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp)
            env = {**os.environ, "XDG_DATA_HOME": tmp}
            entry = data / "applications/io.github.micro23.MicroPandora.desktop"
            entry.parent.mkdir()
            stock = (ROOT / "helpers" / entry.name).read_text()
            legacy = stock.replace("io.github.micro23.micro-pandora.player",
                                   "io.github.dankestrick.omapandora.player")
            customized = legacy.replace("Name=Micro-Pandora", "Name=My station launcher")
            entry.write_text(customized)

            arguments = [ROOT / "helpers/setup-deps", "--launcher"]
            subprocess.run(arguments, env=env, check=True)
            self.assertEqual(entry.read_text(), customized)

            entry.write_text(legacy)
            subprocess.run(arguments, env=env, check=True)
            self.assertEqual(entry.read_text(), stock)

    def test_fresh_setup_installs_dependencies_before_enabling_the_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "bin"
            binary.mkdir()
            tools = {
                "pacman": """#!/bin/sh
for package do :; done
grep -Fxq -- "$package" "$MICRO_SETUP_QA/packages" 2>/dev/null
""",
                "omarchy": """#!/bin/sh
printf '%s\n' "$*" >> "$MICRO_SETUP_QA/events"
if [ "$1" = pkg ]; then
    shift
    [ "$1" != aur ] || shift
    shift
    printf '%s\n' "$@" >> "$MICRO_SETUP_QA/packages"
fi
""",
                "omarchy-shell": """#!/bin/sh
printf '%s\n' "$*" >> "$MICRO_SETUP_QA/events"
""",
                "gnome-keyring-daemon": "#!/bin/sh\nexit 0\n",
            }
            for name, source in tools.items():
                tool = binary / name
                tool.write_text(source)
                tool.chmod(0o755)
            env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                   "MICRO_SETUP_QA": tmp, "XDG_DATA_HOME": str(root / "data"),
                   "XDG_CONFIG_HOME": str(root / "config")}
            subprocess.run([ROOT / "scripts/setup.sh"], env=env, check=True, capture_output=True)
            self.assertEqual((root / "events").read_text().splitlines(), [
                "plugin validate " + str(ROOT),
                "pkg add cava python-pillow python-gobject libsecret",
                "pkg aur add pithos",
                "shell rescanPlugins",
                "plugin enable io.github.micro23.micro-pandora",
            ])
            plugin = root / "config/omarchy/plugins/io.github.micro23.micro-pandora"
            manifest = json.loads((plugin / "manifest.json").read_text())
            ui = Path(manifest["entryPoints"]["panel"]).parent
            self.assertTrue((plugin / ui / "PlayerSettings.qml").exists())
            self.assertTrue((root / "data/applications/io.github.micro23.MicroPandora.desktop").exists())


class VisualizerRouteTests(unittest.TestCase):
    def test_prefers_the_playing_pithos_stream_to_the_default_sink(self):
        with tempfile.TemporaryDirectory() as tmp:
            pactl = Path(tmp) / "pactl"
            pactl.write_text("""#!/bin/sh
case "$*" in
  "-f json list sink-inputs")
    printf '%s\n' '[{"sink":4,"corked":false,"properties":{"application.name":"Other"}},
      {"sink":7,"corked":true,"properties":{"application.id":"io.github.Pithos"}},
      {"sink":9,"corked":false,"properties":{"application.name":"Pithos"}}]' ;;
  "-f json list sinks")
    printf '%s\n' '[{"index":9,"name":"headphones"},{"index":7,"name":"hdmi"}]' ;;
  get-default-sink) printf '%s\n' speakers ;;
esac
""")
            pactl.chmod(0o755)
            env = {**os.environ, "PATH": tmp + os.pathsep + os.environ["PATH"]}
            result = subprocess.check_output([ROOT / "helpers/cava-run", "--monitor"], env=env, text=True)
            self.assertEqual(result.strip(), "headphones.monitor")

            pactl.write_text("#!/bin/sh\n[ \"$1\" != get-default-sink ] || printf '%s\\n' speakers\n")
            result = subprocess.check_output([ROOT / "helpers/cava-run", "--monitor"], env=env, text=True)
            self.assertEqual(result.strip(), "speakers.monitor")
