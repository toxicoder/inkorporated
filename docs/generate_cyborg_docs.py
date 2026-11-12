#!/usr/bin/env python3
"""Generate human-facing cyborg roster docs from cyborgs/*.yaml.

Outputs under docs/cyborgs/generated/ (do not hand-edit). Pages are written as
``.mdx``: the roster is raw HTML and the Fumadocs compiler drops raw HTML blocks
when a page compiles as markdown (``format: md``), so the render is emitted in the
well-formed JSX form and keeps the extension that selects ``format: mdx``.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from collections import Counter, defaultdict
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    print("PyYAML required: pip install PyYAML", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parents[1]
CYBORGS_DIR = REPO_ROOT / "cyborgs"
OUT_DIR = REPO_ROOT / "docs" / "cyborgs" / "generated"
PERSONAS_DIR = OUT_DIR / "personas"
JOB_ROLES_DIR = REPO_ROOT / "docs" / "job_roles"

PREFIX_DOMAIN = {
    "BOARD": "Board & governance",
    "EXEC": "Executive",
    "SWEN": "Software engineering",
    "SREL": "Reliability & security eng",
    "DATA": "Data",
    "PROD": "Product",
    "DESN": "Design",
    "RSCH": "Research",
    "TPGM": "Program management",
    "SALE": "Sales",
    "MKTG": "Marketing",
    "COMM": "Communications",
    "CSM": "Customer success",
    "POLI": "Public policy",
    "FINC": "Finance",
    "PEOP": "People",
    "LEGL": "Legal",
    "OPS": "Operations",
    "REAL": "Workplace / real estate",
    "PERS": "Family office",
    "ITOP": "Corporate IT",
    "CUST": "Customer experience",
    "REGN": "Regional",
    "SQAD": "Squad lead",
}

PREFIX_ORDER = list(PREFIX_DOMAIN.keys())


def prefix_of(job_id: str) -> str:
    m = re.match(r"^([A-Z]+)", job_id or "")
    return m.group(1) if m else "OTHER"


# --- MDX output rules -------------------------------------------------------
#
# Fumadocs registers both extensions (docs-site/source.config.ts) and the compiler picks
# `format` from the file name: `.md` compiles as markdown, which silently drops the raw
# HTML blocks the roster grid is made of; `.mdx` compiles as MDX, which parses those tags
# as JSX. So the render is `.mdx` and every tag it emits has to satisfy the JSX parser:
# balanced, void elements self-closed, attribute values double-quoted, and no literal `{`
# or `}` outside code, because those open a JavaScript expression.


MDX_EXT = ".mdx"

# Page names the generator owns directly under docs/cyborgs/generated/; personas/ holds
# one more file per job id. Only the extension is a render decision.
_TOP_LEVEL_PAGES = ("index", "by_namespace", "by_security", "org_graph")

VOID_ELEMENTS = frozenset(
    {
        "area",
        "base",
        "br",
        "col",
        "embed",
        "hr",
        "img",
        "input",
        "link",
        "meta",
        "param",
        "source",
        "track",
        "wbr",
    }
)

_CODE_FENCE_RE = re.compile(r"^[ \t]*(?P<fence>`{3,}|~{3,})")
_INLINE_CODE_RE = re.compile(r"(?P<tick>`+)(?P<code>.+?)(?P=tick)")
_BARE_BRACE_RE = re.compile(r"(?<!\\)[{}]")


def esc(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def mdx_text(value: Any) -> str:
    """Escape a value for an HTML/JSX text position and shield literal braces."""
    return esc(value).replace("{", r"\{").replace("}", r"\}")


def mdx_attr(value: Any) -> str:
    """Escape a double-quoted attribute value.

    Attributes carry job ids, prefixes, namespaces and security levels. A brace cannot be
    backslash-escaped inside an attribute, so one that turns up in such a token is dropped
    and reported rather than rendered as JSX syntax noise.
    """
    out = esc(value)
    if "{" in out or "}" in out:
        print(f"warning: brace dropped from attribute value {out!r}", file=sys.stderr)
        out = out.replace("{", "").replace("}", "")
    return out


def mdx_front(value: Any) -> str:
    """Render a frontmatter scalar as a double-quoted YAML string.

    JSON string syntax is a valid YAML flow scalar, so a display name holding a colon, a
    quote or a hash still parses, and the value never needs hand-maintained quoting.
    """
    return json.dumps("" if value is None else str(value), ensure_ascii=False)


class _TagBalance(HTMLParser):
    """Collect the tags of one HTML region so the render can be checked before it lands."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[tuple[str, int]] = []
        self.errors: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        line = self.getpos()[0]
        if tag in VOID_ELEMENTS:
            self.errors.append(f"line {line}: <{tag}> must be self-closed as <{tag} />")
            return
        self.stack.append((tag, line))

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        pass

    def handle_endtag(self, tag: str) -> None:
        line = self.getpos()[0]
        if tag in VOID_ELEMENTS:
            self.errors.append(f"line {line}: </{tag}> is invalid, <{tag} /> is void")
            return
        if not self.stack:
            self.errors.append(f"line {line}: </{tag}> has no opening <{tag}>")
            return
        opened, opened_at = self.stack.pop()
        if opened != tag:
            self.errors.append(
                f"line {line}: </{tag}> closes <{opened}> opened at line {opened_at}"
            )


