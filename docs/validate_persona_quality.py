#!/usr/bin/env python3
"""Validate cyborg prompts and job role page depth against quality floors."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
CY = ROOT / "cyborgs"
ROLES = ROOT / "docs" / "job_roles"

PROMPT_FLOOR = 350
ROLE_FLOOR = 1000
PHRASE_FLOOR = 6
PERSONA_FLOOR = 4
GENERIC_INTRO = "Core content for this topic in the Inkorporated enterprise OS"


def words(text: str) -> int:
    return len((text or "").split())


def load_role_map() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for p in ROLES.rglob("*.md"):
        if p.name in ("index.md", "job_role_organization.md", "organization_chart.md"):
            continue
        m = re.search(
            r"\*\*Role Code:\*\*\s*`?([A-Z]+[0-9]+)`?",
            p.read_text(encoding="utf-8", errors="replace"),
        )
        if m:
            out[m.group(1)] = p
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="exit 1 on any failure")
    args = parser.parse_args()

    role_map = load_role_map()
    failures: list[str] = []
    warnings: list[str] = []

    cyborgs = []
    for p in sorted(CY.glob("*.yaml")):
        if p.name.startswith("_"):
            continue
        data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        jid = str(data.get("job_id") or p.stem)
        cyborgs.append((jid, p, data))

    for jid, p, data in cyborgs:
        sp = data.get("system_prompt") or ""
        w = words(sp)
        phrases = data.get("example_phrases") or []
        personalities = data.get("personalities") or []
        if w < PROMPT_FLOOR:
            failures.append(f"{jid}: system_prompt {w}w < {PROMPT_FLOOR}")
        if len(phrases) < PHRASE_FLOOR:
            failures.append(f"{jid}: example_phrases {len(phrases)} < {PHRASE_FLOOR}")
        if len(personalities) < PERSONA_FLOOR:
            failures.append(f"{jid}: personalities {len(personalities)} < {PERSONA_FLOOR}")
        if jid not in role_map:
            warnings.append(f"{jid}: no job role page")

    for jid, path in sorted(role_map.items()):
        text = path.read_text(encoding="utf-8", errors="replace")
        w = words(text)
        if w < ROLE_FLOOR:
            failures.append(f"{path.relative_to(ROOT)}: {w}w < {ROLE_FLOOR}")
        if GENERIC_INTRO in text:
            failures.append(f"{path.relative_to(ROOT)}: generic intro boilerplate")
        if jid not in {c[0] for c in cyborgs}:
            warnings.append(f"{jid}: no cyborg yaml")

    print(f"cyborgs={len(cyborgs)} role_pages={len(role_map)}")
    print(f"failures={len(failures)} warnings={len(warnings)}")
    for line in failures[:50]:
        print("FAIL", line)
    if len(failures) > 50:
        print(f"... {len(failures) - 50} more failures")
    for line in warnings[:20]:
        print("WARN", line)

    if failures and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
