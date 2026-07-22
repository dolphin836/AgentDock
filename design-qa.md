# AgentDock one-screen website design QA

## Visual truth

- Content/layout reference: user-provided `codex-clipboard-8d801e59-c2bc-44dc-89d5-b500820f482e.png`.
- Dot-grid reference: user-provided `codex-clipboard-df42d6e8-bca1-41ba-aa9c-bad7f8fa47a8.png`.
- Final implementation evidence: `.design-evidence/agentdock-one-screen-dots-desktop.png`.
- Final local preview: `http://127.0.0.1:4173/?one-screen=1`.

## Comparison result

- The reference and final screenshot were opened together in one visual comparison pass.
- The original header, eyebrow, particle-notch visual, two-line statement, bottom rule, action, and description keep the same hierarchy and spacing rhythm.
- The final background remains carbon black and now carries a uniform low-contrast grid of tiny circular dots derived from the second reference.
- No capability panels, feature tabs, journey, integrations, privacy section, final CTA, product screenshots, or footer remain below the hero.
- At the in-app browser's 1280 × 720 viewport, document height and hero height are both exactly 720 px; the page has one section, zero footers, and no horizontal overflow.
- The flexible bottom grid was corrected during QA so the description stays inside the right viewport edge at 1280 px.

## Interaction and contract verification

- Particle animation remains visible above the dotted image texture.
- English/Chinese switching works and preserves the one-screen layout.
- Header download and mobile-menu download both retain the authoritative AgentDock 0.2.4 DMG URL.
- Existing navigation items resolve to anchors within the hero instead of removed sections.
- In-app browser console contained no errors or warnings from the application.
- `npm run check`: passed.
- `python3 scripts/check_site.py`: passed against the refreshed `site/` export.
- `python3 scripts/test_update_site_release.py`: passed.
- Browser regression scripts: syntax checked.
- `git diff --check`: passed.

final result: passed
