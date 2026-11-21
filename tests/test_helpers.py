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
from unittest.mock import patch

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("pithosctl", str(ROOT / "helpers/pithosctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
pithosctl = importlib.util.module_from_spec(spec)
loader.exec_module(pithosctl)


class AlbumPaletteTests(unittest.TestCase):
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
