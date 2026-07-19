#!/usr/bin/env python3
# [skill: go-team-standards · dev-dna] 校验本地动效依赖并禁止运行时 CDN
import hashlib
from html.parser import HTMLParser
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
HTML = SITE / "index.html"
REQUIRED_FILES = ("styles.css", "main.js")
VENDOR_SHA256 = {
    "three.core.min.js": "05b2609338c76cd65daf74f3ac515bc9a5045e1b3b33edc07d8c9bd55250fa90",
    "three.module.min.js": "86bcee248b64f44bcfc23c331ae74619061957d59cab040171dcb6fb5900beb6",
    "gsap.min.js": "92bb9a96476f983d212a2bc4f54c889039c1696dd4461d40a736860938570fbb",
    "ScrollTrigger.min.js": "b0b14d67b55b0c43c756ac0b106cfcb09d0879945f6ead64451065b0672916a2",
    "LICENSES.txt": "cd3202138b82af70f2003c3f51b70cd993806cec4a3c1bbd9893dc06f1dac3dd",
}
# Module entry points and scene IDs are activated with their implementations:
# Task 2 owns navigation IDs, Task 3 owns the hero scene, and Task 4 owns
# motion.js, the context scene, and the journey scene. Requiring them here
# would reward empty placeholder nodes instead of tested behavior.
REMOTE_RUNTIME_PREFIXES = ("http://", "https://", "//")
CSS_URL_PATTERN = re.compile(
    r"""url\(\s*(?P<quote>["']?)(?P<url>.*?)(?P=quote)\s*\)""",
    re.IGNORECASE,
)
CSS_IMPORT_PATTERN = re.compile(
    r"""@import\s+["'](?P<url>[^"']+)["']""",
    re.IGNORECASE,
)
JS_IMPORT_SPECIFIER_PATTERN = re.compile(
    r"""(?:\b(?:import|export)(?![\w$])\s*(?:[^"'();]*?\bfrom\s*)?|"""
    r"""\bimport(?![\w$])\s*\(\s*)["'](?P<url>[^"']+)["']""",
    re.MULTILINE,
)
REQUIRED_IDS = {
    "main", "top", "value", "status", "approval", "usage",
    "return", "integrations", "privacy", "download",
    "notchToggle", "notchPanel", "approvalPanel", "approvalStatus",
}
REQUIRED_IDS.update({"siteHeader", "heroStage"})
# Task 2 owns the adaptive navigation, intro curtain, and mobile menu nodes.
REQUIRED_IDS.update({"menuButton", "mobileMenu", "introCurtain"})
# Task 3 owns the one-viewport particle hero: the full-cover WebGL canvas.
REQUIRED_IDS.update({"heroCanvas"})
# Task 4 owns the chapter choreography: capability panels overview, the second
# (context) particle scene, and the pinned horizontal product journey.
REQUIRED_IDS.update(
    {"capabilities", "context", "journey", "contextCanvas",
     "journeyViewport", "journeyTrack", "journeyProgress"}
)
PRODUCT_SECTIONS = {
    "value", "status", "approval", "usage",
    "return", "integrations", "privacy", "download",
    "capabilities", "context", "journey",
}
# Every hero and product section must declare an explicit nav theme so the
# header foreground follows dark/light chapters (design §4.1).
SECTION_THEME_IDS = PRODUCT_SECTIONS | {"top"}
SECTION_THEME_VALUES = {"dark", "light"}
REQUIRED_ACTIONS = {"allow", "review", "deny"}
DEMO_STATES = {"running", "waiting", "usage"}
MIN_AGENT_ROWS = 3
# [skill: go-team-standards · 文案事实契约] 防止集成恢复与遥测边界被再次过度概括
REQUIRED_COPY = {
    "index.html": (
        "backs up integration settings before installation",
        "removes AgentDock's own entries",
        "restores prior settings where they can be recovered",
        "uses an installation-level identifier",
        "does not include session content or file paths",
    ),
    "main.js": (
        "backs up integration settings before installation",
        "removes AgentDock's own entries",
        "restores prior settings where they can be recovered",
        "安装前备份集成配置",
        "只移除 AgentDock 自身写入的配置",
        "仅在原设置可恢复时还原",
        "uses an installation-level identifier",
        "does not include session content or file paths",
        "使用安装级标识",
        "不包含会话内容或文件路径",
    ),
}
FORBIDDEN_COPY = (
    "restores it on uninstall",
    "并在卸载时还原",
    "anonymous launch",
    "匿名的启动",
)


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
        self.demo_views = set()
        self.demo_views_with_text = set()
        self.agent_rows = 0
        self.notch_toggle_expanded = None
        self.notch_toggle_label = None
        self.language_toggle_group_role = None
        self.approval_status_live = None
        self.lang_buttons_pressed = set()
        self.buttons_without_text = []
        self._button_stack = []
        self.section_themes = {}
        self.menu_button_expanded = None
        self.menu_button_controls = None
        self.menu_button_label = None
        self.mobile_menu_hidden = None
        self.mobile_menu_inert = None

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
        if tag == "section" and values.get("id") in SECTION_THEME_IDS:
            self.section_themes[values["id"]] = values.get("data-header")
        if values.get("id") == "menuButton":
            self.menu_button_expanded = values.get("aria-expanded")
            self.menu_button_controls = values.get("aria-controls")
            self.menu_button_label = values.get("aria-label")
        if values.get("id") == "mobileMenu":
            self.mobile_menu_hidden = values.get("aria-hidden")
            self.mobile_menu_inert = "inert" in values
        if tag in ("h2", "h3") and self.section_stack:
            self.section_headings[self.section_stack[-1]] += 1
        if values.get("data-action"):
            self.data_actions.add(values["data-action"])
        if values.get("data-demo-view"):
            state = values["data-demo-view"]
            self.demo_views.add(state)
            if values.get("data-i18n"):
                self.demo_views_with_text.add(state)
        if "agent-row" in classes:
            self.agent_rows += 1
        if tag == "h1":
            self.h1_count += 1
        if tag == "a" and values.get("href") == "#main":
            self.skip_link_target = "#main"
        if values.get("id") == "notchToggle":
            self.notch_toggle_controls = values.get("aria-controls")
            self.notch_toggle_expanded = values.get("aria-expanded")
            self.notch_toggle_label = values.get("aria-label")
        if "language-toggle" in classes:
            self.language_toggle_group_role = values.get("role")
        if values.get("id") == "approvalStatus":
            self.approval_status_live = values.get("aria-live")
        if values.get("data-i18n"):
            self.i18n_keys.add(values["data-i18n"])
            if self.section_stack:
                self.section_i18n[self.section_stack[-1]] += 1
        if values.get("data-lang"):
            self.lang_buttons.add(values["data-lang"])
            if "aria-pressed" in values:
                self.lang_buttons_pressed.add(values["data-lang"])
        if tag == "button":
            self._button_stack.append(
                {"label": bool(values.get("aria-label")), "text": []}
            )
        if tag == "link" and values.get("rel") == "stylesheet":
            self.links.append(values.get("href", ""))
        if tag == "script" and values.get("src"):
            self.scripts.append(values["src"])
        if tag == "img" and "alt" not in values:
            self.images_without_alt.append(values.get("src", "<unknown>"))

    def handle_data(self, data):
        if self._button_stack:
            self._button_stack[-1]["text"].append(data)

    def handle_endtag(self, tag):
        if tag == "section" and self.section_stack:
            self.section_stack.pop()
        if tag == "button" and self._button_stack:
            button = self._button_stack.pop()
            accessible = button["label"] or "".join(button["text"]).strip()
            if not accessible:
                self.buttons_without_text.append("<button>")


class RuntimeResourceParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.resources = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "script" and values.get("src"):
            self.resources.append(("script", values["src"]))
        if tag == "link" and values.get("href"):
            self.resources.append(("link", values["href"]))


def fail(message):
    print(f"FAIL: {message}")
    return False


def is_remote_runtime_url(url):
    return url.strip().lower().startswith(REMOTE_RUNTIME_PREFIXES)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(64 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


# [skill: go-team-standards · dev-dna] 分语言提取翻译键，确保双语契约对称
def extract_translation_keys(js, language):
    match = re.search(
        rf"^[ \t]{{4}}{language}: \{{\n(?P<body>.*?)^[ \t]{{4}}\}},?$",
        js,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        return None
    return set(
        re.findall(
            r"^[ \t]{6}([A-Za-z][A-Za-z0-9]+):",
            match.group("body"),
            re.MULTILINE,
        )
    )


def main():
    ok = True
    text = HTML.read_text(encoding="utf-8")
    parser = SiteParser()
    parser.feed(text)

    for name in REQUIRED_FILES:
        if not (SITE / name).is_file():
            ok = fail(f"missing site/{name}") and ok

    for name, expected_sha256 in VENDOR_SHA256.items():
        vendor_file = SITE / "vendor" / name
        if not vendor_file.is_file():
            ok = fail(f"missing site/vendor/{name}") and ok
            continue
        actual_sha256 = sha256_file(vendor_file)
        if actual_sha256 != expected_sha256:
            ok = fail(
                f"site/vendor/{name} SHA-256 mismatch: "
                f"expected {expected_sha256}, got {actual_sha256}"
            ) and ok

    runtime_sources = [
        path
        for path in SITE.rglob("*")
        if path.is_file()
        and path.suffix in {".html", ".css", ".js"}
    ]
    for path in runtime_sources:
        content = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(ROOT)
        if path.suffix == ".html":
            resource_parser = RuntimeResourceParser()
            resource_parser.feed(content)
            for tag, url in resource_parser.resources:
                if is_remote_runtime_url(url):
                    ok = fail(
                        f"{relative_path} has remote <{tag}> runtime resource: {url}"
                    ) and ok
        elif path.suffix == ".css":
            css_urls = [
                match.group("url").strip()
                for match in CSS_URL_PATTERN.finditer(content)
            ]
            css_urls.extend(
                match.group("url").strip()
                for match in CSS_IMPORT_PATTERN.finditer(content)
            )
            for url in css_urls:
                if is_remote_runtime_url(url):
                    ok = fail(
                        f"{relative_path} has remote CSS runtime resource: {url}"
                    ) and ok
        elif path.suffix == ".js":
            import_urls = {
                match.group("url").strip()
                for match in JS_IMPORT_SPECIFIER_PATTERN.finditer(content)
            }
            for url in sorted(import_urls):
                if is_remote_runtime_url(url):
                    ok = fail(
                        f"{relative_path} has remote JavaScript import: {url}"
                    ) and ok
                if path.name == "three.module.min.js" and url.startswith(("./", "../")):
                    dependency = (path.parent / url).resolve()
                    if not dependency.is_file():
                        ok = fail(
                            f"{relative_path} imports missing dependency: {url}"
                        ) and ok

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
    if parser.notch_toggle_expanded is None:
        ok = fail("#notchToggle must expose aria-expanded state") and ok
    if not parser.notch_toggle_label:
        ok = fail("#notchToggle must have an accessible name") and ok
    if parser.language_toggle_group_role != "group":
        ok = fail(".language-toggle must set role=\"group\"") and ok
    if parser.approval_status_live != "polite":
        ok = fail('#approvalStatus must set aria-live="polite"') and ok
    if parser.lang_buttons_pressed != {"en", "zh"}:
        ok = fail("both language buttons must expose aria-pressed state") and ok
    if parser.buttons_without_text:
        ok = fail(
            f"buttons without accessible text: {parser.buttons_without_text}"
        ) and ok

    # --- Task 2: adaptive navigation, intro curtain, mobile menu ---
    for sid in sorted(SECTION_THEME_IDS):
        theme = parser.section_themes.get(sid)
        if theme is None:
            ok = fail(f'section #{sid} must declare data-header="dark|light"') and ok
        elif theme not in SECTION_THEME_VALUES:
            ok = fail(
                f'section #{sid} data-header must be dark|light, got {theme!r}'
            ) and ok
    if parser.menu_button_expanded is None:
        ok = fail("#menuButton must expose aria-expanded state") and ok
    if parser.menu_button_controls != "mobileMenu":
        ok = fail('#menuButton must set aria-controls="mobileMenu"') and ok
    if not parser.menu_button_label:
        ok = fail("#menuButton must have an accessible name") and ok
    if parser.mobile_menu_hidden != "true":
        ok = fail('#mobileMenu must start with aria-hidden="true"') and ok
    if parser.mobile_menu_inert is not True:
        ok = fail("#mobileMenu must start inert") and ok
    nav_list_match = re.search(
        r'<ul\s+class="nav-links"[^>]*>(?P<body>.*?)</ul>',
        text,
        re.DOTALL,
    )
    if not nav_list_match:
        ok = fail("index.html must contain .nav-links list") and ok
    elif "nav-indicator" in nav_list_match.group("body"):
        ok = fail(".nav-links <ul> must contain only list items; move indicator outside") and ok
    if not re.search(
        r'</ul>\s*<span\s+class="nav-indicator"\s+aria-hidden="true"></span>',
        text,
    ):
        ok = fail(".nav-indicator must be a sibling immediately after .nav-links") and ok
    if '<noscript>' not in text or 'class="nojs-mobile-nav"' not in text:
        ok = fail("index.html must provide a <noscript> mobile navigation fallback") and ok
    if 'class="mobile-nav" aria-label="Mobile navigation"' not in text:
        ok = fail(".mobile-nav must start with an English accessible name") and ok

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
    css = (SITE / "styles.css").read_text(encoding="utf-8") if (SITE / "styles.css").exists() else ""
    copy_files = {"index.html": text, "main.js": js}
    for name, required_snippets in REQUIRED_COPY.items():
        for snippet in required_snippets:
            if snippet not in copy_files[name]:
                ok = fail(f"{name} missing required factual copy: {snippet!r}") and ok
    for snippet in FORBIDDEN_COPY:
        for name, content in copy_files.items():
            if snippet in content:
                ok = fail(f"{name} contains forbidden copy: {snippet!r}") and ok

    en_keys = extract_translation_keys(js, "en")
    zh_keys = extract_translation_keys(js, "zh")
    if en_keys is None:
        ok = fail("could not extract en translation keys from main.js") and ok
        en_keys = set()
    if zh_keys is None:
        ok = fail("could not extract zh translation keys from main.js") and ok
        zh_keys = set()

    missing_from_zh = en_keys - zh_keys
    if missing_from_zh:
        ok = fail(f"translation keys missing from zh: {sorted(missing_from_zh)}") and ok
    missing_from_en = zh_keys - en_keys
    if missing_from_en:
        ok = fail(f"translation keys missing from en: {sorted(missing_from_en)}") and ok

    missing_keys = parser.i18n_keys - (en_keys & zh_keys)
    if missing_keys:
        ok = fail(f"translation keys missing from main.js: {sorted(missing_keys)}") and ok
    required_accessibility_keys = {
        "notchToggleLabel",
        "navMenu",
        "mobileNavLabel",
    }
    missing_accessibility_keys = required_accessibility_keys - (en_keys & zh_keys)
    if missing_accessibility_keys:
        ok = fail(
            "accessibility translation keys missing from main.js: "
            f"{sorted(missing_accessibility_keys)}"
        ) and ok
    if (
        'notchToggle.setAttribute("aria-label", translations[currentLanguage].notchToggleLabel)'
        not in js
    ):
        ok = fail("language changes must update #notchToggle aria-label") and ok
    if (
        'mobileNav.setAttribute("aria-label", translations[currentLanguage].mobileNavLabel)'
        not in js
    ):
        ok = fail("language changes must update .mobile-nav aria-label") and ok

    if parser.demo_views != DEMO_STATES:
        ok = fail(
            f"visible demo states must be {sorted(DEMO_STATES)}, "
            f"found {sorted(parser.demo_views)}"
        ) and ok
    missing_text_states = DEMO_STATES - parser.demo_views_with_text
    if missing_text_states:
        ok = fail(
            "demo states need visible translated text, missing: "
            f"{sorted(missing_text_states)}"
        ) and ok
    for state in sorted(DEMO_STATES):
        selector = (
            f'[data-active-state="{state}"] '
            f'[data-demo-view="{state}"]'
        )
        if selector not in css:
            ok = fail(f"styles.css missing visible demo state selector: {selector}") and ok

    for query in ("@media (max-width: 980px)", "@media (max-width: 700px)"):
        if query not in css:
            ok = fail(f"styles.css missing responsive breakpoint: {query}") and ok
    if "@media (prefers-reduced-motion: reduce)" not in css:
        ok = fail("styles.css missing prefers-reduced-motion overrides") and ok
    required_css_contracts = (
        ".light-section .chapter-index { color: var(--coral-deep); }",
        ".dark-section .chapter-index { color: var(--coral); }",
        ".light-section .value-num { color: var(--coral-deep); }",
        ".dark-section .value-num { color: var(--coral); }",
        "--text-faint: oklch(0.69 0.016 74);",
    )
    for contract in required_css_contracts:
        if contract not in css:
            ok = fail(f"styles.css missing accessibility contract: {contract}") and ok
    if not re.search(
        r"\.approval-agent\s*\{[^}]*color:\s*var\(--coral-deep\)",
        css,
        re.DOTALL,
    ):
        ok = fail(
            "styles.css must give .approval-agent a light-surface contrast color"
        ) and ok

    # [skill: go-team-standards · Vokie 1:1] 导航形态、指示线、移动菜单与 curtain 的样式契约
    required_nav_css = (
        ".nav-shell",
        ".site-header.is-condensed",
        "min(920px, calc(100% - 32px))",
        "blur(14px)",
        ".site-header.is-hidden",
        ".nav-indicator",
        ".menu-squares",
        ".mobile-menu",
        "blur(12px)",
        "clip-path: inset(",
        "@media (max-width: 900px)",
        "@media (max-width: 680px)",
        ".intro-curtain",
        ".has-js .menu-button",
        ".nojs-mobile-nav",
    )
    for contract in required_nav_css:
        if contract not in css:
            ok = fail(f"styles.css missing navigation contract: {contract}") and ok

    # 滚动形态与降级行为契约（行为测试在浏览器中验证，这里只锁定关键常量与钩子）
    required_nav_js = (
        "condenseRatio = 0.22",
        "scrollHideDelta = 12",
        "header.dataset.header",
        "curtain-active",
        "<= 680",
        "setTimeout",
        '"Tab"',
        "inert",
        "restoreFocus",
        "focusHashTarget",
        'target.setAttribute("tabindex", "-1")',
        "target.scrollIntoView()",
        "restoreFocus: false",
    )
    for contract in required_nav_js:
        if contract not in js:
            ok = fail(f"main.js missing navigation behavior hook: {contract}") and ok
    if (
        'menuButton.setAttribute("aria-label", translations[currentLanguage].navMenu)'
        not in js
    ):
        ok = fail("language changes must update #menuButton aria-label") and ok

    # [skill: go-team-standards · 文案事实契约] stageNote 声称"聚焦刘海即可展开"，
    # 行为必须以 focusin 兜住该可及性承诺，避免文案与交互不一致（已知 Minor）。
    stage_notes = re.findall(r'stageNote:\s*"([^"]*)"', js)
    stage_note_claims_focus = any(
        ("focus" in note or "聚焦" in note) for note in stage_notes
    )
    if stage_note_claims_focus and "focusin" not in js:
        ok = fail(
            "stage note claims focus opens the notch, but main.js has no focusin handler"
        ) and ok

    # [skill: go-team-standards · 可及性回归] Escape 关闭刘海后不得重新触发 focusin 打开面板。
    escape_handler = re.search(
        r'document\.addEventListener\("keydown", \(event\) => \{(?P<body>.*?)\n    \}\);',
        js,
        re.DOTALL,
    )
    if not escape_handler or 'event.key === "Escape"' not in escape_handler.group("body"):
        ok = fail("a keydown Escape handler is required to close the notch") and ok
    elif "setNotch(false)" not in escape_handler.group("body"):
        ok = fail("Escape notch handler must close the notch") and ok
    elif "notchToggle.focus()" in escape_handler.group("body"):
        ok = fail(
            "Escape notch handler must not refocus #notchToggle after closing it"
        ) and ok

    # [skill: go-team-standards · Vokie 1:1] Task 3: one-viewport particle hero
    # 静态锁定关键机制常量与降级钩子；粒子数量/收束/暂停/降级由浏览器行为测试验证。
    hero_particles = SITE / "hero-particles.js"
    motion_js = SITE / "motion.js"
    for name in ("hero-particles.js", "motion.js"):
        if not (SITE / name).is_file():
            ok = fail(f"missing site/{name}") and ok

    required_hero_scripts = (
        "./vendor/gsap.min.js",
        "./vendor/ScrollTrigger.min.js",
        "./hero-particles.js",
        "./motion.js",
    )
    for src in required_hero_scripts:
        if src not in parser.scripts:
            ok = fail(f"index.html must load {src}") and ok
    for module_src in ("./hero-particles.js", "./motion.js"):
        if not re.search(
            rf'<script[^>]*\btype="module"[^>]*\bsrc="{re.escape(module_src)}"'
            rf'|<script[^>]*\bsrc="{re.escape(module_src)}"[^>]*\btype="module"',
            text,
        ):
            ok = fail(f"{module_src} must be loaded as type=module") and ok

    hero_particles_js = (
        hero_particles.read_text(encoding="utf-8") if hero_particles.is_file() else ""
    )
    motion_source = motion_js.read_text(encoding="utf-8") if motion_js.is_file() else ""
    # 结构化/散乱双位置 shader、粒子数量分级、DPR 上限、可见性/离屏暂停、
    # reduced-motion 静态、WebGL 失败降级钩子。
    required_hero_particles = (
        "./vendor/three.module.min.js",
        "uProgress",
        "aScatter",
        "aStructured",
        "2200",
        "1200",
        "powerPreference",
        "1.5",
        "visibilitychange",
        "IntersectionObserver",
        "prefers-reduced-motion",
        "particles-active",
        'reducedMotion.addEventListener("change"',
        '"webglcontextlost"',
        "preventDefault()",
        "beginFallbackConvergence",
    )
    for contract in required_hero_particles:
        if contract not in hero_particles_js:
            ok = fail(f"hero-particles.js missing hero contract: {contract}") and ok

    # GSAP 驱动 1.9s 收束、标题裁切入场、motion-ready 门控与 reduced-motion 静态。
    required_motion = (
        "gsap",
        "1.9",
        "motion-ready",
        "clipPath",
        "prefers-reduced-motion",
        '"agentdock:curtain-exit-start"',
        '"agentdock:curtain-skipped"',
        "rollbackHeroMotion",
        "beginFallbackConvergence",
    )
    for contract in required_motion:
        if contract not in motion_source:
            ok = fail(f"motion.js missing hero contract: {contract}") and ok

    playback_guard = re.search(
        r"requestAnimationFrame\(\(\) => \{(?P<body>.*?)\n\s*\}\);",
        motion_source,
        re.DOTALL,
    )
    if not playback_guard:
        ok = fail("motion.js must start deferred GSAP playback in requestAnimationFrame") and ok
    else:
        playback_body = playback_guard.group("body")
        if "try {" not in playback_body or "} catch" not in playback_body:
            ok = fail("deferred timeline/tween play calls must be guarded by try/catch") and ok
        required_playback = ("timeline.play()", "particleTween.play()", "hero._driven = true")
        missing_playback = [
            contract for contract in required_playback if contract not in playback_body
        ]
        if missing_playback:
            ok = fail(
                f"deferred playback guard missing: {missing_playback}"
            ) and ok
        elif not (
            playback_body.index("timeline.play()")
            < playback_body.index("particleTween.play()")
            < playback_body.index("hero._driven = true")
        ):
            ok = fail(
                "hero._driven=true must follow successful timeline and particle play"
            ) and ok

    required_hero_css = (
        ".hero-canvas",
        "z-index: -1",
        "calc(100svh - 24px)",
        "min-height: 580px",
        "grid-template-rows:",
        ".hero-fallback",
        ".hero.particles-active .hero-fallback",
        ".hero-dot-grid",
        ".hero-visual",
        ".motion-ready .hero-title",
        "@media (max-height: 579px)",
    )
    for contract in required_hero_css:
        if contract not in css:
            ok = fail(f"styles.css missing hero contract: {contract}") and ok

    # Curtain owns the start gate. Motion must never race beneath the intro:
    # the curtain publishes an explicit exit-start event, while skipped
    # (mobile/reduced-motion) paths publish an explicit immediate-start event.
    required_curtain_gate = (
        '"agentdock:curtain-exit-start"',
        '"agentdock:curtain-skipped"',
        "dispatchEvent",
        "AgentDockCurtain",
    )
    for contract in required_curtain_gate:
        if contract not in js:
            ok = fail(f"main.js missing curtain/motion gate: {contract}") and ok

    # `height: calc(100svh - 24px)` is strict one-viewport behavior only when
    # the viewport can satisfy the 580px minimum. Below 580px the explicit
    # max-height rule fixes the hero at 580px, allowing normal page scrolling
    # instead of compressing/overlapping title, fallback product UI and CTA.
    if not re.search(
        r"@media\s*\(max-height:\s*579px\).*?\.hero\s*\{[^}]*height:\s*580px",
        css,
        re.DOTALL,
    ):
        ok = fail(
            "styles.css must make <580px heroes 580px tall and vertically scrollable"
        ) and ok

    # [skill: go-team-standards · Vokie 1:1] Task 4: chapter choreography & journey
    # 静态锁定关键机制契约（DOM 结构、CSS 形态、motion.js/ScrollTrigger 钩子、
    # 第二粒子场分级）。滚动/pin/横移/进度/懒加载/降级由浏览器行为测试验证。
    context_particles = SITE / "context-particles.js"
    if not context_particles.is_file():
        ok = fail("missing site/context-particles.js") and ok
    context_source = (
        context_particles.read_text(encoding="utf-8")
        if context_particles.is_file()
        else ""
    )

    # DOM structure counts (mechanism scaffolding must be real, not empty).
    capability_panels = len(re.findall(r'class="[^"]*\bcapability-panel\b', text))
    if capability_panels < 4:
        ok = fail(
            f"at least 4 .capability-panel elements required, found {capability_panels}"
        ) and ok
    journey_panels = len(re.findall(r'class="[^"]*\bjourney-panel\b', text))
    if journey_panels < 4:
        ok = fail(
            f"at least 4 .journey-panel elements required, found {journey_panels}"
        ) and ok
    lines_block = re.search(
        r'<div\s+class="context-lines"[^>]*>(?P<body>.*?)</div>',
        text,
        re.DOTALL,
    )
    if not lines_block:
        ok = fail("index.html must contain a .context-lines background block") and ok
    else:
        line_spans = len(re.findall(r"<span", lines_block.group("body")))
        if line_spans < 5:
            ok = fail(
                f"context-lines must contain at least 5 columns, found {line_spans}"
            ) and ok
    if not re.search(r'id="contextCanvas"', text):
        ok = fail("index.html must contain the #contextCanvas scene canvas") and ok
    # Bleed cards: privacy bleeds left, final CTA bleeds right (design §3.8/§3.9).
    if not re.search(r'<div class="bleed-card bleed-left\b', text):
        ok = fail("privacy must use a .bleed-card.bleed-left large card") and ok
    if not re.search(r'<div class="bleed-card bleed-right\b', text):
        ok = fail("final CTA must use a .bleed-card.bleed-right coral card") and ok

    # CSS mechanism contracts.
    required_chapter_css = (
        ".reveal-band",
        "border-radius: 30px 30px 0 0",
        ".reveal-band-inner",
        ".capability-panels",
        ".capability-panel",
        "flex: 0 1 25%",
        "flex-basis: 40%",
        "flex-basis: 20%",
        "@media (max-width: 767px)",
        "#context",
        "100dvh",
        ".context-canvas",
        ".context-scene",
        "mask-image: linear-gradient(",
        ".journey-viewport",
        ".journey-track",
        ".journey-panel",
        ".journey-progress",
        "flex-direction: column",
        ".journey.is-pinned .journey-track",
        "flex-direction: row",
        ".context-lines",
        ".context-lines span",
        ".bleed-card",
        "@media (min-width: 901px)",
    )
    for contract in required_chapter_css:
        if contract not in css:
            ok = fail(f"styles.css missing chapter contract: {contract}") and ok
    # Second particle scene is masked to the middle band with top/bottom vignette.
    if "80%" not in css or "20%" not in css:
        ok = fail("styles.css context mask must fade at 20% and 80% bands") and ok
    # Reduced motion must neutralize the reveal clip so content is never trapped.
    reduced_block = re.search(
        r"@media \(prefers-reduced-motion: reduce\) \{(?P<body>.*)\}",
        css,
        re.DOTALL,
    )
    if reduced_block and "clip-path: none" not in reduced_block.group("body"):
        ok = fail(
            "reduced-motion must reset reveal clip-path to none (no trapped content)"
        ) and ok

    # motion.js scroll orchestration hooks (behavior verified in the browser).
    required_chapter_motion = (
        "ScrollTrigger",
        "registerPlugin",
        "inset(0 100% 0 0)",
        '"top bottom"',
        '"top 42%"',
        "scrub: 1",
        "pin: true",
        "(min-width: 901px)",
        ">= 700",
        "is-pinned",
        'import("./context-particles.js")',
        "requestIdleCallback",
        "scaleY",
        "Math.max(",
    )
    for contract in required_chapter_motion:
        if contract not in motion_source:
            ok = fail(f"motion.js missing chapter contract: {contract}") and ok

    # Capability panel accordion lives in main.js as progressive enhancement.
    required_chapter_js = (
        "capability-panel",
        "is-active",
    )
    for contract in required_chapter_js:
        if contract not in js:
            ok = fail(f"main.js missing capability panel hook: {contract}") and ok

    # Second particle field: lazy, device-tiered, reduced-motion static, resilient.
    required_context_particles = (
        "./vendor/three.module.min.js",
        "contextCanvas",
        "saveData",
        "deviceMemory",
        "hardwareConcurrency",
        "pointer: coarse",
        "prefers-reduced-motion",
        "IntersectionObserver",
        "visibilitychange",
        '"webglcontextlost"',
        "preventDefault()",
        "AgentDockContext",
    )
    for contract in required_context_particles:
        if contract not in context_source:
            ok = fail(f"context-particles.js missing contract: {contract}") and ok

    if ok:
        print("PASS: site contract")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
