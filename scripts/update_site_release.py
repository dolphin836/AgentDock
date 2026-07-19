#!/usr/bin/env python3
# [skill: go-team-standards · 可复现发布替换] 显式更新指定首页的下载链接和版本标签
import argparse
from pathlib import Path
import re


VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
DOWNLOAD_PATTERN = re.compile(
    r"https://api\.agentdockstatus\.app/v1/download/"
    r"AgentDock-[0-9.]+\.(?:pkg|dmg)"
)
VERSION_LABEL_PATTERN = re.compile(r">v\d+\.\d+\.\d+<")


def update_html(path: Path, version: str, download_url: str) -> tuple[int, int]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid semantic version: {version!r}")

    text = path.read_text(encoding="utf-8")
    text, link_count = DOWNLOAD_PATTERN.subn(download_url, text)
    text, label_count = VERSION_LABEL_PATTERN.subn(f">v{version}<", text)
    if link_count == 0:
        raise ValueError(f"no AgentDock download links found in {path}")
    if label_count == 0:
        raise ValueError(f"no AgentDock version labels found in {path}")
    path.write_text(text, encoding="utf-8")
    return link_count, label_count


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
    links, labels = update_html(args.html, args.version, args.url)
    print(f"updated {links} download link(s) and {labels} version label(s) in {args.html}")


if __name__ == "__main__":
    main()
