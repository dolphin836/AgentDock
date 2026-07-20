<!-- [skill: go-team-standards · 设计取证] Vokie 首页基础视觉与资源取证，供 AgentDock 品牌化重建 -->
# Vokie foundation evidence

> **Scope:** read-only evidence collected from the public `https://vokie.com/` on 2026-07-20. This document does not copy production code or download source assets. Values below are browser-computed values, rather than visual estimates.
>
> **Rebuild boundary:** reproduce layout, interaction patterns, and an independently authored design system for AgentDock. Do **not** reuse Vokie's name, copy, logo, app screenshots, QR code, favicon, product media, illustrations, SVG artwork, or brand colors without written permission.

## 1. Runtime and page foundation

| Evidence | Observed value |
| --- | --- |
| Canonical URL | `https://www.vokie.com/` |
| Document title | `Vokie - AI 语音输入、会议转写与语音上下文助手` |
| `<html>` classes | `js motion-ready` |
| Base scroll behavior | `scroll-behavior: smooth`; body `overflow-x: clip` |
| Header height | desktop `80px`; mobile (`390px`) `64px` |
| Content width token | `--content-width: 1440px` |
| Page gutter | desktop `40px`; tablet (`768px`) `24px`; mobile (`390px`) `18px` |
| Main surface palette | `--ink: #090909`; `--carbon: #111`; `--carbon-soft: #1b1b1b`; `--carbon-raised: #1b1b1b`; `--paper: #dadada`; `--paper-pure: #e7e7e7`; `--mist: #f5f5f5`; `--graphite: #535353` |
| Brand-only accents | `--vokie-blue: #2563eb`; `--vokie-blue-dark: #1d4ed8`; `--coral: #f97c28`; `--mint: #4cbd4f` |
| Structural easing | `--ease-structural: cubic-bezier(.62,.16,.13,1.01)`; `--ease-out: cubic-bezier(.22,1,.36,1)`; default duration `.15s`; default easing `cubic-bezier(.4,0,.2,1)` |
| Radius tokens | `.5rem`, `.75rem`, `1rem`, `1.5rem` |
| Spacing base | `--spacing: .25rem` (4px) |

### AgentDock reuse decision

- **Safe to recreate:** responsive gutters, wide 1440px composition, 4px spacing rhythm, dark/light surface contrast, accessible smooth-scroll preference handling, and independently written cubic-bezier motion.
- **Replace:** every Vokie-named color token. AgentDock should establish its own semantic tokens (`--surface`, `--ink`, `--accent`, etc.); the palette above is evidence, not a palette to import.

## 2. Typography

### Actual rendered stacks

| Role / live example | Computed family | Computed weight | Size / line-height |
| --- | --- | ---: | --- |
| General document | `MiSans, "PingFang SC", "Microsoft YaHei", sans-serif` | 400 | `16px / 24px` |
| Product/UI sans | `MiSans, Geist, Inter, "Noto Sans SC", "PingFang SC", "HarmonyOS Sans SC", "Microsoft YaHei", "OPPO Sans", sans-serif` | variable values `440–900` | varies |
| Eyebrow/number labels | `"Geist Mono", monospace` | 520 (also 400) | typically `12px / 15.6px` |
| Desktop hero headline | product/UI sans | 570 | `68px / 64.6px` |
| Desktop CTA headline | product/UI sans | 560 | `60px / 61.2px` |
| Section headline | product/UI sans | 560 | `60px / 64.8px`; compact sections `30px / 30px` |
| Card title | product/UI sans | 550–570 | `20px–30px / 21.6px–33px` |
| Body lead | product/UI sans | 400 | `19px / 32.3px` |
| Body copy | product/UI sans | 400 | `16px–18px / 19.2px–30.96px` |
| Nav | product/UI sans | 400 | `13px / 19.5px` |
| Mobile hero | product/UI sans | browser-computed | `39px / 39px` |

Observed variable numeric weights include `400, 440, 520, 540, 550, 560, 570, 600, 620, 640, 900`; therefore do not collapse the design into only 400/500/700 during implementation.

### Font resources and rights

