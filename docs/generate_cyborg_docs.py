#!/usr/bin/env python3
"""Generate human-facing cyborg roster docs from cyborgs/*.yaml.

Outputs under docs/cyborgs/generated/ (do not hand-edit).
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from collections import Counter, defaultdict
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


def esc(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


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
    return f'<span class="chip {css}">{esc(label)}</span>'


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
    blurb = esc(truncate(c["short_description"]))
    return f"""
<article class="cyborg-card" data-security="{esc(c['security_level'])}" data-ns="{esc(c['namespace'])}" data-prefix="{esc(c['prefix'])}">
  <header class="cyborg-card__header">
    <span class="cyborg-avatar" data-prefix="{esc(c['prefix'])}" aria-hidden="true">{esc(initials)}</span>
    <div class="cyborg-card__header-text">
      <h3 class="cyborg-card__title">{esc(c['display_name'])}</h3>
      <p class="cyborg-card__subtitle">{esc(c['human_title'])} · {esc(c['domain'])}</p>
    </div>
    {chip(c['job_id'], 'chip-jobid')}
  </header>
  <div class="cyborg-card__chips">{''.join(chip_bits)}</div>
  <p class="cyborg-card__blurb">{blurb}</p>
  <div class="cyborg-chip-row">{''.join(cap_bits) if cap_bits else '<span class="cyborg-empty">No capabilities listed</span>'}</div>
  <div class="cyborg-chip-row">{''.join(tool_bits)}</div>
  <footer class="cyborg-card__footer">
    <a href="personas/{esc(c['job_id'])}/">Full profile →</a>
    <span class="chip chip-tag">{esc(c['prefix'])}</span>
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
            f'<button type="button" data-filter="prefix:{esc(p)}">{esc(p)}</button>'
        )
    for s in secs:
        if any(c["security_level"] == s for c in cyborgs):
            buttons.append(
                f'<button type="button" data-filter="security:{esc(s)}">{esc(s)}</button>'
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

!!! tip "Source of truth"
    Edit `cyborgs/<JOB_ID>.yaml`, then run `./docs/manage-docs.sh build` (generator runs automatically). Do **not** hand-edit files under `docs/cyborgs/generated/`.

{render_stats(cyborgs)}

<div data-cyborg-roster markdown="0">
{render_filter_bar(cyborgs)}
<div class="cyborg-grid">
{cards}
</div>
</div>

## Related

- [By namespace](by_namespace.md)
- [By security](by_security.md)
- [Org graph](org_graph.md)
- [Schema](../schema.md)
"""
    (OUT_DIR / "index.md").write_text(body, encoding="utf-8")


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
            f'## {esc(k)}\n\n<div class="cyborg-grid" markdown="0">\n{cards}\n</div>\n'
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

[← Back to roster](index.md)

{chr(10).join(sections)}
"""
    (OUT_DIR / filename).write_text(body, encoding="utf-8")


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
        role_link = f"- Job role doc: [{esc(c['job_id'])}]({rel.as_posix()})\n"

    phrases = ""
    if c["example_phrases"]:
        phrases = "\n".join(f"- {esc(p)}" for p in c["example_phrases"][:8])
    else:
        phrases = '<p class="cyborg-empty">None listed</p>'

    invokers = (
        "".join(chip(x, "chip-jobid") for x in c["allowed_invokers"])
        if c["allowed_invokers"]
        else '<span class="cyborg-empty">Org default policy</span>'
    )

    res = c["resources"]
    retry = c["retry"]
    prompt = esc(c["system_prompt"])

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
<div class="cyborg-panel cyborg-panel--critical" markdown="0">
  <h3>Elevated risk persona</h3>
  <p>Security level <strong>{esc(c['security_level'])}</strong>.
  Human approval required: <strong>{'yes' if c['human_approval_required'] else 'no'}</strong>.</p>
  <div class="cyborg-chip-row">Allowed invokers: {invokers}</div>
</div>
"""

    body = f"""---
title: "{c['display_name']} ({c['job_id']})"
description: "Cyborg persona {c['job_id']} — {c['human_title']}"
tags: [cyborgs, generated, persona]
---

# {esc(c['display_name'])}

<div class="cyborg-detail-hero" markdown="0">
  <span class="cyborg-avatar" data-prefix="{esc(c['prefix'])}" aria-hidden="true">{esc(initials)}</span>
  <div>
    <p class="cyborg-card__subtitle">{esc(c['human_title'])}</p>
    <div class="cyborg-card__chips" style="margin-top:0.5rem">{chips}</div>
  </div>
</div>

**What's on this page**

- Full machine metadata for `{esc(c['job_id'])}`
- Capabilities, tools, security gates, and system prompt

**What this enables**

- Safe operator review before enabling an agent
- Traceability back to YAML source `cyborgs/{esc(c['path'])}`

[← Roster](../index.md)

{critical_panel}

## At a glance

| Field | Value |
| --- | --- |
| Job ID | `{esc(c['job_id'])}` |
| Domain | {esc(c['domain'])} |
| Namespace | `{esc(c['namespace'])}` |
| Job type | {esc(c['job_type'])} |
| Reliability | {esc(c['reliability'])} |
| SLA latency | {esc(c['sla'])} |
| Priority | {esc(c['priority'])} |
| Timeout | {esc(c['timeout_ms'])} ms |
| Reports to | {esc(c['reports_to'] or '—')} |

## Description

{esc(c['short_description'])}

## Capabilities

<div class="cyborg-chip-row" markdown="0">{caps or '<span class="cyborg-empty">None</span>'}</div>

### LLM

<div class="cyborg-chip-row" markdown="0">{''.join(chip(x, 'chip-cap') for x in c['llm_capabilities']) or '<span class="cyborg-empty">None</span>'}</div>

## Tools and dependencies

<div class="cyborg-chip-row" markdown="0">{tools or '<span class="cyborg-empty">None</span>'}</div>

## Tags and personalities

<div class="cyborg-chip-row" markdown="0">{tags}</div>
<div class="cyborg-chip-row" markdown="0">{personalities}</div>

## Example phrases

{phrases}

## System prompt

<details>
<summary>Show system prompt</summary>

```text
{c['system_prompt']}
```

</details>

## Security

| Control | Value |
| --- | --- |
| Level | {esc(c['security_level'])} |
| Encryption | {esc(c['encryption_required'])} |
| Authentication | {esc(c['authentication_required'])} |
| Authorization | {esc(c['authorization_required'])} |
| Human approval | {esc(c['human_approval_required'])} |

<div class="cyborg-chip-row" markdown="0">Invokers: {invokers}</div>

## Resources

| Resource | Value |
| --- | --- |
| CPU cores | {esc(res.get('cpu_cores', ''))} |
| Memory GB | {esc(res.get('memory_gb', ''))} |
| Storage GB | {esc(res.get('storage_gb', ''))} |
| Network Mbps | {esc(res.get('network_mbps', ''))} |

## Retry

| Field | Value |
| --- | --- |
| Max retries | {esc(retry.get('max_retries', ''))} |
| Initial backoff ms | {esc(retry.get('initial_backoff_ms', ''))} |
| Max backoff ms | {esc(retry.get('max_backoff_ms', ''))} |
| Multiplier | {esc(retry.get('backoff_multiplier', retry.get('multiplier', '')))} |

## Knowledge docs

{chr(10).join(f'- `{esc(k)}`' for k in c['knowledge_docs']) or '_None listed_'}

## Reporting

{mermaid or '_No reports_to / direct_reports edges in YAML._'}

## Links

- Machine source: [`cyborgs/{esc(c['path'])}`](https://github.com/toxicoder/inkorporated/blob/main/cyborgs/{esc(c['path'])})
{role_link}
"""
    # Fix system prompt in details - should not double-escape in fence; use raw
    body = body.replace(
        f"```text\n{c['system_prompt']}\n```",
        "```text\n" + c["system_prompt"].replace("```", "'''") + "\n```",
    )
    # title in frontmatter already quoted; body used esc on display - for markdown title use plain
    body = body.replace(f"# {esc(c['display_name'])}", f"# {c['display_name']}", 1)
    (PERSONAS_DIR / f"{c['job_id']}.md").write_text(body, encoding="utf-8")


def _mermaid_id(job_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", job_id)


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
        anchor = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
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
            f'### {title} {{#{anchor}}}\n\n'
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
        f"- [{title}](#{re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')})"
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

[← Roster](index.md)

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
    (OUT_DIR / "org_graph.md").write_text(body, encoding="utf-8")


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
        # clean personas to avoid stale IDs
        if PERSONAS_DIR.exists():
            for old in PERSONAS_DIR.glob("*.md"):
                old.unlink()
    PERSONAS_DIR.mkdir(parents=True, exist_ok=True)

    role_pages = find_role_pages()
    write_roster(cyborgs)
    write_grouped(
        cyborgs,
        "namespace",
        "Cyborgs by namespace",
        "by_namespace.md",
    )
    write_grouped(
        cyborgs,
        "security_level",
        "Cyborgs by security level",
        "by_security.md",
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