def _blank_inline_code(text: str) -> str:
    """Blank inline code spans, keeping byte offsets and line numbers intact.

    Backticked text is literal to the MDX compiler, so ```cyborgs/<JOB_ID>.yaml`` is prose,
    not a tag.
    """
    return _INLINE_CODE_RE.sub(lambda m: " " * len(m.group()), text)


def _html_depth(lines: list[str]) -> int:
    """Net count of elements still open after ``lines``.

    Only used to decide whether a plain-text line lazily continues an open element (as MDX
    parses it) or starts markdown that ends the HTML region. The authoritative balance check
    is :class:`_TagBalance`.
    """
    depth = 0
    for closing, tag, attrs in re.findall(
        r"<(/?)([A-Za-z][A-Za-z0-9._-]*)((?:\"[^\"]*\"|'[^']*'|[^>\"'])*)>",
        _blank_inline_code("\n".join(lines)),
    ):
        if closing:
            depth -= 1
        elif attrs.rstrip().endswith("/") or tag in VOID_ELEMENTS:
            continue
        else:
            depth += 1
    return depth


def check_mdx_safety(name: str, text: str) -> None:
    """Fail the render when a page would not compile under MDX ``format: mdx``.

    Fenced blocks and inline code are exempt, matching what the compiler exempts. HTML is
    checked per region: a region is a run of tag lines that blank lines and fenced blocks
    may sit inside, which is how MDX groups JSX children.
    """
    lines = text.split("\n")

    fenced: list[tuple[int, int]] = []
    open_at: int | None = None
    marker = ""
    for index, line in enumerate(lines):
        match = _CODE_FENCE_RE.match(line)
        if match is None:
            continue
        fence = match.group("fence")
        if open_at is None:
            open_at, marker = index, fence
        elif fence[0] == marker[0] and len(fence) >= len(marker):
            fenced.append((open_at, index + 1))
            open_at = None
    if open_at is not None:
        fenced.append((open_at, len(lines)))

    def in_fence(index: int) -> bool:
        return any(start <= index < end for start, end in fenced)

    front_end = 0
    if lines and lines[0].strip() == "---":
        front_end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), 0)

    problems: list[str] = []
    regions: list[tuple[int, list[str]]] = []
    current: list[str] = []
    start = 0
    depth = 0
    for index, line in enumerate(lines):
        if index <= front_end or in_fence(index):
            continue
        if line.lstrip().startswith("<") or (current and depth > 0):
            # A text line lazily continues an element MDX still has open, so it belongs to
            # the same JSX block and must be checked with it.
            if not current:
                start = index
            current.append(line)
            depth += _html_depth([line])
        elif line.strip():
            if current:
                regions.append((start, current))
                current = []
                depth = 0

    if current:
        regions.append((start, current))

    for region_start, chunk in regions:
        parser = _TagBalance()
        # Newline padding keeps getpos() on the page's own line numbers.
        parser.feed("\n" * region_start + _blank_inline_code("\n".join(chunk)))
        parser.close()
        for tag, line in parser.stack:
            problems.append(f"line {line}: <{tag}> is never closed")
        problems.extend(parser.errors)

    for index, line in enumerate(lines):
        if index <= front_end or in_fence(index):
            continue
        if _BARE_BRACE_RE.search(_blank_inline_code(line)):
            problems.append(f"line {index + 1}: unescaped brace: {line.strip()[:72]}")

    if problems:
        raise SystemExit(
            f"{name} is not MDX-safe:\n  "
            + "\n  ".join(sorted(set(problems)))
            + "\nFix docs/generate_cyborg_docs.py; docs/cyborgs/generated/ is a render."
        )


def write_page(path: Path, text: str) -> None:
    """Write one generated page once it is known to compile as MDX."""
    check_mdx_safety(path.relative_to(OUT_DIR.parent).as_posix(), text)
    path.write_text(text, encoding="utf-8")


def as_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            if item is None or item == "":
                continue
            out.append(str(item))
        return out
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def truncate(text: str, limit: int = 220) -> str:
    text = re.sub(r"\s+", " ", (text or "").strip())
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def security_class(level: str) -> str:
    level = (level or "UNSPECIFIED").upper()
    mapping = {
        "CRITICAL": "chip-security-critical",
        "HIGH": "chip-security-high",
        "MEDIUM": "chip-security-medium",
        "LOW": "chip-security-low",
        "NONE": "chip-security-none",
    }
    return mapping.get(level, "chip-security-unspecified")


