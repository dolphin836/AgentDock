#!/usr/bin/env python3
# [skill: go-team-standards · 可复现发布测试] 在临时 HTML 副本验证版本替换且保护真实首页
# 覆盖的是兼容性 patch 工具(update_site_release.py);权威发布路径是 Next env 重建,
# 见 design-qa.md。工具与断言均只接受 .dmg 制品。
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
                "AgentDock-0.1.0.dmg\">legacy download</a>\n"
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
                r"AgentDock-[0-9.]+\.dmg",
                updated,
            )
            self.assertGreaterEqual(len(links), 2)
            self.assertEqual(
                set(links),
                {
                    "https://api.agentdockstatus.app/v1/download/"
                    "AgentDock-9.9.9.dmg",
                },
            )
            self.assertIn("<span>v9.9.9</span>", updated)

        self.assertEqual(sha256(INDEX), before)

    def test_updates_next_exported_version_markup_and_every_download_url(self) -> None:
        before = sha256(INDEX)
        source = (
            '<a href="https://api.agentdockstatus.app/v1/download/AgentDock-0.2.4.dmg">'
            "Download</a>"
            '<a download="AgentDock-0.2.4.dmg" href="https://api.agentdockstatus.app/v1/download/'
            'AgentDock-0.2.4.dmg">Download</a>'
            "<span>v<!-- -->0.2.4</span>"
            '<meta content="AgentDock v0.2.4" name="release"/>'
            '<section data-version="0.2.4"></section>'
            '<script>self.__next_f.push(["v0.2.4","AgentDock-0.2.4.dmg"])</script>'
        )
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / "index.html"
            copy.write_text(source, encoding="utf-8")

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
            self.assertNotIn("0.2.4", updated)
            self.assertNotIn("AgentDock-0.2.4.dmg", updated)
            self.assertEqual(updated.count("AgentDock-9.9.9.dmg"), 4)
            self.assertIn("v<!-- -->9.9.9", updated)
            self.assertIn("AgentDock v9.9.9", updated)
            self.assertIn('data-version="9.9.9"', updated)
            self.assertIn('"v9.9.9"', updated)

        self.assertEqual(sha256(INDEX), before)


if __name__ == "__main__":
    unittest.main()
