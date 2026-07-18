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
REQUIRED_IDS.update({"siteHeader", "heroStage"})
PRODUCT_SECTIONS = {
    "value", "status", "approval", "usage",
    "return", "integrations", "privacy", "download",
}
REQUIRED_ACTIONS = {"allow", "review", "deny"}
MIN_AGENT_ROWS = 3


class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.scripts = []
        self.lang_buttons = set()
        self.i18n_keys = set()
        self.images_without_alt = []
        self.h1_count = 0
        self.skip_link_target = None
        self.notch_toggle_controls = None
        self.section_stack = []
        self.section_headings = {}
        self.section_i18n = {}
        self.data_actions = set()
        self.agent_rows = 0

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        classes = values.get("class", "").split()
        if values.get("id"):
            self.ids.add(values["id"])
        if tag == "section" and values.get("id") in PRODUCT_SECTIONS:
            sid = values["id"]
            self.section_stack.append(sid)
            self.section_headings.setdefault(sid, 0)
            self.section_i18n.setdefault(sid, 0)
        if tag in ("h2", "h3") and self.section_stack:
            self.section_headings[self.section_stack[-1]] += 1
        if values.get("data-action"):
            self.data_actions.add(values["data-action"])
        if "agent-row" in classes:
            self.agent_rows += 1
        if tag == "h1":
            self.h1_count += 1
        if tag == "a" and values.get("href") == "#main":
            self.skip_link_target = "#main"
        if values.get("id") == "notchToggle":
            self.notch_toggle_controls = values.get("aria-controls")
        if values.get("data-i18n"):
            self.i18n_keys.add(values["data-i18n"])
            if self.section_stack:
                self.section_i18n[self.section_stack[-1]] += 1
        if values.get("data-lang"):
            self.lang_buttons.add(values["data-lang"])
        if tag == "link" and values.get("rel") == "stylesheet":
            self.links.append(values.get("href", ""))
        if tag == "script" and values.get("src"):
            self.scripts.append(values["src"])
        if tag == "img" and "alt" not in values:
            self.images_without_alt.append(values.get("src", "<unknown>"))

    def handle_endtag(self, tag):
        if tag == "section" and self.section_stack:
            self.section_stack.pop()


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

    if parser.h1_count != 1:
        ok = fail(f"exactly one <h1> is required, found {parser.h1_count}") and ok
    if parser.skip_link_target != "#main":
        ok = fail("a skip link targeting #main is required") and ok
    if parser.notch_toggle_controls != "notchPanel":
        ok = fail('#notchToggle must set aria-controls="notchPanel"') and ok

    downloads = re.findall(
        r"https://api\.agentdockstatus\.app/v1/download/AgentDock-[0-9.]+\.dmg",
        text,
    )
    if len(downloads) < 2:
        ok = fail("at least two versioned DMG links are required") and ok

    for sid in sorted(PRODUCT_SECTIONS):
        if parser.section_headings.get(sid, 0) < 1:
            ok = fail(f"section #{sid} must contain at least one heading") and ok
        if parser.section_i18n.get(sid, 0) < 1:
            ok = fail(f"section #{sid} must contain at least one [data-i18n] node") and ok

    missing_actions = REQUIRED_ACTIONS - parser.data_actions
    if missing_actions:
        ok = fail(f"approval actions missing: {sorted(missing_actions)}") and ok

    if parser.agent_rows < MIN_AGENT_ROWS:
        ok = fail(
            f"at least {MIN_AGENT_ROWS} .agent-row elements required, "
            f"found {parser.agent_rows}"
        ) and ok

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
