<!-- [skill: go-team-standards · 部署发布 · QA 记录] AgentDock homepage verification evidence -->
# AgentDock Website Design QA

## Comparison target

The route under review is `site/index.html`. Task 6 compares AgentDock 1:1
against the live Vokie site (https://vokie.com/) on *mechanism and composition*,
not pixels: the same adaptive navigation, one-viewport particle hero, rounded
`clip-path` chapter reveal, expanding capability panels, masked second particle
field, pinned horizontal product journey, vertical-line background, and the
left/right out-bleed cards — rendered with AgentDock's own brand, copy, product
UI and particle shapes. No Vokie logo, image, copy, code, or particle shape is
reproduced.

## Evidence captured on 2026-07-19

All frames were captured with local Chrome over CDP (puppeteer-core, real
`Google Chrome`). Live Vokie reference frames and local AgentDock frames were
taken at matching viewports and scroll positions. These are local, uncommitted
evidence files under the git-ignored `.superpowers/sdd/nav-tests/` tree.

Live Vokie reference (read-only): `.superpowers/sdd/nav-tests/vokie/`
- `vokie-1440-hero.png`, `vokie-1440-nav-condensed.png`, `vokie-1440-s1..s6.png`,
  `vokie-1440-cta.png`, `vokie-1440-full.png`, `vokie-390-hero.png`,
  `vokie-390-full.png`.

Local AgentDock: `.superpowers/sdd/nav-tests/task6/`
- Desktop 1440×1000: `t6-1440-hero-settled-en.png`, `t6-1440-hero-zh.png`,
  `t6-1440-nav-condensed.png`, `t6-1440-value.png`, `t6-1440-capabilities.png`,
  `t6-1440-context-settled.png`, `t6-1440-journey-run.png`,
  `t6-1440-journey-mid.png`, `t6-1440-journey-end.png`,
  `t6-1440-integrations.png`, `t6-1440-privacy.png`, `t6-1440-cta.png`.
- Desktop 1280×800: `t6-1280-hero.png`, `t6-1280-journey-run.png`.
- Tablet 834×1194: `t6-834-hero.png`, `t6-834-capabilities.png`.
- Mobile 390×844: `t6-390-hero-en.png`, `t6-390-hero-zh.png`, `t6-390-full.png`,
  `t6-390-menu-open.png`.
- Mobile 360×800: `t6-360-hero.png`, `t6-360-full.png`.
- Degradation: `t6-1440-reduced.png`, `t6-1440-nojs.png`, `t6-390-nojs.png`,
  `t6-1440-nowebgl.png`.
- Critique-and-fix evidence: `t6-390-menu-open-scrolled-FIXED.png`.

## Mechanism comparison (live Vokie vs local, 1440 unless noted)

| Mechanism | Live Vokie | Local AgentDock | Result |
| --- | --- | --- | --- |
| Nav initial | Full-width thin bar: brand / center links / actions | Same three-region 80px bar (`所有…` links, EN·中文, 下载) | Match |
| Nav condensed | Floating dark capsule (~920, blur, border) after scroll | Capsule at `min(920px, …)` height 58, `blur(14px)`, top 11px | Match |
| Nav theme / hide | Foreground follows chapter; hides on scroll-down | `data-header` per section; direction hide past one viewport | Match |
| Hero | One viewport; particles converge into a blob behind title | One viewport; 2200/1200 particles converge (1.9s) into the AgentDock notch + two status bands; title, CTA, description | Match (original shape) |
| First light chapter | Rounded top slice revealing on scroll | `.reveal-band` rounded 30px top, `clip-path` reveal from right | Match |
| Feature panels | Horizontal expanding colored panels | Four dark capability panels, active grows to 40% w/ coral border | Match (brand palette) |
| Second particle field | Prominent dot field behind centered copy | Masked/vignetted stream field, deliberately calm per design §5.3 | Match (intentionally subtler) |
| Product journey | Desktop pinned horizontal track + progress line | `.journey.is-pinned` horizontal track, coral scaleX progress bar | Match |
| Vertical lines | Low-contrast vertical lines background | Five `.context-lines` columns grow on scroll | Match |
| Privacy card | Light card bleeding to a page edge | `.bleed-card.bleed-left` light card | Match |
| Final CTA | Accent card bleeding to opposite edge | `.bleed-card.bleed-right` coral card | Match (coral vs blue) |
| Mobile menu | Four-square button → full-screen clipped menu | Same four-square button, full-screen `clip-path` staggered links | Match |

## Browser matrix (evidence-backed)

| Surface | Result |
| --- | --- |
| Desktop 1440×1000 EN/ZH | Rendered; hero particles reach `uProgress=1` (2200 pts, 119 frames); zero document overflow. |
| Desktop 1280×800 | Journey pins horizontally (tall enough); zero overflow. |
| Tablet 834×1194 | Four capability panels legible; zero overflow. |
| Mobile 390×844 EN/ZH | Hero fits one viewport (1200 pts, converged); full-screen menu opens; zero overflow. |
| Mobile 360×800 | Full-page render; zero overflow. |
| Language | `setLanguage` round-trips: `zh-CN`/`en` on `<html lang>`, hero copy, and `#notchToggle`/`#menuButton`/`.mobile-nav` aria-labels. |
| Notch (WebGL fallback) | Hidden (`display:none`) while particles active; visible & interactive when WebGL fails; hover/click-pin open, pointer-away keeps pinned, Escape closes. |
| Approval demo | Allow/Review/Deny set `approved`/`review`/`denied` with matching `aria-pressed`. |
| Reduced motion | Curtain skipped, no `.reveal` hidden, hero `uProgress=1`, `motion-ready` absent. |
| JavaScript disabled | English content, notch product UI, nav anchors and downloads all visible/usable; zero overflow. |
| WebGL disabled | Hero and context fall back to CSS dot-grid / masked paper; content intact. Three.js logs its own context-creation error, then the guarded fallback engages. |
| saveData / low memory / low CPU | Hero drops to 1200 pts, context to 800 pts; content unaffected. |
| Resources / console | Three raster favicons load (natural width 64); one stylesheet; no console errors or failed requests on the happy path; all `.download` links resolve to `…/AgentDock-0.2.4.dmg`. |

## Critique and correction

First real critique-and-fix round found a material mobile interaction defect:
while the full-screen mobile menu is open, scrolling down triggered the header's
direction-hide logic and slid the header — including the four-square button that
is the only touch close control — off-screen (measured `btnTop=-72`, header
`translateY(-89.7px)`, not reachable) while the menu stayed open, stranding a
touch user.

Regression-first: four browser assertions were added to
`.superpowers/sdd/nav-tests/nav.test.mjs` (menu stays open, header not hidden,
close button on-screen and reachable while scrolling with the menu open). They
were RED against the prior code (3 failures). The minimal fix in `site/main.js`
makes `updateHeader()` keep the header shown whenever `#mobileMenu` has the
`is-open` class. `scripts/check_site.py` gained a matching static contract. The
tests then passed (nav 63/0); `t6-390-menu-open-scrolled-FIXED.png` shows the
header capsule and close control remaining on-screen (`btnTop=18`).

## Release substitution check

Using a temporary copy of `site/index.html`, the same two Python regex
substitutions in `scripts/package.sh` (version `9.9.9`) changed all five
versioned download URLs to the test DMG URL and updated the visible `<b>v…</b>`
label. A SHA-256 comparison confirmed the real `site/index.html` was unchanged.

## Command results

| Command | Result |
| --- | --- |
| `python3 scripts/check_site.py` | `PASS: site contract` |
| `node --check` (main/motion/hero-particles/context-particles) | All OK |
| `swift test` | 91 tests in 28 suites passed |
| `git diff --check` | Clean (exit 0) |
| Browser suites (nav/hero/journey/nojs/task5) | 63 / 86 / 92 / all / 81 passed, 0 failed |

## Concerns

- P3: The second (context) particle field is deliberately faint per design §5.3
  ("no full-page uniform noise"); it renders (webgl, 200+ frames) but reads much
  quieter than Vokie's prominent dot grid. This is an intentional divergence, not
  a defect.
- P3: When WebGL is unavailable, Three.js emits its own
  `THREE.WebGLRenderer: Error creating WebGL context` console error before the
  guarded fallback engages. It is third-party and harmless; the fallback UI is
  correct.
- Screenshot and reference frames are local, git-ignored evidence and are not
  committed.
