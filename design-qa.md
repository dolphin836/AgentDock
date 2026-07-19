<!-- [skill: go-team-standards · 部署发布 · QA 记录] AgentDock 首页 Vokie 机制对照与发布验证 -->
# AgentDock Website Design QA

## Scope and evidence standard

The route under review is `site/index.html`. “1:1” means alignment of Vokie's
layout and interaction mechanisms while retaining AgentDock's original brand,
copy, product UI, palette and particle shapes. Verdicts below therefore use
**mechanism aligned**, not pixel-match claims.

All screenshots were captured on 2026-07-19 with local Google Chrome/CDP.
Evidence is local and git-ignored under `.superpowers/sdd/nav-tests/`.

## Viewport evidence

| Viewport/state | Live Vokie reference | Local AgentDock evidence | Observed difference |
| --- | --- | --- | --- |
| 1440×1000 hero | `vokie/vokie-1440-hero.png` | `task6/t6-1440-hero-settled-en.png` | Both are one viewport with centered particle structure; AgentDock uses a coral notch/status-band shape and editorial title placement. |
| 1440×1000 condensed nav | `vokie/vokie-1440-nav-condensed.png` | `task6/t6-1440-nav-condensed.png` | Both become a blurred floating capsule; AgentDock retains bilingual controls and coral action styling. |
| 1440×1000 context field | `vokie/vokie-1440-s1.png` | `task6/t6-1440-context-density-final.png` | Middle-field visual density is now comparable; Vokie uses a uniform grid, AgentDock uses three original converging streams. |
| 1280×800 hero | `vokie/vokie-1280-hero.png` | `task6/t6-1280-hero.png` | Mechanism aligned; typography, copy and particle geometry intentionally differ. |
| 834×1194 hero | `vokie/vokie-834-hero.png` | `task6/t6-834-hero.png` | Mechanism aligned; both preserve the one-screen composition and mobile header mode. |
| 390×844 hero | `vokie/vokie-390-hero.png` | `task6/t6-390-hero-en.png` | Mechanism aligned; AgentDock uses a full-width download action and notch silhouette. |
| 390×844 menu open | `vokie/vokie-390-menu-open.png` | `task6/t6-390-menu-open.png` | Both use a full-screen dark menu; Vokie is a 2×2 grid, AgentDock is an editorial vertical list with clipped reveal. |
| 360×800 hero | `vokie/vokie-360-hero.png` | `task6/t6-360-hero.png` | Mechanism aligned; no local horizontal overflow. |

Additional local chapter evidence:

- Reveal band: `task6/t6-1440-value.png`.
- Capability panels: `task6/t6-1440-capabilities.png`,
  `task6/t6-834-capabilities.png`.
- Pinned journey/progress: `task6/t6-1440-journey-run.png`,
  `task6/t6-1440-journey-mid.png`, `task6/t6-1440-journey-end.png`,
  `task6/t6-1280-journey-run.png`.
- Vertical lines, privacy left bleed, CTA right bleed:
  `task6/t6-1440-integrations.png`, `task6/t6-1440-privacy.png`,
  `task6/t6-1440-cta.png`.
- Fallbacks: `task6/t6-1440-reduced.png`,
  `task6/t6-1440-nojs.png`, `task6/t6-390-nojs.png`,
  `task6/t6-1440-nowebgl.png`.

## Mechanism verdicts

| Mechanism | Evidence-backed verdict |
| --- | --- |
| Initial / condensed navigation | Mechanism aligned: 80px full-width bar, then `min(920px, …)` × 58px capsule at 22vh; themed foreground and direction hide/show. |
| Hero | Mechanism aligned: one viewport, title and lower action row, 1.9s convergence; AgentDock's shape is original. |
| Reveal band | Mechanism aligned: rounded light slice with right-to-left `clip-path` reveal. |
| Capability panels | Mechanism aligned: horizontal expansion on desktop and vertical cards on mobile; styling/content differ. |
| Context particles | Mechanism aligned after review fix: broad masked middle field with reference-level density; geometry remains three AgentDock streams rather than Vokie's grid. |
| Journey | Mechanism aligned: desktop pin + horizontal translation + progress; vertical degradation below 901px, under 700px height, or reduced motion. |
| Integrations / cards | Mechanism aligned: five growing vertical lines, privacy left bleed, final CTA right bleed. |
| Mobile menu | Mechanism aligned at interaction level: four-square control, full-screen overlay, Escape/focus management. Composition intentionally differs from Vokie's 2×2 menu. |

## Review findings and RED → GREEN evidence

### Executable mobile-menu regression

The previous proof lived only in `.superpowers`. It is now committed as
`scripts/check_site_browser.mjs`, using only Node built-ins, global WebSocket,
and local Chrome CDP—no npm package.

The test runs 390×844 and 360×800, opens the menu, verifies first-link focus,
scrolls down, confirms the header and close control remain visible/reachable,
then sends Escape and verifies closed ARIA state plus restored toggle focus.

RED was reproduced against detached commit `ea3c2cb`:
`FAIL: header remains visible while mobile menu is open`.
GREEN on the current site: all 17 browser assertions pass. The source-string
assertion in `scripts/check_site.py` remains auxiliary only.

### Context particle density

First comparison:
`task6/t6-1440-context-settled.png` versus `vokie/vokie-1440-s1.png`
showed AgentDock's field was materially too sparse.

RED: the committed browser contract required a capable tier of at least 4000
points, point size ≥4.8, base alpha ≥0.28, peak alpha ≥0.9 and a 12%–88%
visible mask; the old 1600 / 3.0 / 0.12–0.62 implementation failed.

GREEN: capable desktops now use 4000 points, size 5.0 and alpha 0.30–0.95;
stream fan/control spread is wider, the vertical mask is 12%–88%, and the
vignette exposes more of the middle. Final screenshot:
`task6/t6-1440-context-density-final.png`. The original three-stream convergence
is preserved. `saveData`, ≤4GB memory, ≤4 CPU cores, or coarse pointer uses the
1600-point constrained tier; the committed CDP test verifies this downgrade.

## Release replacement

Release replacement is now reproducible without packaging:

- `scripts/update_site_release.py` accepts explicit `--html`, `--version` and
  `--url`.
- `scripts/package.sh` delegates only the HTML replacement to that helper.
- `scripts/test_update_site_release.py` copies the real index to a temporary
  path, covers existing DMG plus legacy PKG links and both visible label forms,
  then verifies the real `site/index.html` SHA-256 is unchanged.

RED: test failed because `update_site_release.py` did not exist. GREEN: one
test passes; 6 temporary links and 2 labels are replaced. No package was built
and the production version remains `0.2.4`.

## Accessibility, degradation and console evidence

- EN/ZH, mobile focus trap, Escape, ARIA state, reduced motion, JS disabled,
  WebGL failure, saveData/low-memory tiering, resources and happy-path console
  were exercised.
- **Accepted WebGL exception:** forcing WebGL creation failure produces
  Three.js's expected `THREE.WebGLRenderer: Error creating WebGL context`
  console error before AgentDock catches the constructor failure and exposes
  the CSS/product fallback. This path is not claimed console-clean.
- Happy-path page traversal has no console errors or failed local resources.

## Concerns

- Screenshots remain local, git-ignored evidence rather than repository assets.
- The WebGL-failure console entry is an explicitly accepted third-party
  exception; fallback content remains functional.
- Constrained devices intentionally render 1600 context particles rather than
  the 4000-point desktop field to protect battery and memory.