| Resource | Evidence / URL | Reuse decision |
| --- | --- | --- |
| Geist Mono font file | `https://vokie.com/fonts/geist-mono-variable.woff2` (preloaded as `font/woff2`) | Do not hotlink or copy from Vokie. Geist is commonly OFL-licensed, but verify the upstream package/version and include its own license before independently installing it. |
| MiSans | Used in computed stack; no public font-file URL surfaced in the page resource list | Treat availability and license as unverified. Do not extract or bundle it from Vokie. Use an AgentDock-approved CJK font or a system fallback. |
| System fallbacks | PingFang SC, Microsoft YaHei, Inter, Noto Sans SC, HarmonyOS Sans SC, OPPO Sans | Browser/platform fonts are not Vokie assets; validate each intended distribution license before bundling. System fallback usage is safe. |

## 3. Responsive evidence

| Breakpoint / condition detected in served CSS | Effect or implementation implication |
| --- | --- |
| `min-width: 40rem` (640px) | Tailwind-style breakpoint |
| `min-width: 48rem` (768px) | Tailwind-style breakpoint |
| `min-width: 64rem` (1024px) | Tailwind-style breakpoint |
| `min-width: 80rem` (1280px) | Tailwind-style breakpoint |
| `min-width: 96rem` (1536px) | Tailwind-style breakpoint |
| `min-width: 901px`, `max-width: 900px` | Site-specific desktop/mobile behavior boundary |
| `max-width: 1180px`, `max-width: 767px`, `max-width: 680px` | Additional compact-layout rules |
| `min-width: 901px and min-height: 700px` | Desktop viewport-height treatment |
| `max-height: 699px` / `max-height: 640px` | Short-screen motion/layout treatment |
| `(hover: hover)`, `(hover: none), (pointer: coarse)` | Hover affordances are gated for input capability |
| `prefers-reduced-motion: reduce` | Motion-reduced alternative exists and must be retained in an AgentDock recreation |

At `390px`, the computed `--page-gutter` is `18px`; a hero title measures `354px` wide at `x=18px`. At `768px`, the gutter is `24px`. Desktop is `40px`. This is direct evidence for the `viewport - 2 × gutter` content model.

## 4. Color tokens and computed colors

### Semantic surfaces and text actually rendered

| Usage | Computed value |
| --- | --- |
| Ink text | `rgb(9, 9, 9)` / `#090909` |
| Carbon surface | `rgb(17, 17, 17)` / `#111111` |
| Paper | `rgb(218, 218, 218)` / `#dadada` |
| Pure paper | `rgb(231, 231, 231)` / `#e7e7e7` |
| Secondary text | `rgb(83, 83, 83)` / `#535353` |
| Bright text | `rgb(255, 255, 255)` |
| Muted light text | `rgba(246, 248, 248, 0.42–0.68)` |
| Blue download/link accent | `rgb(143, 176, 255)` in a rendered mobile-menu item; token blue is `#2563eb` |
| Dark header overlay | `rgba(11, 13, 16, 0.96)` |
| Light hairline | `rgba(255, 255, 255, 0.16)` |

Other framework-generated Tailwind OKLCH tokens are present (neutral, gray, slate, blue, cyan, purple, pink, orange, etc.). They are not proof of intentional Vokie semantic use. Do not copy the full generated palette; retain only AgentDock semantic tokens backed by its own visual direction.

### Background treatments

| Layer | Exact computed value | Recreate? |
| --- | --- | --- |
| Context vignette | `linear-gradient(rgb(218, 218, 218) 0%, rgba(218, 218, 218, 0) 50%, rgb(218, 218, 218) 100%)` | Mechanism is generic; recreate with AgentDock colors. |
| Voice-result dot field | `radial-gradient(circle, rgba(255,255,255,.12) 1px, transparent 1.2px), radial-gradient(circle at 50% 38%, rgba(255,255,255,.035), transparent 44%)` | Mechanism is generic; redraw/tune independently. |

## 5. Global animation, scroll, and rendering dependencies

### Keyframes served by the page

