import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("release_update", str(ROOT / "helpers/release-update"))
spec = importlib.util.spec_from_loader(loader.name, loader)
updater = importlib.util.module_from_spec(spec)
loader.exec_module(updater)


class ReleaseUpdateTests(unittest.TestCase):
    def test_latest_requires_a_stable_version(self):
        with patch.object(updater, "get_metadata", return_value={
            "tag_name": "v0.10.3", "draft": False, "prerelease": False,
        }):
            self.assertEqual(updater.latest_version(), "0.10.3")
            self.assertGreater(updater.version_key("0.10.3"), updater.version_key("0.9.12"))
        with patch.object(updater, "get_metadata", return_value={
            "tag_name": "v0.10.3-rc.1", "draft": False, "prerelease": True,
        }):
            with self.assertRaises(ValueError):
                updater.latest_version()

    def test_installs_a_validated_commit_for_both_installation_types(self):
        for copied in (False, True):
            with self.subTest(copied=copied), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                repo = work / "repo"
                repo.mkdir()
                updater.git(repo, "init", "-q")
                updater.git(repo, "config", "user.name", "Micro-Pandora Test")
                updater.git(repo, "config", "user.email", "test@example.invalid")
                helpers = repo / "helpers"
                helpers.mkdir()
                for name in ("install-copy", "pithosctl", "cava-run", "setup-deps"):
                    shutil.copy2(ROOT / "helpers" / name, helpers / name)

                self.commit_version(repo, "0.9.4")
                config = work / "config"
                plugin = config / "omarchy" / "plugins" / updater.PLUGIN_ID
                env = {"XDG_CONFIG_HOME": str(config)}
                with patch.dict(os.environ, env):
                    if copied:
                        subprocess.run([helpers / "install-copy", repo], check=True, capture_output=True)
                    else:
                        plugin.parent.mkdir(parents=True)
                        updater.git(work, "clone", "-q", str(repo), str(plugin))

                    commit = self.commit_version(repo, "0.10.0")
                    with (
                        patch.object(updater, "REPOSITORY", str(repo)),
                        patch.object(updater, "latest_version", return_value="0.10.0"),
                        patch.object(updater, "get_metadata", return_value={"sha": commit}),
                    ):
                        modified = plugin / "qml-0.9.4/Player.qml"
                        original = modified.read_text()
                        modified.write_text(original + "// user edit\n")
                        with self.assertRaises(ValueError):
                            updater.install_release(plugin, "0.10.0")
                        self.assertEqual(updater.manifest_version(plugin), "0.9.4")
                        self.assertIn("user edit", modified.read_text())

                        modified.write_text(original)
                        if copied:
                            (plugin / ".omapandora-dev-install").unlink()
                            modified.write_text(original + "// synced customization\n")
                        updater.install_release(plugin, "0.10.0")

                    self.assertEqual(updater.manifest_version(plugin), "0.10.0")
                    self.assertTrue((plugin / "qml-0.10.0/Player.qml").exists())
                    self.assertFalse((plugin / "qml-0.9.4").exists())
                    self.assertEqual((plugin / ".git").is_dir(), not copied)
                    if copied:
                        backups = list(plugin.parent.glob(f".{updater.PLUGIN_ID}.old.*/plugin"))
                        self.assertEqual(len(backups), 1)
                        self.assertIn("synced customization",
                                      (backups[0] / "qml-0.9.4/Player.qml").read_text())
                        self.assertTrue((plugin / ".omapandora-dev-install").is_file())

    def commit_version(self, repo, version):
        existing = next(repo.glob("qml-*"), None)
        if existing:
            shutil.rmtree(existing)
        ui = repo / f"qml-{version}"
        ui.mkdir()
        (ui / "Player.qml").write_text("import QtQuick\nItem {}\n")
        (repo / "manifest.json").write_text(json.dumps({
            "schemaVersion": 1,
            "id": updater.PLUGIN_ID,
            "version": version,
            "name": "Micro-Pandora Test",
            "author": "Micro-Pandora",
            "description": "Test player",
            "kinds": ["panel"],
            "entryPoints": {"panel": f"qml-{version}/Player.qml"},
        }))
        updater.git(repo, "add", "-A")
        updater.git(repo, "commit", "-qm", version)
        return updater.git(repo, "rev-parse", "HEAD").decode().strip()
