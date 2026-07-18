<!-- [skill: go-team-standards · 部署发布 · QA 记录] AgentDock homepage verification evidence -->
# AgentDock Website Design QA

## Comparison target

The target is Vokie-inspired editorial rhythm—dark ink field, warm copper
attention, oversized type, and a calm native-utility stage—not pixel copying.
The route under review is `site/index.html`.

## Evidence captured on 2026-07-19

- Desktop English: `/tmp/agentdock-task6-desktop-en.png` at 1440 × 1000.
- Desktop Simplified Chinese: `/tmp/agentdock-task6-desktop-zh.png` at
  1440 × 1000.
- Tablet English: `/tmp/agentdock-task6-tablet-en.png` at 834 × 1194.
- Mobile Simplified Chinese: `/tmp/agentdock-task6-mobile-zh.png` at
  390 × 844.

The captured desktop and mobile hero views retain the intended headline,
copper action, dark macOS stage, and notch hierarchy. The viewport checks
reported no document-level horizontal overflow for all four captures.

## Browser matrix

| Surface | Evidence-backed result |
| --- | --- |
| Desktop, 1440 × 1000 | English and Simplified Chinese rendered; no horizontal overflow. |
| Tablet, 834 × 1194 | English rendered; no horizontal overflow. |
| Mobile, 390 × 844 | Simplified Chinese rendered; no horizontal overflow. |
| Language control | Selecting 中文 set `document.documentElement.lang` to `zh-CN` and updated the hero copy. |
| Notch | Pointer hover opened it; click/focus set `aria-expanded="true"`; an actual pointer click followed by Escape left `aria-expanded="false"`. |
| Approval demo | Allow, Review, and Deny produced `approved`, `review`, and `denied` states respectively, with the selected button pressed. |
| Reduced motion | Emulated `prefers-reduced-motion: reduce` matched; reveal opacity was `1` and transition duration was `1e-05s`. |
| JavaScript disabled | `has-js` was absent; the English heading and approval text remained present and reveal content had opacity `1`. |
| Resources and console | Three raster images had non-zero natural widths; stylesheet and script loaded; no Runtime or Log error entries were captured. |
| Download links | The three `.download` links resolved to one URL: `https://api.agentdockstatus.app/v1/download/AgentDock-0.2.4.dmg`. |

## Release substitution check

Using a temporary copy of `site/index.html`, the same two Python regex
substitutions in `scripts/package.sh` changed all three versioned download URLs
to the test DMG URL and updated the visible `v9.9.9` label. A byte comparison
confirmed the real `site/index.html` was unchanged.

## Critique and correction

The first interaction pass found a material Escape defect: the handler closed
the notch and then refocused its trigger, whose `focusin` listener reopened the
panel. A regression contract was added to `scripts/check_site.py` first; it
failed against that behavior. Removing the unnecessary refocus is the minimal
fix. The contract then passed, and the actual-click/Escape retest reported a
collapsed notch (`aria-expanded="false"`).

## Remaining polish

- P3: add official third-party agent brand assets only if licensed source files
  are supplied.
- P3: add a notarization or signing trust badge only after release status is
  independently confirmed.