def ns_class(namespace: str) -> str:
    ns = (namespace or "").lower()
    if "executive" in ns:
        return "chip-ns-executive"
    if "development" in ns or "product" in ns:
        return "chip-ns-development"
    if "security" in ns:
        return "chip-ns-security"
    if "sre" in ns:
        return "chip-ns-sre"
    if "gtm" in ns:
        return "chip-ns-gtm"
    if "family" in ns or "personal" in ns:
        return "chip-ns-family-office"
    if "customer" in ns:
        return "chip-ns-customer"
    if "squad" in ns:
        return "chip-ns-squad"
    if "hr" in ns:
        return "chip-ns-hr"
    if "ga" in ns or "finance" in ns:
        return "chip-ns-ga"
    return "chip-ns-default"


def chip(label: str, css: str) -> str:
    return f'<span class="chip {css}">{mdx_text(label)}</span>'


def load_cyborgs() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in sorted(CYBORGS_DIR.glob("*.yaml")):
        if path.name.startswith("_"):
            continue
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if not isinstance(data, dict):
            continue
        job_id = str(data.get("job_id") or path.stem)
        deployment = data.get("deployment") or {}
        if not isinstance(deployment, dict):
            deployment = {}
        security = data.get("security") or {}
        if not isinstance(security, dict):
            security = {}
        resources = data.get("resources") or {}
        if not isinstance(resources, dict):
            resources = {}
        retry = data.get("retry") or data.get("retry_config") or {}
        if not isinstance(retry, dict):
            retry = {}

        prefix = prefix_of(job_id)
        ns = str(deployment.get("namespace") or "unspecified")
        level = str(security.get("level") or "UNSPECIFIED").upper()
        display = str(data.get("display_name") or job_id)
        human = str(data.get("human_title") or display)
        short = str(data.get("short_description") or "")
        item = {
            "job_id": job_id,
            "path": path.name,
            "display_name": display,
            "human_title": human,
            "prefix": prefix,
            "domain": PREFIX_DOMAIN.get(prefix, prefix.title()),
            "category": str(data.get("category") or ""),
            "sub_category": str(data.get("sub_category") or ""),
            "level_band": str(data.get("level_band") or ""),
            "reports_to": str(data.get("reports_to") or ""),
            "direct_reports": as_list(data.get("direct_reports")),
            "short_description": short,
            "system_prompt": str(data.get("system_prompt") or short),
            "personalities": as_list(data.get("personalities")),
            "example_phrases": as_list(data.get("example_phrases")),
            "primary_functionality": as_list(data.get("primary_functionality")),
            "deterministic_capabilities": as_list(
                data.get("deterministic_capabilities")
            ),
            "llm_capabilities": as_list(data.get("llm_capabilities")),
            "tags": as_list(data.get("tags")),
            "tools_mcp": as_list(data.get("tools_mcp")),
            "knowledge_docs": as_list(data.get("knowledge_docs")),
            "dependencies": as_list(data.get("dependencies")),
            "job_type": str(data.get("job_type") or "LLM"),
            "namespace": ns,
            "sla": str(deployment.get("sla_latency_budget") or ""),
            "reliability": str(deployment.get("reliability_tier") or ""),
            "max_streams": deployment.get("max_concurrent_streams", ""),
            "security_level": level,
            "encryption_required": bool(security.get("encryption_required")),
            "authentication_required": bool(security.get("authentication_required")),
            "authorization_required": bool(security.get("authorization_required")),
            "human_approval_required": bool(security.get("human_approval_required")),
            "allowed_invokers": as_list(security.get("allowed_invokers")),
            "resources": resources,
            "retry": retry,
            "priority": data.get("priority", ""),
            "timeout_ms": data.get("timeout_ms", ""),
            "kpi_owned": as_list(data.get("kpi_owned")),
            "escalation_path": as_list(data.get("escalation_path")),
        }
        items.append(item)

    def sort_key(c: dict[str, Any]) -> tuple[int, str]:
        pref = c["prefix"]
        try:
            idx = PREFIX_ORDER.index(pref)
        except ValueError:
            idx = 999
        return (idx, c["job_id"])

    items.sort(key=sort_key)
    return items


def find_role_pages() -> dict[str, str]:
    """Map role code -> relative docs path from docs/."""
    mapping: dict[str, str] = {}
    if not JOB_ROLES_DIR.exists():
        return mapping
    for path in JOB_ROLES_DIR.rglob("*.md"):
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
            r"\*\*Role Code:\*\*\s*`?([A-Z]+[0-9]+)`?", text
        ):
            code = m.group(1)
            rel = path.relative_to(REPO_ROOT / "docs").as_posix()
            mapping.setdefault(code, rel)
    return mapping


