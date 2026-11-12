#!/usr/bin/env python3
"""Validate docs link conventions for the two-alias (latest / development) site.

Policy:
- Intra-docs links: relative .md paths (enforced loosely; the strict docs export,
  ``bazelisk run //docs:manage-docs -- build --strict``, is primary). A relative .md
  link stays valid when the file on disk is its .mdx twin, because that is how
  docs-site/lib/href.ts resolves links at render time.
- Repo-root / non-docs files: GitHub URLs must use the trunk ref ``development`` as the
  canonical source form; the published alias stamps its own ref at build time
  (``docs-site/lib/remark-git-ref.ts``), and a link written on a tag keeps the tag.
- Do not hardcode a GitHub source link on a retired branch (``main`` / ``master``).
- Generated HTML must not use ``href="...*.md"`` or ``href="...*.mdx"`` (directory
  URLs on publish).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

# A page is markdown or MDX; the site renders both from the same content tree.
PAGE_SUFFIXES = {".md", ".mdx"}

# A GitHub source link pinned to a retired branch.  `development` is the trunk and the only
# long-lived ref, so that is what authors commit; the build stamps the alias's own ref.
_RETIRED_BRANCH_GH = re.compile(
    r"https://github\.com/toxicoder/inkorporated/(?:blob|tree)/(?:main|master)/"
)
# Absolute site URLs without a published version alias.
_SITE_NO_VERSION = re.compile(
    r"https://toxicoder\.github\.io/inkorporated/(?!latest/|development/)[a-zA-Z]"
)
# HTML hrefs to a page file (breaks use_directory_urls deploys).
_HTML_MD_HREF = re.compile(
    r"""href=["'][^"']+\.(?:md|mdx)(?:#[^"']*)?["']""", re.I
)

SKIP_NAME_PARTS = {
    "validate_docs_links.py",
    "CHANGELOG.md",  # not under docs usually
}


def iter_doc_files() -> list[Path]:
    files: list[Path] = []
    for p in DOCS.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix not in PAGE_SUFFIXES | {".html", ".py", ".js", ".css", ".yml", ".yaml"}:
            continue
        # Skip pure binary-ish
        if "node_modules" in p.parts or ".venv" in p.parts:
            continue
        files.append(p)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="exit 1 on failures")
    args = parser.parse_args()

    failures: list[str] = []
    warnings: list[str] = []

    for path in iter_doc_files():
        rel = path.relative_to(ROOT).as_posix()
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        # Skip the validator and other tooling docs that describe anti-patterns.
        if path.name in {
            "validate_docs_links.py",
            "prompt_quality_standard.md",
        }:
            continue

        for m in _RETIRED_BRANCH_GH.finditer(text):
            line = text[: m.start()].count("\n") + 1
            failures.append(
                f"{rel}:{line}: GitHub source link pinned to a retired branch; "
                "use the trunk ref development or a tag"
            )

        if path.suffix in PAGE_SUFFIXES:
            for m in _SITE_NO_VERSION.finditer(text):
                line = text[: m.start()].count("\n") + 1
                warnings.append(
                    f"{rel}:{line}: absolute site URL without /latest/ or /development/"
                )

        # Focus page-file hrefs in generated HTML on the roster content.
        if "cyborgs/generated" in rel.replace("\\", "/") or path.name.endswith(".html"):
            for m in _HTML_MD_HREF.finditer(text):
                line = text[: m.start()].count("\n") + 1
                failures.append(
                    f"{rel}:{line}: HTML href to a .md/.mdx page "
                    "(use directory URL trailing slash)"
                )

        # Also flag page-file hrefs in any file that contains cyborg-card HTML
        if "cyborg-card" in text or "data-cyborg-roster" in text:
            for m in _HTML_MD_HREF.finditer(text):
                line = text[: m.start()].count("\n") + 1
                msg = f"{rel}:{line}: roster HTML href to a .md/.mdx page"
                if msg not in failures:
                    failures.append(msg)

    print(f"failures={len(failures)} warnings={len(warnings)}")
    for line in failures[:40]:
        print("FAIL", line)
    if len(failures) > 40:
        print(f"... {len(failures) - 40} more")
    for line in warnings[:15]:
        print("WARN", line)

    if failures and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
