#!/usr/bin/env python3
"""Internal link and asset check for the built Windmühle Tündern site.

`zola build` never verifies that a link or an image path resolves. A renamed
image directory or a hand-built URL keeps the build green and only breaks in
the browser. Both have happened: /imgs/pfingstmontag/ stayed hardcoded in
templates/gallery.html after the directory moved, and tag chips pointed at
/en/tags/<term>/, a tree Zola does not emit.

Walks public/ and resolves every local reference (href, src, meta content)
against the built output. Run it after `zola build`.

Exits non-zero on the first broken reference, so it can gate CI.
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
PUBLIC = ROOT / "public"
CONFIG = ROOT / "config.toml"

REF = re.compile(r'(?:href|src|content)="([^"]*)"', re.IGNORECASE)
BASE_URL = re.compile(r'^base_url\s*=\s*"([^"]+)"', re.MULTILINE)

# Reported per broken target, so one renamed directory does not print 200 lines.
MAX_SOURCES = 3


def site_base() -> str:
    m = BASE_URL.search(CONFIG.read_text(encoding="utf-8"))
    return m.group(1).rstrip("/") if m else ""


def local_path(raw: str, base: str) -> str | None:
    """Normalize one attribute value to a site-absolute path, or None to skip."""
    ref = html.unescape(raw).strip()
    if base and ref.startswith(base):
        ref = ref[len(base) :] or "/"
    # Anything still carrying a scheme, or a non-path value such as a meta
    # description or a viewport spec, is not ours to resolve.
    if not ref.startswith("/"):
        return None
    ref = urlsplit(ref).path
    if not ref:
        return None
    return unquote(ref)


def resolves(path: str) -> bool:
    target = PUBLIC / path.lstrip("/")
    if path.endswith("/"):
        return (target / "index.html").is_file()
    # Extensionless paths may be either a file or a directory with an index.
    return target.is_file() or (target / "index.html").is_file()


def main() -> int:
    if not PUBLIC.is_dir():
        print("check-links: public/ not found. Run `zola build` first.")
        return 1

    base = site_base()
    broken: dict[str, set[str]] = {}
    checked: set[str] = set()
    pages = 0

    for page in sorted(PUBLIC.rglob("*.html")):
        pages += 1
        source = str(page.relative_to(PUBLIC))
        for raw in REF.findall(page.read_text(encoding="utf-8", errors="ignore")):
            path = local_path(raw, base)
            if path is None:
                continue
            checked.add(path)
            if not resolves(path):
                broken.setdefault(path, set()).add(source)

    if broken:
        print("check-links FAILED: broken local references")
        for path in sorted(broken):
            sources = sorted(broken[path])
            shown = ", ".join(sources[:MAX_SOURCES])
            extra = f" (+{len(sources) - MAX_SOURCES} more)" if len(sources) > MAX_SOURCES else ""
            print(f"  - {path}")
            print(f"      referenced by: {shown}{extra}")
        return 1

    print(f"check-links OK: {len(checked)} distinct targets across {pages} pages resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