def render_card(c: dict[str, Any]) -> str:
    initials = (c["prefix"][:2] if c["prefix"] else "CY").upper()
    tags = c["tags"][:6]
    caps = (c["primary_functionality"] or c["deterministic_capabilities"])[:4]
    tools = (c["tools_mcp"] or c["dependencies"])[:4]
    chip_bits = [
        chip(c["security_level"], security_class(c["security_level"])),
        chip(c["namespace"], ns_class(c["namespace"])),
        chip(c["job_type"], "chip-type"),
    ]
    for t in tags:
        chip_bits.append(chip(t, "chip-tag"))
    cap_bits = [chip(x, "chip-cap") for x in caps]
    tool_bits = [chip(x, "chip-tool") for x in tools]
    blurb = mdx_text(truncate(c["short_description"]))
    return f"""
<article class="cyborg-card" data-security="{mdx_attr(c['security_level'])}" data-ns="{mdx_attr(c['namespace'])}" data-prefix="{mdx_attr(c['prefix'])}">
  <header class="cyborg-card__header">
    <span class="cyborg-avatar" data-prefix="{mdx_attr(c['prefix'])}" aria-hidden="true">{mdx_text(initials)}</span>
    <div class="cyborg-card__header-text">
      <h3 class="cyborg-card__title">{mdx_text(c['display_name'])}</h3>
      <p class="cyborg-card__subtitle">{mdx_text(c['human_title'])} · {mdx_text(c['domain'])}</p>
    </div>
    {chip(c['job_id'], 'chip-jobid')}
  </header>
  <div class="cyborg-card__chips">{''.join(chip_bits)}</div>
  <p class="cyborg-card__blurb">{blurb}</p>
  <div class="cyborg-chip-row">{''.join(cap_bits) if cap_bits else '<span class="cyborg-empty">No capabilities listed</span>'}</div>
  <div class="cyborg-chip-row">{''.join(tool_bits)}</div>
  <footer class="cyborg-card__footer">
    <a href="personas/{mdx_attr(c['job_id'])}/">Full profile →</a>
    <span class="chip chip-tag">{mdx_text(c['prefix'])}</span>
  </footer>
</article>
""".strip()


def render_filter_bar(cyborgs: list[dict[str, Any]]) -> str:
    prefixes = []
    for p in PREFIX_ORDER:
        if any(c["prefix"] == p for c in cyborgs):
            prefixes.append(p)
    for p in sorted({c["prefix"] for c in cyborgs}):
        if p not in prefixes:
            prefixes.append(p)
    secs = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
    buttons = ['<button type="button" data-filter="all:" class="is-active">All</button>']
    for p in prefixes:
        buttons.append(
            f'<button type="button" data-filter="prefix:{mdx_attr(p)}">{mdx_text(p)}</button>'
        )
    for s in secs:
        if any(c["security_level"] == s for c in cyborgs):
            buttons.append(
                f'<button type="button" data-filter="security:{mdx_attr(s)}">{mdx_text(s)}</button>'
            )
    return f'<div class="cyborg-filters" role="toolbar" aria-label="Filter cyborgs">{"".join(buttons)}</div>'


def render_stats(cyborgs: list[dict[str, Any]]) -> str:
    by_sec = Counter(c["security_level"] for c in cyborgs)
    namespaces = len({c["namespace"] for c in cyborgs})
    chips = [
        chip(f"{len(cyborgs)} personas", "chip-jobid"),
        chip(f"{namespaces} namespaces", "chip-tag"),
        chip(f"{by_sec.get('CRITICAL', 0)} CRITICAL", "chip-security-critical"),
        chip(f"{by_sec.get('HIGH', 0)} HIGH", "chip-security-high"),
    ]
    return f'<div class="cyborg-stats">{"".join(chips)}</div>'


def write_roster(cyborgs: list[dict[str, Any]]) -> None:
    cards = "\n".join(render_card(c) for c in cyborgs)
    body = f"""---
title: Cyborg roster
description: Auto-generated visual catalog of Inkorporated AI cyborg personas.
tags: [cyborgs, generated]
---

# Cyborg roster

**What's on this page**

- Auto-generated cards for every persona in `cyborgs/*.yaml`
- Color-coded security and namespace chips for fast scanning
- Client-side filters by prefix and security level

**What this enables**

- Developers understand agent risk, tools, and domain at a glance
- Single pipeline from YAML source of truth to human docs

<Callout type="info" title="Source of truth">

Edit `cyborgs/<JOB_ID>.yaml`, then run `bazelisk test //docs:build` (the generator runs automatically). Do **not** hand-edit files under `docs/cyborgs/generated/`.

</Callout>

{render_stats(cyborgs)}

<div data-cyborg-roster>
{render_filter_bar(cyborgs)}
<div class="cyborg-grid">
{cards}
</div>
</div>

## Related

- [By namespace](by_namespace{MDX_EXT})
- [By security](by_security{MDX_EXT})
- [Org graph](org_graph{MDX_EXT})
- [Schema](../schema.md)
"""
    write_page(OUT_DIR / f"index{MDX_EXT}", body)


def write_grouped(
    cyborgs: list[dict[str, Any]],
    key: str,
    title: str,
    filename: str,
    order: list[str] | None = None,
) -> None:
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for c in cyborgs:
        groups[str(c.get(key) or "unspecified")].append(c)
    keys = order or sorted(groups.keys())
    for k in list(groups.keys()):
        if k not in keys:
            keys.append(k)
    sections: list[str] = []
    for k in keys:
        if k not in groups:
            continue
        cards = "\n".join(render_card(c) for c in groups[k])
        sections.append(
            f'## {mdx_text(k)}\n\n<div class="cyborg-grid">\n{cards}\n</div>\n'
        )
    body = f"""---
title: {title}
description: Cyborg personas grouped by {key}.
tags: [cyborgs, generated]
---

# {title}

**What's on this page**

- Same card UI as the roster, grouped by **{key}**

**What this enables**

- Ops and security reviews by deployment or risk tier

[← Back to roster](index{MDX_EXT})

{chr(10).join(sections)}
"""
    write_page(OUT_DIR / filename, body)


