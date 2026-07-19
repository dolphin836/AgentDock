#!/usr/bin/env python3
# [skill: go-team-standards · 可复现发布测试] 在临时 HTML 副本验证版本替换且保护真实首页
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "site" / "index.html"
UPDATER = ROOT / "scripts" / "update_site_release.py"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class UpdateSiteReleaseTests(unittest.TestCase):
    def test_updates_temp_copy_and_leaves_real_index_unchanged(self) -> None:
        before = sha256(INDEX)
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / "index.html"
            shutil.copyfile(INDEX, copy)
            fixture = copy.read_text(encoding="utf-8")
            fixture += (
                "\n<a href=\"https://api.agentdockstatus.app/v1/download/"
                "AgentDock-0.1.0.pkg\">legacy package</a>\n"
                "<span>v0.1.0</span>\n"
            )
            copy.write_text(fixture, encoding="utf-8")

            subprocess.run(
                [
                    sys.executable,
                    str(UPDATER),
                    "--html",
                    str(copy),
                    "--version",
                    "9.9.9",
                    "--url",
                    "https://api.agentdockstatus.app/v1/download/"
                    "AgentDock-9.9.9.dmg",
                ],
                cwd=ROOT,
                check=True,
            )

            updated = copy.read_text(encoding="utf-8")
            links = re.findall(
                r"https://api\.agentdockstatus\.app/v1/download/"
                r"AgentDock-[0-9.]+\.(?:pkg|dmg)",
                updated,
            )
            self.assertEqual(len(links), 6)
            self.assertEqual(
                set(links),
                {
                    "https://api.agentdockstatus.app/v1/download/"
                    "AgentDock-9.9.9.dmg",
                },
            )
            self.assertIn("<b>v9.9.9</b>", updated)
            self.assertIn("<span>v9.9.9</span>", updated)

        self.assertEqual(sha256(INDEX), before)


if __name__ == "__main__":
    unittest.main()
