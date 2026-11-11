#!/usr/bin/env python3
"""Generate the Fumadocs navigation tree from the retired MkDocs ``nav`` declaration.

The MkDocs site declared its information architecture in ``mkdocs.yml`` under ``nav``.
Fumadocs builds its sidebar from a content source plus ``meta.json`` files, which cannot
express this repository's shape: eleven top-level sections, several of them holding pages
that sit in deep directories, and roughly 870 pages of which the old ``nav`` listed 79.

So the nav is transcribed once into ``docs-site/lib/nav.json`` and applied by the
page-tree builder in ``docs-site/lib/nav.ts``. This script is the transcription, plus the
coverage rule that made the old site's unlisted pages reachable in the new one:

1. the curated ``nav:`` block wins, in its own order, and is copied verbatim;
2. every collection page the block does not name is folded into the section that owns its
   directory, grouped by subdirectory, so no page is an orphan;
3. a page that is listed twice, or a listed page that does not exist, fails the run.

While ``mkdocs.yml`` exists the tree is transcribed from it. Once it is gone the committed
``nav.json`` is the source of truth and ``--check`` verifies it against the files on disk.

Usage:
    python3 docs-site/scripts/gen_nav.py [--check] [--print]

Options:
    --check   Exit 1 if the committed nav.json differs from what the tree says.
    --print   Print the JSON to stdout without writing.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MKDOCS_YML = REPO_ROOT / "mkdocs.yml"
DOCS_DIR = REPO_ROOT / "docs"
OUT_JSON = REPO_ROOT / "docs-site" / "lib" / "nav.json"

#: ``- Label: path/to/page.md`` (a nav leaf).
_NAV_LEAF_RE = re.compile(r"^[ \t]*-[ \t]+(?P<label>[^:\n]+?):[ \t]+(?P<path>[A-Za-z0-9_.\-/]+\.md)[ \t]*$")
#: ``- Label:`` with no value (a nav group).
_NAV_GROUP_RE = re.compile(r"^[ \t]*-[ \t]+(?P<label>[^:\n]+?):[ \t]*$")

#: Directory-level content is excluded from the collection, mirroring the ``files``
#: globs in ``docs-site/source.config.ts``. The two lists must stay in step: a page the
#: site does not compile but the nav names makes ``buildPageTree`` throw at build time,
#: and a page the site compiles but the nav omits fails the coverage rule below.
EXCLUDED_DIRS = frozenset({"includes", "_data", "assets", "__pycache__"})
EXCLUDED_NAMES = frozenset({"README.md", "BUILD.bazel", "requirements.txt", "Gemfile"})
EXCLUDED_SUFFIXES = frozenset({".json", ".sh", ".py"})
COLLECTION_SUFFIXES = frozenset({".md", ".mdx"})

#: Section a top-level directory belongs to when the curated ``nav:`` block never named
#: it. Without this table the 790 pages MkDocs kept out of its nav would stay invisible;
#: with it, a new page under a known directory lands in the menu automatically. A
#: directory absent from both the nav and this table is an error, not a silent drop.
DIRECTORY_TABS: dict[str, str] = {
    "guides": "Getting Started",
    "organization": "Organization",
    "corporate_strategy": "Corporate Strategy",
    "job_roles": "Job Roles",
    "cyborgs": "Cyborgs",
    "engineering_standards": "Engineering",
    "policies": "Policies",
    "architecture": "Infrastructure",
    "reference": "Infrastructure",
    "adr": "Infrastructure",
    "user_management": "Infrastructure",
    "style_guides": "Contributing",
    "status": "Status",
    "interview_questions": "Interview Questions",
    "training": "Training",
    "onboarding": "Onboarding",
    "playbooks": "Playbooks",
    "technical_support": "Technical Support",
}

#: Order the sections created only by folding are appended in, so the menu does not depend
#: on filesystem enumeration order.
NEW_TAB_ORDER = (
    "Onboarding",
    "Interview Questions",
    "Training",
    "Playbooks",
    "Technical Support",
)

#: Root-level pages that are not the site home page get a section of their own.
ROOT_TAB = "Contributing"
HOME_PAGE = "index.md"


def _nav_block(lines: list[str]) -> list[str]:
    """Slice the ``nav:`` block out of a mkdocs.yml.

    Args:
        lines: All lines of ``mkdocs.yml``.

    Returns:
        The lines belonging to the ``nav`` list, excluding the key itself.
    """
    try:
        start = next(i for i, line in enumerate(lines) if line.startswith("nav:"))
    except StopIteration:
        raise ValueError("mkdocs.yml has no top-level nav: key") from None
    body: list[str] = []
    for line in lines[start + 1 :]:
        if line.strip() and not line.startswith((" ", "\t", "#")):
            break
        body.append(line)
    return body


def _dash_column(line: str) -> int:
    """Return the column of a nav line's ``-`` bullet.

    Args:
        line: A nav line whose first non-space character is ``-``.

    Returns:
        Zero-based column index of the bullet.
    """
    return len(line) - len(line.lstrip(" \t"))


def parse_nav(mkdocs_text: str) -> list[dict[str, object]]:
    """Convert the MkDocs ``nav`` list into the Fumadocs group layout.

    Nesting is read from the bullet column rather than from indentation size, so a tab
    entry and its children are told apart regardless of how the file happens to be
    indented. A tab may be a bare page (``- Home: index.md``) or a list of pages, and a
    tab's list may contain nested groups whose leaves still belong to that tab.

    Args:
        mkdocs_text: Contents of ``mkdocs.yml``.

    Returns:
        One entry per top-level tab: ``{"title", "pages"}`` where ``pages`` holds the
        ordered ``{"title", "path"}`` leaves declared under that tab.
    """
    lines = [
        line
        for line in _nav_block(mkdocs_text.split("\n"))
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not lines:
        raise ValueError("mkdocs.yml nav is empty")
    tab_column = min(_dash_column(line) for line in lines)

    tabs: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    for line in lines:
        is_tab_level = _dash_column(line) == tab_column
        leaf = _NAV_LEAF_RE.match(line)
        group = _NAV_GROUP_RE.match(line)

        if is_tab_level and group:
            current = {"title": group.group("label").strip(), "pages": []}
            tabs.append(current)
            continue
        if is_tab_level and leaf:
            tabs.append(
                {
                    "title": leaf.group("label").strip(),
                    "pages": [
                        {"title": leaf.group("label").strip(), "path": leaf.group("path").strip()}
                    ],
                }
            )
            current = tabs[-1]
            continue
        if leaf:
            if current is None:
                raise ValueError(f"nav leaf appears before any tab: {line!r}")
            assert isinstance(current["pages"], list)
            current["pages"].append(
                {"title": leaf.group("label").strip(), "path": leaf.group("path").strip()}
            )
            continue
        if group:
            continue  # Nested group heading; its leaves attach to the enclosing tab.
        raise ValueError(f"unparsed nav line: {line!r}")

    if not tabs:  # pragma: no cover
        # Unreachable by construction: ``tab_column`` is the shallowest bullet, so the first
        # such line either opens a tab or raises below, and an empty nav fails earlier. Kept
        # as an invariant guard against a future parser letting an empty tree through.
        raise ValueError("mkdocs.yml nav produced no tabs")
    return tabs


def flatten_pages(nodes: object) -> list[dict[str, str]]:
    """Collect every ``{"title", "path"}`` leaf below ``nodes``, in nav order.

    A node is either a leaf (it carries ``path``) or a group (it carries a ``pages``
    list). Tabs, sidebar folders, and any deeper nesting all use the group shape, so the
    walk is recursive rather than fixed to two levels.

    Args:
        nodes: Tabs, a tab's ``pages`` list, or any deeper group's ``pages`` list.

    Returns:
        The leaves in the order a reader meets them, deepest groups first inside their
        own position.
    """
    leaves: list[dict[str, str]] = []
    if isinstance(nodes, dict):
        nodes = [nodes]
    if not isinstance(nodes, list):
        return leaves
    for node in nodes:
        if not isinstance(node, dict):
            continue
        path = node.get("path")
        if isinstance(path, str) and path:
            leaves.append({"title": str(node.get("title", "")), "path": path})
            continue
        leaves.extend(flatten_pages(node.get("pages")))
    return leaves


def is_collection_page(relative: pathlib.PurePosixPath) -> bool:
    """Report whether a file under ``docs/`` is a page the site compiles.

    Mirrors the ``files`` globs of ``docs-site/source.config.ts``. Keeping the rule here
    as one function is what lets ``test_gen_nav.py`` assert the two agree.

    Args:
        relative: Path of the file relative to ``docs/``.

    Returns:
        ``True`` when Fumadocs includes the file in the docs collection.
    """
    parts = relative.parts
    if any(part in EXCLUDED_DIRS for part in parts):
        return False
    name = relative.name
    if name in EXCLUDED_NAMES:
        return False
    if relative.suffix not in COLLECTION_SUFFIXES:
        return False
    return not (relative.suffix in EXCLUDED_SUFFIXES)


def discover_pages() -> list[str]:
    """List every collection page on disk, POSIX-style and sorted.

    Returns:
        Paths relative to ``docs/``, in lexicographic order.
    """
    if not DOCS_DIR.is_dir():  # pragma: no cover - the repository always ships docs/
        return []
    found = [
        p.relative_to(DOCS_DIR).as_posix()
        for p in DOCS_DIR.rglob("*")
        if p.is_file() and is_collection_page(p.relative_to(DOCS_DIR))
    ]
    return sorted(found)


def prettify(directory: str) -> str:
    """Turn a directory segment into a readable folder title.

    Args:
        directory: A directory name such as ``specialized_squads_cross_functional_teams``.

    Returns:
        ``Specialized squads cross functional teams``.
    """
    return directory.replace("_", " ").replace("-", " ").strip().title()


def _group_title(directory: str, curated_titles: dict[str, str]) -> str:
    """Title a folded folder from its own index page when it has one.

    A directory that carries an ``index.md`` the curated nav already labels reads under
    the same words the old site used ("Executive leadership" rather than
    "Executive_Leadership").

    Args:
        directory: Directory path relative to ``docs/``, no trailing slash.
        curated_titles: Curated leaf titles keyed by page path.

    Returns:
        The folder label to print in the sidebar.
    """
    for suffix in (".md", ".mdx"):
        index = f"{directory}/index{suffix}"
        if index in curated_titles:
            return curated_titles[index]
    return prettify(directory.rsplit("/", 1)[-1] if "/" in directory else directory)


def _page_key(path: str) -> str:
    """Return the identity a page has regardless of which collection suffix it uses.

    ``docs-site/lib/nav.ts`` matches a nav entry against the collection with the extension
    stripped, and the MDX migration renames a page from ``.md`` to ``.mdx`` without touching
    its address, so a curated entry that still names the ``.md`` path and the on-disk ``.mdx``
    file are one page. Comparing raw paths would let the fold file that page a second time.

    Args:
        path: Page path relative to ``docs/``, with either collection suffix.

    Returns:
        The path with a trailing ``.md`` or ``.mdx`` removed.
    """
    if path.endswith(".md") or path.endswith(".mdx"):
        return path.rsplit(".", 1)[0]
    return path


def fold_unlisted(tabs: list[dict[str, object]]) -> list[dict[str, object]]:
    """Append every page the curated nav omits, under the section that owns its directory.

    The curated leaves keep their tab and their order and are emitted first, so the front
    door of each section is exactly what MkDocs showed. Below them, unlisted pages are
    gathered into one folder per subdirectory, folders sorted by path, pages sorted by
    file name with a directory's own ``index`` first.

    Args:
        tabs: Output of :func:`parse_nav`, or the committed tree.

    Returns:
        A new tab list in which every collection page appears exactly once.

    Raises:
        ValueError: A page sits in a directory no section claims.
    """
    pages = discover_pages()
    claimed = {_page_key(page["path"]) for page in flatten_pages(tabs)}
    curated_titles = {page["path"]: page["title"] for page in flatten_pages(tabs)}

    by_tab: dict[str, dict[str, list[str]]] = {}
    for tab in tabs:
        by_tab[str(tab["title"])] = {}

    for path in pages:
        if _page_key(path) in claimed:
            continue
        relative = pathlib.PurePosixPath(path)
        if len(relative.parts) == 1:
            tab_title = ROOT_TAB if path != HOME_PAGE else _tab_of_home(tabs)
            folders = by_tab.setdefault(tab_title, {})
            folders.setdefault("", []).append(path)
            continue
        top = relative.parts[0]
        tab_title = DIRECTORY_TABS.get(top)
        if tab_title is None:
            raise ValueError(
                f"docs/{path} sits under '{top}/', which no nav section claims: add the "
                "directory to DIRECTORY_TABS in docs-site/scripts/gen_nav.py"
            )
        folders = by_tab.setdefault(tab_title, {})
        folders.setdefault(relative.parent.as_posix(), []).append(path)

    result: list[dict[str, object]] = [
        {"title": tab["title"], "pages": list(tab["pages"])} for tab in tabs
    ]
    by_title = {str(tab["title"]): tab for tab in result}

    for tab_title, folders in by_tab.items():
        tab = by_title.get(tab_title)
        if tab is None:  # A section that exists only because a folded directory needs it.
            tab = {"title": tab_title, "pages": []}
            by_title[tab_title] = tab
            result.append(tab)
        pages_out = tab["pages"]
        assert isinstance(pages_out, list)
        for directory in sorted(folders):
            members = sorted(folders[directory], key=_sort_key)
            if directory == "":
                pages_out.extend({"title": _leaf_title(m, curated_titles), "path": m} for m in members)
                continue
            pages_out.append(
                {
                    "title": _group_title(directory, curated_titles),
                    "pages": [{"title": _leaf_title(m, curated_titles), "path": m} for m in members],
                }
            )

    return _order_new_tabs(result, {str(tab["title"]) for tab in tabs})


def _tab_of_home(tabs: list[dict[str, object]]) -> str:
    """Section that already holds the site home page, so folding cannot orphan ``index.md``.

    Args:
        tabs: The curated tab list.

    Returns:
        Its title, or ``"Home"`` when the home page is not curated.
    """
    for tab in tabs:
        if any(page["path"] == HOME_PAGE for page in flatten_pages(tab["pages"])):
            return str(tab["title"])
    return "Home"  # pragma: no cover - mkdocs.yml always curates index.md


def _sort_key(path: str) -> tuple[int, str]:
    """Sort pages inside one folder: the folder's own index first, then by name.

    Args:
        path: Page path relative to ``docs/``.

    Returns:
        A sort key.
    """
    name = pathlib.PurePosixPath(path).name
    return (0 if name.startswith("index.") else 1, name)


def _leaf_title(path: str, curated_titles: dict[str, str]) -> str:
    """Label a folded page from its frontmatter title.

    Args:
        path: Page path relative to ``docs/``.
        curated_titles: Curated titles keyed by path, consulted for an authored page.

    Returns:
        The frontmatter ``title`` when it parses, else the file stem.
    """
    if path in curated_titles:
        return curated_titles[path]
    file = DOCS_DIR / path
    try:
        text = file.read_text(encoding="utf-8", errors="replace")
    except OSError:  # pragma: no cover - discover_pages only returns real files
        return pathlib.PurePosixPath(path).stem
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            match = re.search(r"^title:[ \t]*(?P<title>.+?)[ \t]*$", text[4:end], re.M)
            found = match.group("title") if match else ""
            found = found.strip().strip("\"'")
            if found:
                return found
    return pathlib.PurePosixPath(path).stem


def _order_new_tabs(tabs: list[dict[str, object]], curated: set[str]) -> list[dict[str, object]]:
    """Move sections created only by folding into :data:`NEW_TAB_ORDER` position.

    Sections the curated nav declared keep their authored position. A section created by
    folding is appended, and the known ones are ordered so the menu does not shift when a
    directory is added.

    Args:
        tabs: Tab list with folded content merged in.
        curated: Titles of the sections the curated nav declared.

    Returns:
        The same tabs, reordered.
    """
    kept = [tab for tab in tabs if str(tab["title"]) in curated]
    moved = [tab for tab in tabs if str(tab["title"]) not in curated]
    ranked = sorted(
        moved,
        key=lambda tab: (
            NEW_TAB_ORDER.index(str(tab["title"])) if str(tab["title"]) in NEW_TAB_ORDER else len(NEW_TAB_ORDER),
            str(tab["title"]),
        ),
    )
    return kept + ranked


def validate(tabs: list[dict[str, object]]) -> list[str]:
    """Check the nav against the files on disk.

    Args:
        tabs: Output of :func:`fold_unlisted`, or the committed tree once ``mkdocs.yml``
            is retired.

    Returns:
        Human-readable problems; empty when the nav is consistent.
    """
    problems: list[str] = []
    seen: dict[str, int] = {}
    # The report names the path an author wrote, so keep one raw path per identity.
    first_path: dict[str, str] = {}
    for page in flatten_pages(tabs):
        declared = DOCS_DIR / page["path"]
        if not declared.is_file() and not declared.with_suffix(".mdx").is_file():
            problems.append(f"nav page missing on disk: docs/{page['path']}")
        key = _page_key(page["path"])
        seen[key] = seen.get(key, 0) + 1
        first_path.setdefault(key, page["path"])
    for key, count in sorted(seen.items()):
        if count > 1:
            problems.append(f"nav page listed {count} times: docs/{first_path[key]}")

    missing = [path for path in sorted(discover_pages()) if _page_key(path) not in seen]
    for path in missing[:40]:
        problems.append(f"page missing from the nav: docs/{path}")
    if len(missing) > 40:
        problems.append(f"... and {len(missing) - 40} more pages missing from the nav")
    return problems


def build_tree() -> list[dict[str, object]]:
    """Produce the navigation tree for this checkout.

    While ``mkdocs.yml`` exists the curated block is transcribed from it; afterwards the
    committed ``nav.json`` is the curated source and is folded again so a page added under
    any known directory is picked up without a hand edit.

    Returns:
        The tab list, every collection page appearing exactly once.

    Raises:
        FileNotFoundError: Neither ``mkdocs.yml`` nor ``nav.json`` is available.
    """
    if MKDOCS_YML.is_file():
        tabs = parse_nav(MKDOCS_YML.read_text(encoding="utf-8"))
    elif OUT_JSON.is_file():
        tabs = json.loads(OUT_JSON.read_text(encoding="utf-8"))
    else:
        raise FileNotFoundError(
            f"neither {MKDOCS_YML} nor {OUT_JSON} exists: the nav needs one of them"
        )
    return fold_unlisted(tabs)


def main(argv: list[str] | None = None) -> int:
    """Generate or verify ``docs-site/lib/nav.json``.

    Args:
        argv: Argument vector (defaults to ``sys.argv[1:]``).

    Returns:
        ``0`` on success, ``1`` on a validation problem or ``--check`` drift.
    """
    parser = argparse.ArgumentParser(description="Generate or verify docs-site/lib/nav.json.")
    parser.add_argument("--check", action="store_true", help="fail if the committed file is stale")
    parser.add_argument("--print", action="store_true", dest="print_only", help="write to stdout")
    args = parser.parse_args(argv)

    try:
        tabs = build_tree()
    except FileNotFoundError as error:
        print(f"gen_nav: {error}", file=sys.stderr)
        return 1

    problems = validate(tabs)
    if problems:
        for problem in problems:
            print(f"nav problem: {problem}", file=sys.stderr)
        return 1

    payload = json.dumps(tabs, indent=2, ensure_ascii=False) + "\n"
    if args.print_only:
        sys.stdout.write(payload)
        return 0

    existing = OUT_JSON.read_text(encoding="utf-8") if OUT_JSON.is_file() else None
    if args.check:
        if existing != payload:
            print("docs-site/lib/nav.json is stale; run docs-site/scripts/gen_nav.py", file=sys.stderr)
            return 1
        print("nav.json is up to date.")
        return 0
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(payload, encoding="utf-8")
    pages = len(flatten_pages(tabs))
    print(f"wrote {OUT_JSON.relative_to(REPO_ROOT)} ({len(tabs)} tabs, {pages} pages)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
