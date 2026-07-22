#!/usr/bin/env python3
# [skill: go-team-standards · 部署发布] 校验 Next.js 静态导出发布契约
"""Validate published Next.js static output, not retired single-file internals."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
HTML = SITE / "index.html"
DMG_URL = "https://api.agentdockstatus.app/v1/download/AgentDock-0.2.4.dmg"
# React can split a text node like `v0.2.4` around a comment marker
# (`v<!-- -->0.2.4`) in the static export, so match the label tolerantly.
VERSION_LABEL_PATTERN = re.compile(r"v(?:<!--\s*-->)?0\.2\.4")
REQUIRED_IDS = {
    "main-content", "top", "voice", "meeting", "integrations", "privacy",
    "download", "final-cta-heading", "site-menu",
}
HEADER_IDS = {"top"}


class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.id_counts = {}
        self.headers = {}
        self.runtime_resources = []
        self.skip_target = None
        self.menu_button = None
        self.menu = None
        self.section_count = 0
        self.footer_count = 0

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "section":
            self.section_count += 1
        if tag == "footer":
            self.footer_count += 1
        identifier = values.get("id")
        if identifier:
            self.ids.add(identifier)
            self.id_counts[identifier] = self.id_counts.get(identifier, 0) + 1
            if identifier in HEADER_IDS:
                self.headers[identifier] = values.get("data-header")
        if tag == "a" and values.get("href") == "#main-content":
            self.skip_target = values["href"]
        if tag == "script" and values.get("src"):
            self.runtime_resources.append(("script", values["src"]))
        if tag == "link" and values.get("rel") == "stylesheet":
            self.runtime_resources.append(("stylesheet", values.get("href", "")))
        if "data-mobile-menu-button" in values:
            self.menu_button = values
        if identifier == "site-menu":
            self.menu = values


def fail(message):
    print(f"FAIL: {message}")
    return False


def local_asset_exists(url):
    path = url.split("?", 1)[0].lstrip("/")
    return bool(path) and (SITE / path).is_file()


def main():
    ok = True
    if not HTML.is_file():
        return 1 if fail("missing site/index.html") else 1
    text = HTML.read_text(encoding="utf-8")
    parser = Parser()
    parser.feed(text)

    if not (SITE / "_next").is_dir():
        ok = fail("missing site/_next static export assets") and ok
    if not (SITE / "macos").is_dir():
        ok = fail("missing retained site/macos directory") and ok
    for name in ("admin.html", "version.json"):
        if not (SITE / name).is_file():
            ok = fail(f"missing retained release asset site/{name}") and ok
    if "AgentDock" not in text or not any((SITE / "macos").rglob("*")):
        ok = fail("missing AgentDock first-party site assets") and ok
    if not (SITE / "hero-dot-grid.png").is_file():
        ok = fail("missing dotted hero background asset") and ok

    for kind, url in parser.runtime_resources:
        if url.lower().startswith(("http://", "https://", "//")):
            ok = fail(f"remote runtime {kind}: {url}") and ok
        elif not local_asset_exists(url):
            ok = fail(f"missing local runtime {kind}: {url}") and ok

    missing = sorted(REQUIRED_IDS - parser.ids)
    if missing:
        ok = fail(f"missing or non-unique critical ids: {missing}") and ok
    duplicate_ids = sorted(
        identifier
        for identifier in REQUIRED_IDS
        if parser.id_counts.get(identifier, 0) != 1
    )
    if duplicate_ids:
        ok = fail(f"critical ids must be unique: {duplicate_ids}") and ok
    if '<html lang="en"' not in text or 'name="viewport"' not in text:
        ok = fail("missing exported HTML language or viewport metadata") and ok
    if 'name="description"' not in text:
        ok = fail("missing exported page description metadata") and ok
    for identifier in sorted(HEADER_IDS):
        if parser.headers.get(identifier) not in {"dark", "light"}:
            ok = fail(f"#{identifier} must declare data-header=dark|light") and ok
    if parser.skip_target != "#main-content":
        ok = fail("missing skip link to #main-content") and ok
    if parser.section_count != 1 or parser.footer_count != 0:
        ok = fail(
            f"homepage must contain exactly one section and no footer "
            f"(sections={parser.section_count}, footers={parser.footer_count})"
        ) and ok
    if (
        not parser.menu_button
        or parser.menu_button.get("aria-controls") != "site-menu"
        or "aria-expanded" not in parser.menu_button
    ):
        ok = fail("mobile menu button needs aria-controls and aria-expanded") and ok
    if (
        not parser.menu
        or parser.menu.get("role") != "dialog"
        or parser.menu.get("aria-modal") != "true"
    ):
        ok = fail("#site-menu needs dialog role and aria-modal=true") and ok
    if text.count(DMG_URL) < 2 or not VERSION_LABEL_PATTERN.search(text):
        ok = fail("missing real AgentDock v0.2.4 DMG URL or version") and ok
    try:
        release = json.loads((SITE / "version.json").read_text(encoding="utf-8"))
        if release.get("version") != "0.2.4" or release.get("dmg") != DMG_URL:
            ok = fail("site/version.json does not retain v0.2.4 DMG") and ok
    except (OSError, json.JSONDecodeError) as error:
        ok = fail(f"invalid site/version.json: {error}") and ok

    if ok:
        print("PASS: Next.js static site contract")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
