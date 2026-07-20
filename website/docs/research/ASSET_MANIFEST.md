<!-- [skill: go-team-standards · 设计取证] AgentDock 首页第一方品牌素材清单 -->
# AgentDock asset manifest

This manifest records first-party assets permitted for the AgentDock homepage. It intentionally excludes every Vokie asset referenced during visual research.

| Asset | Source | Website path | Intended use | License / ownership |
| --- | --- | --- | --- | --- |
| AgentDock application icon | Authored by the AgentDock project; source renderer: `/Users/eric/AgentDock/scripts/render-appicon.swift` | `public/app-icon.png` | Header brand mark, social preview, and application identity | First-party AgentDock artwork |

## Asset intake rules

- Add only original AgentDock artwork, product captures, or assets with an explicit compatible license.
- Record the original source, local public path, purpose, and ownership before a new asset is used in a section.
- Do not add Vokie logos, screenshots, illustrations, favicon files, QR codes, SVG paths, product media, or source URLs to `public/`.

## Current delivery note

`public/app-icon.png` is the agreed runtime path for the AgentDock mark. The source repository contains its first-party renderer, but the raster export has not yet been supplied to this website directory. Section implementation must not ship until that exported asset is present.