| Name | Exact behavior |
| --- | --- |
| `voice-wave` | `0%,100% { opacity:.5; transform:scaleY(.28) }`; `50% { opacity:1; transform:scaleY(1) }` |
| `voice-caret` | `0%,48% { opacity:1 }`; `49%,100% { opacity:0 }` |
| `button-sheen` | starts `opacity:0; transform:skew(-18deg) translate(0px)`; at `18%`, opacity `.9`; ends `opacity:0; transform:skew(-18deg) translate(620%)` |
| `command-cursor` | same blink timing as `voice-caret` |
| `pulse` | `50% { opacity:.5 }` |

### Runtime dependency evidence

| Dependency / mechanism | Public evidence | AgentDock decision |
| --- | --- | --- |
| GSAP | preload: `https://vokie.com/assets/gsap-a3sj5zmn.js` | Do not copy Vokie's bundle. Install GSAP independently only if AgentDock needs imperative timeline/ScrollTrigger behavior and its license is accepted. |
| Three.js | preload: `https://vokie.com/assets/three-BON0aOZo.js` | Do not copy bundle. Three.js may be independently installed under its upstream MIT license; use only for an AgentDock-authored canvas scene. |
| Page-specific context focus | module preload: `https://vokie.com/assets/context-focus-CEJSYbYa.js` | Proprietary implementation; identify desired behavior and implement anew. |
| Smooth scrolling | native `scroll-behavior: smooth` observed; no Lenis/Locomotive asset or DOM class observed | Use native smooth scrolling and a reduced-motion fallback; do not add a library without a product need. |
| Motion state | root class `motion-ready`; CSS has reduced-motion rules | Recreate the feature pattern, including `prefers-reduced-motion`, with AgentDock code. |

## 6. SEO, favicon, and metadata inventory

| Item | Public URL / value | Reuse decision |
| --- | --- | --- |
| Favicon | `https://vokie.com/favicon.png?v=2` | Vokie brand asset — do not download or reuse. Create AgentDock favicon. |
| Apple touch icon | `https://vokie.com/vokie-app-icon.png` | Vokie brand asset — do not reuse. |
| Canonical | `https://www.vokie.com/` | Do not retain; set AgentDock canonical URL. |
| Theme color | `#0b0d10` | Brand choice; replace with AgentDock theme color. |
| Description / Open Graph / Twitter metadata | all describe Vokie and use `https://www.vokie.com/vokie-app-icon.png` | Replace all titles, descriptions, image URLs, `og:site_name`, locale strategy, and social copy. |
| Security metadata | CSP restricts assets to `self` and Cloudflare Insights; referrer `strict-origin-when-cross-origin`; `nosniff`; geolocation/microphone/camera disabled | These are useful security patterns, not Vokie visual IP. Re-evaluate according to AgentDock deployment requirements. |

## 7. Complete visible asset and layering inventory

**License assessment for every Vokie-hosted item below:** no asset-level open-source license or grant was exposed by the homepage. Treat every URL as copyrighted/proprietary and **not downloadable/reusable** in AgentDock absent explicit written permission. URLs are retained only as provenance.

### Brand and global

| Layer / use | URL | Intrinsic size | Decision |
| --- | --- | ---: | --- |
| Header/footer/voice-dock symbol | `https://vokie.com/vokie-symbol.svg` | `24×24` | Vokie logo asset; replace with AgentDock mark. |
| Footer QR | `https://vokie.com/vokie-contact-qr.png` | `293×329` | Vokie contact asset; do not reuse. |
| Favicon | `https://vokie.com/favicon.png?v=2` | not measured | Do not reuse. |
| App/OG icon | `https://vokie.com/vokie-app-icon.png` | metadata declares `1024×1024` | Do not reuse. |

### Capability storytelling

| Layer / use | URL | Intrinsic size |
| --- | --- | ---: |
| Free-expression illustration | `https://vokie.com/assets/free-expression-vfjKdmVL.png` | `1174×758` |
| Faithful-editing illustration | `https://vokie.com/assets/faithful-editing-4EiXh_zv.png` | `1567×469` |
| Ready-now illustration | `https://vokie.com/assets/ready-now-nce9ls9K.png` | `1319×749` |
| Reusable-context illustration | `https://vokie.com/assets/reusable-context-ZvFiZSKE.png` | `1646×451` |

