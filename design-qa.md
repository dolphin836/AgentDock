<!-- [skill: go-team-standards · 部署发布] Next.js 静态导出验证记录 -->
# AgentDock website QA

## Current implementation

The published page is the static Next.js export in `site/`: `site/index.html`
loads local `site/_next` chunks and assets. It is not the retired hand-authored
single-file implementation, so this QA record does not make single-file,
vendor-hash, or legacy DOM-class claims.

`admin.html`, `version.json`, the release DMG when packaging creates it, and
`macos/` remain release assets outside the generated Next output.

## Reproducible validation

Run from the repository root:

```sh
python3 scripts/check_site.py
node scripts/check_site_browser.mjs
python3 scripts/test_update_site_release.py
swift test
(cd website && npm run check && npm run test:mobile && npm run test:release && npm run capture:local && npm run export:site)
git diff --check
```

The static contract requires local runtime scripts and stylesheets, while
canonical and metadata links may be external. It also verifies the document
language and metadata, skip link, unique critical section IDs, `data-header`
themes, mobile-menu ARIA contract, local first-party assets, and the real
`AgentDock-0.2.4.dmg` / `v0.2.4` release information.

The browser contract targets `http://127.0.0.1:4174/`; if no preview is already
running, it safely serves `site/` on that port. It checks 1440px and 390px
overflow, header scrolling, menu focus and Escape behavior, hero canvas, voice
tabs, journey desktop/mobile behavior, reduced motion, Chinese switching,
download links, and console errors.

## Release authority

The authoritative release path is a **rebuild of the Next static export**, not
an HTML patch. The shipping version and DMG URL live in one place —
`website/src/lib/release.ts` — which reads `NEXT_PUBLIC_AGENTDOCK_VERSION` and
`NEXT_PUBLIC_AGENTDOCK_DMG_URL` at build time (falling back to `0.2.4`).
`scripts/package.sh` sets those variables to the release values, runs
`npm run build` once, then `npm run copy:site` (copy only, no second env-less
build) to publish `out/` into `site/`, and finally writes `site/version.json`.

`npm run test:release` (`scripts/release-regression.mjs`) guards this contract:
it rebuilds `out/` with a `9.9.9` sentinel, asserts the exported HTML and every
hashed JS chunk contain `9.9.9`/its DMG URL and **no** stale `0.2.4`, then serves
the export and, via Puppeteer, confirms the download `href` and version stay
`9.9.9` after both automatic Chinese switching and a manual language toggle. It
restores the default build in a `finally` block.

`scripts/update_site_release.py` is retained only as a **compatibility helper**
for patching an already-exported `index.html` (URLs, artifact filenames including
`download=` values and serialized Next data, and both plain and
React-comment-split version labels). Because patching is not the source of truth,
it is not the authoritative publish path; `package.sh` no longer calls it. Its
temporary-copy regression test still protects the real exported HTML. The helper
and its checks only accept `.dmg` artifacts, matching the shipping format.
