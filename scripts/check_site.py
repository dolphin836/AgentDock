#!/usr/bin/env python3
from html.parser import HTMLParser
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
HTML = SITE / "index.html"
REQUIRED_FILES = ("styles.css", "main.js")
REQUIRED_IDS = {
    "main", "top", "value", "status", "approval", "usage",
    "return", "integrations", "privacy", "download",
    "notchToggle", "notchPanel", "approvalPanel", "approvalStatus",
}


class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.scripts = []
        self.lang_buttons = set()
        self.i18n_keys = set()
        self.images_without_alt = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"])
        if values.get("data-i18n"):
            self.i18n_keys.add(values["data-i18n"])
        if values.get("data-lang"):
            self.lang_buttons.add(values["data-lang"])
        if tag == "link" and values.get("rel") == "stylesheet":
            self.links.append(values.get("href", ""))
        if tag == "script" and values.get("src"):
            self.scripts.append(values["src"])
        if tag == "img" and "alt" not in values:
            self.images_without_alt.append(values.get("src", "<unknown>"))


def fail(message):
    print(f"FAIL: {message}")
    return False


def main():
    ok = True
    text = HTML.read_text(encoding="utf-8")
    parser = SiteParser()
    parser.feed(text)

    for name in REQUIRED_FILES:
        if not (SITE / name).is_file():
            ok = fail(f"missing site/{name}") and ok

    missing_ids = REQUIRED_IDS - parser.ids
    if missing_ids:
        ok = fail(f"missing ids: {sorted(missing_ids)}") and ok

    if "./styles.css" not in parser.links:
        ok = fail("index.html must load ./styles.css") and ok
    if "./main.js" not in parser.scripts:
        ok = fail("index.html must load ./main.js") and ok
    if parser.lang_buttons != {"en", "zh"}:
        ok = fail("language controls must provide en and zh") and ok
    if parser.images_without_alt:
        ok = fail(f"images missing alt: {parser.images_without_alt}") and ok

    downloads = re.findall(
        r"https://api\.agentdockstatus\.app/v1/download/AgentDock-[0-9.]+\.dmg",
        text,
    )
    if len(downloads) < 2:
        ok = fail("at least two versioned DMG links are required") and ok

    js = (SITE / "main.js").read_text(encoding="utf-8") if (SITE / "main.js").exists() else ""
    js_keys = set(re.findall(r"^\s+([A-Za-z][A-Za-z0-9]+):", js, re.MULTILINE))
    missing_keys = parser.i18n_keys - js_keys
    if missing_keys:
        ok = fail(f"translation keys missing from main.js: {sorted(missing_keys)}") and ok

    if ok:
        print("PASS: site contract")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