def write_persona(c: dict[str, Any], role_pages: dict[str, str]) -> None:
    initials = (c["prefix"][:2] if c["prefix"] else "CY").upper()
    chips = "".join(
        [
            chip(c["job_id"], "chip-jobid"),
            chip(c["security_level"], security_class(c["security_level"])),
            chip(c["namespace"], ns_class(c["namespace"])),
            chip(c["job_type"], "chip-type"),
            chip(c["domain"], "chip-tag"),
        ]
    )
    if c["human_approval_required"]:
        chips += chip("HITL required", "chip-security-critical")

    caps = "".join(
        chip(x, "chip-cap")
        for x in (c["primary_functionality"] + c["deterministic_capabilities"])[:12]
    )
    tools = "".join(
        chip(x, "chip-tool") for x in (c["tools_mcp"] or c["dependencies"])[:20]
    )
    tags = "".join(chip(x, "chip-tag") for x in c["tags"][:16])
    personalities = "".join(chip(x, "chip-tag") for x in c["personalities"][:12])

    role_link = ""
    if c["job_id"] in role_pages:
        # from generated/personas/ -> docs/
        rel = Path("../../..") / role_pages[c["job_id"]]
        role_link = f"- Job role doc: [{mdx_text(c['job_id'])}]({rel.as_posix()})\n"

    phrases = ""
    if c["example_phrases"]:
        phrases = "\n".join(f"- {mdx_text(p)}" for p in c["example_phrases"][:8])
    else:
        phrases = '<p class="cyborg-empty">None listed</p>'

    invokers = (
        "".join(chip(x, "chip-jobid") for x in c["allowed_invokers"])
        if c["allowed_invokers"]
        else '<span class="cyborg-empty">Org default policy</span>'
    )

    res = c["resources"]
    retry = c["retry"]
    # The prompt goes into a fenced block verbatim; only a nested fence has to be neutered.
    prompt_fence = c["system_prompt"].replace("```", "'''")

    mermaid = ""
    if c["reports_to"] or c["direct_reports"]:
        lines = ["flowchart LR"]
        me = re.sub(r"[^A-Za-z0-9_]", "_", c["job_id"])
        lines.append(f'  {me}["{c["job_id"]}"]')
        if c["reports_to"]:
            mgr = re.sub(r"[^A-Za-z0-9_]", "_", c["reports_to"])
            lines.append(f'  {mgr}["{c["reports_to"]}"] --> {me}')
        for dr in c["direct_reports"][:12]:
            d = re.sub(r"[^A-Za-z0-9_]", "_", dr)
            lines.append(f'  {me} --> {d}["{dr}"]')
        mermaid = "```mermaid\n" + "\n".join(lines) + "\n```\n"

    critical_panel = ""
    if c["security_level"] == "CRITICAL" or c["prefix"] == "PERS":
        critical_panel = f"""
<div class="cyborg-panel cyborg-panel--critical">
  <h3>Elevated risk persona</h3>
  <p>Security level <strong>{mdx_text(c['security_level'])}</strong>.
  Human approval required: <strong>{'yes' if c['human_approval_required'] else 'no'}</strong>.</p>
  <div class="cyborg-chip-row">Allowed invokers: {invokers}</div>
</div>
"""

    body = f"""---
title: {mdx_front(f"{c['display_name']} ({c['job_id']})")}
description: {mdx_front(f"Cyborg persona {c['job_id']} — {c['human_title']}")}
tags: [cyborgs, generated, persona]
---

# {mdx_text(c['display_name'])}

<div class="cyborg-detail-hero">
  <span class="cyborg-avatar" data-prefix="{mdx_attr(c['prefix'])}" aria-hidden="true">{mdx_text(initials)}</span>
  <div>
    <p class="cyborg-card__subtitle">{mdx_text(c['human_title'])}</p>
    <div class="cyborg-card__chips">{chips}</div>
  </div>
</div>

**What's on this page**

- Full machine metadata for `{esc(c['job_id'])}`
- Capabilities, tools, security gates, and system prompt

**What this enables**

- Safe operator review before enabling an agent
- Traceability back to YAML source `cyborgs/{esc(c['path'])}`

[← Roster](../index{MDX_EXT})

{critical_panel}

## At a glance

| Field | Value |
| --- | --- |
| Job ID | `{esc(c['job_id'])}` |
| Domain | {mdx_text(c['domain'])} |
| Namespace | `{esc(c['namespace'])}` |
| Job type | {mdx_text(c['job_type'])} |
| Reliability | {mdx_text(c['reliability'])} |
| SLA latency | {mdx_text(c['sla'])} |
| Priority | {mdx_text(c['priority'])} |
| Timeout | {mdx_text(c['timeout_ms'])} ms |
| Reports to | {mdx_text(c['reports_to'] or '—')} |

## Description

{mdx_text(c['short_description'])}

## Capabilities

<div class="cyborg-chip-row">{caps or '<span class="cyborg-empty">None</span>'}</div>

### LLM

<div class="cyborg-chip-row">{''.join(chip(x, 'chip-cap') for x in c['llm_capabilities']) or '<span class="cyborg-empty">None</span>'}</div>

## Tools and dependencies

<div class="cyborg-chip-row">{tools or '<span class="cyborg-empty">None</span>'}</div>

## Tags and personalities

<div class="cyborg-chip-row">{tags}</div>
<div class="cyborg-chip-row">{personalities}</div>

## Example phrases

{phrases}

## System prompt

<details>
<summary>Show system prompt</summary>

```text
{prompt_fence}
```

</details>

## Security

| Control | Value |
| --- | --- |
| Level | {mdx_text(c['security_level'])} |
| Encryption | {mdx_text(c['encryption_required'])} |
| Authentication | {mdx_text(c['authentication_required'])} |
| Authorization | {mdx_text(c['authorization_required'])} |
| Human approval | {mdx_text(c['human_approval_required'])} |

<div class="cyborg-chip-row">Invokers: {invokers}</div>

## Resources

| Resource | Value |
| --- | --- |
| CPU cores | {mdx_text(res.get('cpu_cores', ''))} |
| Memory GB | {mdx_text(res.get('memory_gb', ''))} |
| Storage GB | {mdx_text(res.get('storage_gb', ''))} |
| Network Mbps | {mdx_text(res.get('network_mbps', ''))} |

## Retry

| Field | Value |
| --- | --- |
| Max retries | {mdx_text(retry.get('max_retries', ''))} |
| Initial backoff ms | {mdx_text(retry.get('initial_backoff_ms', ''))} |
| Max backoff ms | {mdx_text(retry.get('max_backoff_ms', ''))} |
| Multiplier | {mdx_text(retry.get('backoff_multiplier', retry.get('multiplier', '')))} |

## Knowledge docs

{chr(10).join(f'- `{esc(k)}`' for k in c['knowledge_docs']) or '_None listed_'}

## Reporting

{mermaid or '_No reports_to / direct_reports edges in YAML._'}

## Links

- Machine source: [`cyborgs/{esc(c['path'])}`](https://github.com/toxicoder/inkorporated/blob/development/cyborgs/{esc(c['path'])})
{role_link}
"""
    write_page(PERSONAS_DIR / f"{c['job_id']}{MDX_EXT}", body)


