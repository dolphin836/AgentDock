<!-- [skill: go-team-standards · Code Review] Final homepage remediation record -->
# Final Fix Report — Vokie Homepage

## Scope

- Branch: `feat/vokie-1to1-homepage`
- Delivery: one local commit, not pushed and not amended.

## Resolved findings

- Mobile menu focus order now includes `#menuButton`: Shift+Tab from the first
  link reaches the visible close control, and Tab returns to the first link.
- Pinned desktop journey observes focus inside its panels, maps a noncurrent
  panel index to the ScrollTrigger range, and scrolls its focused content into
  view. Mobile, short viewports, and reduced motion retain the vertical flow.
- Curtain and menu use source-owned inert state, so one feature cannot remove
  another feature's inert lock. Curtain cleanup releases its owner on skipped,
  completed, and error paths.
- Capability `article` containers expose `role="button"` and
  `aria-expanded`; hover, focus, click, Enter, and Space synchronize the same
  active state without introducing nested interactive controls.
- `setLanguage()` now updates the symmetric English/Chinese page title and
  description as well as visible copy and ARIA labels.
- The site checker converts actual OKLCH values to sRGB and verifies every
  `--text-faint` surface is at least 4.5:1. Current values pass without a token
  adjustment.
- Three.js and GSAP provenance now cites official `registry.npmjs.org`
  tarballs. Their official SHA-512 integrity values and vendored bytes were
  rechecked; vendor JavaScript was unchanged.
- `LICENSES.txt` records the current AgentDock-only GSAP use and a future-use
  review reminder. It describes the No Charge assessment without claiming legal
  advice.

## TDD and verification

- RED: the expanded static checker reported missing metadata keys/updates,
  capability semantics and keyboard handling, inert ownership, journey focus
  handling, and official registry/license records. The expanded browser test
  also failed before the new focus-trap, curtain, capability, metadata, and
  journey behaviors existed.
- GREEN:
  - `python3 scripts/check_site.py`
  - `node scripts/check_site_browser.mjs` (Chrome CDP)
  - `python3 scripts/test_update_site_release.py`
  - `node --check` for authored site and browser-check JavaScript
  - `swift test --package-path /Users/eric/AgentDock-vokie-homepage` (91 tests)
  - `git diff --check`

## Residual concerns

- The contrast checker covers the declared opaque surfaces that use
  `--text-faint`; it intentionally does not model arbitrary transparency or
  rendered anti-aliasing.
- GSAP licensing remains usage-dependent. Re-review its upstream terms before
  offering the animation or site-building capability as a product feature.
