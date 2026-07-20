#!/usr/bin/env python3
# [skill: go-team-standards · 可复现发布替换] 显式更新指定首页的下载链接和版本标签
#
# COMPATIBILITY HELPER ONLY. The authoritative release path is an env-driven
# rebuild of the Next static export (website/src/lib/release.ts +
# scripts/package.sh); see design-qa.md. This script patches an
# already-exported index.html and MUST NOT be treated as the source of truth.
# It only handles `.dmg` artifacts, matching the shipping format.
import argparse
from pathlib import Path
import re
from urllib.parse import urlparse


VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
DOWNLOAD_PATTERN = re.compile(
    r"https://api\.agentdockstatus\.app/v1/download/"
    r"AgentDock-[0-9.]+\.dmg"
)
ARTIFACT_PATTERN = re.compile(r"AgentDock-[0-9.]+\.dmg")
VERSION_LABEL_PATTERN = re.compile(r"v(?:<!--\s*-->)?\d+\.\d+\.\d+")
VERSION_ATTRIBUTE_PATTERN = re.compile(
    r'(?P<prefix>data-version\s*=\s*["\'])\d+\.\d+\.\d+'
)


def update_html(path: Path, version: str, download_url: str) -> tuple[int, int, int, int]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid semantic version: {version!r}")
    download_name = Path(urlparse(download_url).path).name
    if not re.fullmatch(r"AgentDock-\d+\.\d+\.\d+\.dmg", download_name):
        raise ValueError(f"invalid AgentDock DMG download URL: {download_url!r}")

    text = path.read_text(encoding="utf-8")
    text, url_count = DOWNLOAD_PATTERN.subn(download_url, text)
    text, artifact_count = ARTIFACT_PATTERN.subn(download_name, text)
    text, label_count = VERSION_LABEL_PATTERN.subn(
        lambda match: (
            f"v<!-- -->{version}"
            if "<!--" in match.group(0)
            else f"v{version}"
        ),
        text,
    )
    text, attribute_count = VERSION_ATTRIBUTE_PATTERN.subn(
        rf"\g<prefix>{version}", text
    )
    if url_count == 0:
        raise ValueError(f"no AgentDock download links found in {path}")
    if label_count == 0:
        raise ValueError(f"no AgentDock version labels found in {path}")
    path.write_text(text, encoding="utf-8")
    return url_count, artifact_count, label_count, attribute_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update AgentDock download URLs and visible version labels.",
    )
    parser.add_argument("--html", required=True, type=Path, help="HTML file to update")
    parser.add_argument("--version", required=True, help="Release version, for example 0.2.4")
    parser.add_argument("--url", required=True, help="Release download URL")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    urls, artifacts, labels, attributes = update_html(
        args.html, args.version, args.url
    )
    print(
        f"updated {urls} download URL(s), {artifacts} artifact name(s), "
        f"{labels} version label(s), and {attributes} version attribute(s) in {args.html}"
    )


if __name__ == "__main__":
    main()