def _mermaid_id(job_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", job_id)


def _heading_anchor(title: str) -> str:
    """Stable anchor for a slice heading.

    Emitted as ``### Title [#anchor]`` rather than the MkDocs ``{#anchor}``: MDX reads the
    braces as the start of a JavaScript expression, while fumadocs' remarkHeading plugin
    honours the bracket form as an explicit id (``customId``), so the in-page TOC keeps
    landing on the same addresses.
    """
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def _node_label(job_id: str, labels: dict[str, str], max_len: int = 28) -> str:
    """Short readable label: display name + job id."""
    name = (labels.get(job_id) or job_id).strip()
    if name == job_id:
        text = job_id
    else:
        # Keep labels compact for mermaid readability
        short = name if len(name) <= 18 else name[:16].rstrip() + "…"
        text = f"{short}\\n{job_id}"
    text = text.replace('"', "'")
    if len(text) > max_len + 12:
        text = text[: max_len + 9] + "…"
    return text


def _flowchart(edges: list[tuple[str, str]], labels: dict[str, str], direction: str = "TB") -> str:
    # Drop self-loops and duplicates; keep stable order for readable diffs.
    clean: list[tuple[str, str]] = []
    seen_e: set[tuple[str, str]] = set()
    for a, b in edges:
        if not a or not b or a == b:
            continue
        if (a, b) in seen_e:
            continue
        seen_e.add((a, b))
        clean.append((a, b))
    if not clean:
        return "_No reporting edges in this slice._"
    lines = [f"flowchart {direction}"]
    seen_nodes: set[str] = set()
    for a, b in clean:
        for node in (a, b):
            if node not in seen_nodes:
                nid = _mermaid_id(node)
                lines.append(f'  {nid}["{_node_label(node, labels)}"]')
                seen_nodes.add(node)
        lines.append(f"  {_mermaid_id(a)} --> {_mermaid_id(b)}")
    return "```mermaid\n" + "\n".join(lines) + "\n```"


# High-level org buckets for split hierarchy diagrams (readable size).
ORG_SLICES: list[tuple[str, str, set[str]]] = [
    ("Board & executive", "Top of house: board, C-suite, and corporate chief of staff.", {"BOARD", "EXEC"}),
    ("Engineering & reliability", "Software, platform, SRE, and security-engineering personas.", {"SWEN", "SREL"}),
    ("Product, design & data", "Product, design, research, program, and data personas.", {"PROD", "DESN", "RSCH", "TPGM", "DATA"}),
    ("Go-to-market & regions", "Sales, marketing, CS, comms, policy, and regional leads.", {"SALE", "MKTG", "COMM", "CSM", "POLI", "REGN"}),
    ("G&A, legal, people & IT", "Finance, people, legal, ops, workplace, and corporate IT.", {"FINC", "PEOP", "LEGL", "OPS", "REAL", "ITOP"}),
    ("Customer experience", "Support, TAM, implementation, and related CX personas.", {"CUST"}),
    ("Family office", "PERS* agents under FO director / CEO boundary.", {"PERS"}),
    ("Squad leads", "Cross-functional SQAD orchestrator personas.", {"SQAD"}),
]


def write_org_graph(cyborgs: list[dict[str, Any]]) -> None:
    labels: dict[str, str] = {}
    reports_to: dict[str, str] = {}
    children: dict[str, list[str]] = defaultdict(list)
    nodes: set[str] = set()

    for c in cyborgs:
        jid = c["job_id"]
        labels[jid] = str(c.get("display_name") or jid)
        nodes.add(jid)
        mgr = (c.get("reports_to") or "").strip()
        if mgr:
            reports_to[jid] = mgr
            children[mgr].append(jid)
            nodes.add(mgr)
            labels.setdefault(mgr, mgr)
        for dr in c.get("direct_reports") or []:
            dr = str(dr).strip()
            if not dr:
                continue
            children[jid].append(dr)
            reports_to.setdefault(dr, jid)
            nodes.add(dr)
            labels.setdefault(dr, dr)

    # Dedupe children lists
    for k, vals in list(children.items()):
        children[k] = sorted(set(vals))

    all_edges = sorted({(mgr, child) for child, mgr in reports_to.items() if mgr})
    # Also include explicit direct_reports edges
    for mgr, kids in children.items():
        for kid in kids:
            all_edges.append((mgr, kid))
    all_edges = sorted(set(all_edges))

    # --- Overview: only top-level anchors (board, exec, domain roots) ---
    overview_keep = {
        n
        for n in nodes
        if prefix_of(n) in {"BOARD", "EXEC"}
        or n
        in {
            "PERS0001",
            "SWEN0001",
            "PROD0001",
            "SALE0001",
            "MKTG0001",
            "FINC0001",
            "PEOP0001",
            "LEGL7001",
            "SREL0003",
            "DATA4001",
        }
    }
    # Always include CEO and any board node
    for n in list(nodes):
        if n.startswith("BOARD") or n in {"EXEC0001", "PERS0001"}:
            overview_keep.add(n)

    overview_edges = [
        (a, b)
        for a, b in all_edges
        if a in overview_keep and b in overview_keep
    ]
    # If sparse, add edges from CEO/board to vertical heads even when not both EXEC
    for child, mgr in reports_to.items():
        if mgr in {"EXEC0001", "BOARD0001"} and prefix_of(child) in {
            "EXEC",
            "PERS",
            "SWEN",
            "PROD",
            "SALE",
            "FINC",
            "PEOP",
        }:
            overview_edges.append((mgr, child))
    overview_edges = sorted(set(overview_edges))

    overview_block = _flowchart(overview_edges, labels, "TB")
    if overview_block.startswith("_No"):
        # Fallback synthetic overview of prefixes under CEO
        synth = ["flowchart TB", '  CEO["CEO\\nEXEC0001"]']
        for pref, title in [
            ("SWEN", "Engineering"),
            ("SREL", "Reliability/Sec"),
            ("PROD", "Product"),
            ("SALE", "Sales"),
            ("MKTG", "Marketing"),
            ("FINC", "Finance"),
            ("PEOP", "People"),
            ("PERS", "Family Office"),
            ("SQAD", "Squads"),
        ]:
            count = sum(1 for c in cyborgs if c["prefix"] == pref)
            if count:
                synth.append(f'  {pref}["{title}\\n{count} personas"]')
                synth.append(f"  CEO --> {pref}")
        overview_block = "```mermaid\n" + "\n".join(synth) + "\n```"

    # --- Per-slice detailed graphs ---
    slice_sections: list[str] = []
    for title, blurb, prefixes in ORG_SLICES:
        member_ids = {n for n in nodes if prefix_of(n) in prefixes}
        # Include managers of those members so hierarchy roots are visible
        roots_extra: set[str] = set()
        for n in list(member_ids):
            mgr = reports_to.get(n)
            if mgr:
                roots_extra.add(mgr)
        visible = member_ids | roots_extra
        slice_edges = [(a, b) for a, b in all_edges if a in visible and b in member_ids]
        # Cap very large slices: prefer edges where child is in slice
        if len(slice_edges) > 45:
            # Keep edges to managers within prefix first, then truncate alphabetically
            internal = [(a, b) for a, b in slice_edges if prefix_of(b) in prefixes]
            slice_edges = sorted(internal)[:45]
        if not member_ids:
            continue
        count = sum(1 for c in cyborgs if c["prefix"] in prefixes)
        anchor = _heading_anchor(title)
        diagram = _flowchart(slice_edges, labels, "TB")
        if diagram.startswith("_No") and member_ids:
            # Flat fan-out under domain label when reports_to sparse
            lines = ["flowchart TB", f'  ROOT["{title}"]']
            for n in sorted(member_ids)[:30]:
                lines.append(f'  {_mermaid_id(n)}["{_node_label(n, labels)}"]')
                lines.append(f"  ROOT --> {_mermaid_id(n)}")
            if len(member_ids) > 30:
                lines.append(f'  MORE["+{len(member_ids) - 30} more personas"]')
                lines.append("  ROOT --> MORE")
            diagram = "```mermaid\n" + "\n".join(lines) + "\n```"
        capped = len(slice_edges) >= 45
        slice_sections.append(
            f'### {title} [#{anchor}]\n\n'
            f"{blurb} **{count}** personas in this slice"
            f"{' (diagram capped for readability)' if capped else ''}.\n\n"
            f"{diagram}\n"
        )

    by_prefix = Counter(c["prefix"] for c in cyborgs)
    stats_lines = ["pie showData", "  title Cyborgs by prefix"]
    for pref, count in by_prefix.most_common(16):
        stats_lines.append(f'  "{pref}" : {count}')

    sec = Counter(c["security_level"] for c in cyborgs)
    sec_lines = ["pie showData", "  title Security levels"]
    for level, count in sec.most_common():
        sec_lines.append(f'  "{level}" : {count}')

    toc = "\n".join(
        f"- [{title}](#{_heading_anchor(title)})"
        for title, _, prefixes in ORG_SLICES
        if any(c["prefix"] in prefixes for c in cyborgs)
    )

    body = f"""---
title: Cyborg org and stats graphs
description: Auto-generated mermaid hierarchy views over cyborg YAML metadata.
tags: [cyborgs, generated, mermaid]
---

# Cyborg org and stats graphs

**What's on this page**

- A **compact executive overview** of the agent hierarchy
- **Domain slices** of the reporting tree (readable size)
- Population charts by prefix and security level

**What this enables**

- Structural review of the agent fleet without a single unreadable mega-graph

[← Roster](index{MDX_EXT})

## How to read these diagrams

- Node labels show **display name** (when known) and **job id**.
- Edges come from `reports_to` / `direct_reports` in `cyborgs/*.yaml`.
- Large domains are **split** so each diagram stays scannable.
- If a slice has sparse reporting edges, it falls back to a domain fan-out list.

## Executive overview

Top-of-house hierarchy only (board, CEO/C-suite anchors, and key vertical heads).

{overview_block}

## Reporting hierarchy by domain

{toc}

{chr(10).join(slice_sections)}

## Population by prefix

```mermaid
{chr(10).join(stats_lines)}
```

## Population by security level

```mermaid
{chr(10).join(sec_lines)}
```
"""
    write_page(OUT_DIR / f"org_graph{MDX_EXT}", body)


def write_stats_json(cyborgs: list[dict[str, Any]]) -> None:
    payload = {
        "count": len(cyborgs),
        "by_prefix": dict(Counter(c["prefix"] for c in cyborgs)),
        "by_security": dict(Counter(c["security_level"] for c in cyborgs)),
        "by_namespace": dict(Counter(c["namespace"] for c in cyborgs)),
        "job_ids": [c["job_id"] for c in cyborgs],
    }
    (OUT_DIR / "_stats.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def generate() -> int:
    if not CYBORGS_DIR.is_dir():
        print(f"missing {CYBORGS_DIR}", file=sys.stderr)
        return 1
    cyborgs = load_cyborgs()
    if not cyborgs:
        print("no cyborgs found", file=sys.stderr)
        return 1

    if OUT_DIR.exists():
        # clean personas to avoid stale IDs, and drop any page still wearing the
        # pre-MDX extension so one page never exists in two renders at once
        if PERSONAS_DIR.exists():
            for suffix in (".md", MDX_EXT):
                for old in PERSONAS_DIR.glob(f"*{suffix}"):
                    old.unlink()
        for page in _TOP_LEVEL_PAGES:
            (OUT_DIR / f"{page}.md").unlink(missing_ok=True)
    PERSONAS_DIR.mkdir(parents=True, exist_ok=True)

    role_pages = find_role_pages()
    write_roster(cyborgs)
    write_grouped(
        cyborgs,
        "namespace",
        "Cyborgs by namespace",
        f"by_namespace{MDX_EXT}",
    )
    write_grouped(
        cyborgs,
        "security_level",
        "Cyborgs by security level",
        f"by_security{MDX_EXT}",
        order=["CRITICAL", "HIGH", "MEDIUM", "LOW", "NONE", "UNSPECIFIED"],
    )
    write_org_graph(cyborgs)
    write_stats_json(cyborgs)
    for c in cyborgs:
        write_persona(c, role_pages)

    print(f"generated {len(cyborgs)} cyborg docs → {OUT_DIR.relative_to(REPO_ROOT)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Reserved for CI stale checks (currently always regenerates)",
    )
    parser.parse_args()
    return generate()


if __name__ == "__main__":
    raise SystemExit(main())