### Meeting/product media

The individual media nodes are absolutely positioned (`.product-media`), which means their parent media slots are composited scenes rather than a single flat asset. AgentDock may recreate this **layering mechanism** with its own UI screenshots/media.

| Layer / use | URL | Intrinsic size |
| --- | --- | ---: |
| Meeting shortcut | `https://vokie.com/product-media/meeting-shortcut.png` | `1320×1038` |
| Meeting sources | `https://vokie.com/assets/meeting-sources-DJYOe9qC.png` | `1320×1038` |
| Meeting recording | `https://vokie.com/assets/meeting-recording-BFODUSHf.png` | `1320×1038` |
| Meeting action items | `https://vokie.com/assets/meeting-action-items-B6otFqSo.png` | `1320×1038` |
| Transcript | `https://vokie.com/product-media/transcript.webp` | `1920×1322` |
| Summary | `https://vokie.com/product-media/summary.webp` | `1920×1322` |
| Actions | `https://vokie.com/product-media/actions.webp` | `1920×1322` |
| Memory chat | `https://vokie.com/product-media/memory-chat.webp` | `2144×1546` |

### Context and skill-card artwork

The hotword and skill images are absolutely positioned within `article.context-card`; preserve the card/image layering pattern only, with original AgentDock artwork and content.

| Layer / use | URL | Intrinsic size |
| --- | --- | ---: |
| Correct hotword card | `https://vokie.com/assets/hotword-correct-white-BzI4hyGe.png` | `1586×992` |
| Save hotword card | `https://vokie.com/assets/hotword-save-white-CepovRW5.png` | `1986×792` |
| Recall hotword card | `https://vokie.com/assets/hotword-remember-white-rjW7kSP2.png` | `1697×927` |
| Hotword summary card | `https://vokie.com/assets/hotword-summary-white-D48kFp2A.png` | `1928×816` |
| Meeting skill icon | `https://vokie.com/assets/skill-meeting-qwvE1G3p.png` | `1254×1254` |
| Search skill icon | `https://vokie.com/assets/skill-search-aPWyBk_4.png` | `1254×1254` |
| Continue skill icon | `https://vokie.com/assets/skill-continue-D6B55-EQ.png` | `1254×1254` |
| History skill icon | `https://vokie.com/assets/skill-history-D95fD-u6.png` | `1254×1254` |

### Closing/privacy artwork

| Layer / use | URL | Intrinsic size |
| --- | --- | ---: |
| Privacy boundary figure | `https://vokie.com/assets/privacy-boundary-BSi1w35N.png` | `1430×805` |
| Final voice-context figure | `https://vokie.com/assets/final-voice-context-4fXSA-Al.png` | `1383×721` |

### Inline SVG system

One inline `<svg class="voice-icon-sprite">` contains a symbol sprite (e.g., `voice-icon-filler`, `voice-icon-correction`, `voice-icon-paragraphs`, `voice-icon-lists`) consumed through `<use>`. These icon paths are Vokie artwork and are not reusable. AgentDock can safely use the architectural pattern—an internally owned SVG sprite or an appropriately licensed icon library—but must draw/select distinct icons.

### Media result

No `<video>` element or video source was present in the inspected DOM. The visible product demonstrations are raster/WebP assets and CSS/SVG composition, not video.

## 8. Implementation guidance for AgentDock

1. Use this document as a measurement reference only. Build a new `AgentDock` token layer and replace every product claim, visual, mark, app screen, and metadata field.
2. Preserve the practical mechanisms: constrained wide canvas, `40/24/18px` responsive gutters, mono eyebrow + UI-sans hierarchy, CSS micro-keyframes, image/media cards with independently created layered art, and reduced-motion behavior.
3. Use generated or first-party AgentDock product captures for all card media. Each replacement should have an asset manifest with source/creator/license.
4. If GSAP or Three.js is adopted, install from official registries, pin/record the independent license, and author all timelines/scenes in this codebase. Do not reference Vokie's hashed bundles.
