# AgentDock website design QA

## Visual truth and implementation

- Source of visual truth: live `https://vokie.com/` captured in the in-app browser.
- Primary source evidence: `.design-evidence/vokie-desktop-top.png` and `.design-evidence/vokie-mobile-top.png`.
- Implementation evidence: `.design-evidence/agentdock-v2-desktop-top-final.png` and `.design-evidence/agentdock-v2-mobile-top-final.png`.
- Focused implementation evidence: `.design-evidence/agentdock-v2-desktop-section-01-ready.png`, `.design-evidence/agentdock-v2-desktop-tabs.png`, `.design-evidence/agentdock-v2-desktop-tabs-approval.png`, `.design-evidence/agentdock-v2-desktop-journey-start.png`, `.design-evidence/agentdock-v2-desktop-journey-end.png`, `.design-evidence/agentdock-v2-desktop-integrations.png`, `.design-evidence/agentdock-v2-desktop-privacy.png`, `.design-evidence/agentdock-v2-mobile-mosaic.png`, `.design-evidence/agentdock-v2-mobile-menu.png`, and `.design-evidence/agentdock-v2-mobile-journey.png`.
- Desktop viewport: 1440 × 1000 CSS pixels; both top screenshots are 1425 × 990 captured pixels after browser chrome/scrollbar exclusion.
- Mobile viewport: 390 × 844 CSS pixels; both top screenshots are 375 × 812 captured pixels after browser chrome/scrollbar exclusion.
- States compared: loaded hero in Chinese, desktop status/approval tab states, desktop pinned journey at start/end, mobile navigation open, mobile vertical journey, privacy, and integrations.

## Comparison history

1. Initial implementation versus source: hero structure matched, but AgentDock used pill CTAs while Vokie used a quiet underlined action. Mobile particles also obscured the title and the open menu inherited a light header tone.
2. Corrective pass: replaced the hero pills with the source-style underlined action, reduced particle contrast, resized/repositioned the mobile particle field, and forced the open menu header to the dark palette.
3. Final same-input comparison: source and implementation were opened together at identical desktop and mobile viewports. Header height, gutters, dark carbon background, warm-gray typography, hero framing, bottom rule/copy split, and overall information density align. Product-specific differences are intentional: the particle silhouette is the AgentDock notch and all copy/product imagery is AgentDock content.

## Detailed findings

- Typography: Geist/system fallback, 570-ish display weights, tight negative tracking, mono uppercase labels, and the 68 px desktop hero scale match the source character.
- Color: `#111111` carbon, `#dadada` warm paper, `#e7e7e7` light stage, Vokie-like blue and coral feature panels, and low-contrast hairlines are consistent across sections.
- Layout: fixed/condensing header, one-viewport hero, four large capability panels, convergence interlude, left-tab product stage, pinned horizontal desktop journey, light accordion, dark three-agent cards, usage panel, privacy field, split final CTA, and footer reproduce the source page rhythm.
- Motion: particle convergence, global reveal transitions, card lift, image transitions, header condensing/hide behavior, tab/accordion transitions, and scroll-driven horizontal journey work. Reduced-motion styles remove nonessential motion.
- Responsive: mobile uses the same 390 px breakpoint truth as the source, a 2 × 2 full-screen menu, single-column capability cards, horizontal feature tabs, vertical journey cards, and no horizontal overflow.
- Assets: four original AgentDock product images are stored locally under `website/public/product/`; no Vokie assets or hotlinks are used.

## Interaction and contract verification

- Desktop feature tabs switch copy and imagery with correct `tab`/`tabpanel` ARIA state.
- Outcome accordion moves the expanded state and associated imagery.
- Desktop journey translates from monitor through approval, usage, and return while the section is pinned; mobile resets to a vertical stack.
- Mobile navigation opens as a focus-contained full-screen menu with readable dark contrast and closes normally.
- English/Chinese switching updates the document language, hero, sections, navigation, and download copy.
- Header, footer, and final CTA all resolve to the authoritative `AgentDock-0.2.4.dmg` URL; the final CTA exposes the release `data-version` contract.
- In-app browser console: no errors or warnings on the final desktop/mobile pass.
- `npm run check`: passed.
- `npm run test:release`: passed, including sentinel build, language switch, download URL, version metadata, and console checks.
- `python3 scripts/check_site.py`: passed against the exported `site/` tree.
- `python3 scripts/test_update_site_release.py`: passed.
- `git diff --check`: passed.
- Static export refreshed from `website/out/` into `site/`.

final result: passed
