#!/usr/bin/env python3
"""Render-oriented checks for the Inkorporated Fumadocs documentation site.

The site is a Next.js App Router static export (``docs-site/``) that reads the markdown
where it has always lived (``docs/``). Nothing here needs a browser or a build: the source
contract - navigation, frontmatter, fences, chrome wiring, theme tokens - is checked against
the files that produce the pages, and always runs. The export checks in ``ExportTests`` skip
with a printed note when ``docs-site/out/`` has not been built.

Usage:
    python3 docs/test_docs_site_render.py

Exit status is 0 when every test passed or skipped.
"""

from __future__ import annotations

import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DOCS_DIR = REPO_ROOT / "docs"
SITE_DIR = REPO_ROOT / "docs-site"
EXPORT_DIR = SITE_DIR / "out"
NAV_JSON = SITE_DIR / "lib" / "nav.json"
GEN_NAV_PY = SITE_DIR / "scripts" / "gen_nav.py"

#: Directory segment that marks a page as generator-owned rather than authored.
GENERATED_DIR = "generated"
#: Site home page, relative to ``docs/``. Kept as a local default; the assertion that needs
#: the generator's own wording reads ``HOME_PAGE`` off ``docs-site/scripts/gen_nav.py``.
HOME_PAGE = "index.md"

FRONTMATTER_RE = re.compile(r"^---[ \t]*\n(?P<body>.*?)\n---[ \t]*\n", re.S)
#: An opening or closing code fence, with the info string of an opening one.
FENCE_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<fence>`{3,}|~{3,})(?P<info>[^`\n]*)$")
MERMAID_INFO_RE = re.compile(r"^mermaid\b", re.I)
#: ``[label {{ interpolation }}]`` - mermaid needs the label quoted for braces to survive.
BAD_MERMAID_LABEL_RE = re.compile(r'\[[^"\]]*\{\{')

#: MkDocs-only syntax Fumadocs would print as literal text.
GRID_CARDS_RE = re.compile(r"grid\s+cards")
TOC_RE = re.compile(r"^\s*\[TOC\]\s*$", re.M | re.I)
INCLUDE_RE = re.compile(r"\{!\s*[^}\n]*!\}")
SNIPPET_RE = re.compile(r"--8<-")
TAB_LINE_RE = re.compile(r'^\s*={3,}[ \t]*["\']', re.M)

#: The indigo identity this repo adopted, from the retired ``mkdocs.yml`` palette.
INDIGO_PRIMARY = "#3f51b5"
INDIGO_PRIMARY_DARK = "#8c9eff"
#: The donor site's Pages prefixes: this repo publishes at ``/inkorporated/<alias>/``.
DONOR_PAGES_PATHS = ("ez-comfy-stack", "nvidia-dgx-spark-lab")


def _load_gen_nav():
    """Import ``docs-site/scripts/gen_nav.py`` so the nav expectations come from it.

    The tab titles and the home page are asserted against the generator's own tables
    (``DIRECTORY_TABS``, ``ROOT_TAB``, ``HOME_PAGE``) rather than a copy of them that would
    silently age out of step with the site.

    Returns:
        The loaded module.

    Raises:
        AssertionError: The generator is missing, so there is nothing to derive from.
    """
    if not GEN_NAV_PY.is_file():
        raise AssertionError(f"missing nav generator: {GEN_NAV_PY}")
    spec = importlib.util.spec_from_file_location("gen_nav_under_test", GEN_NAV_PY)
    if spec is None or spec.loader is None:  # pragma: no cover - importlib contract
        raise AssertionError(f"cannot load {GEN_NAV_PY}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_yaml():
    """Import PyYAML when the interpreter has it.

    Returns:
        The ``yaml`` module, or ``None`` when it is not installed. Nothing here installs a
        dependency; the caller skips the one assertion that needs a real YAML parser.
    """
    try:
        import yaml  # noqa: PLC0415 - optional dependency, probed at call time
    except ImportError:
        return None
    return yaml


def load_nav_tree() -> list[dict[str, object]]:
    """Read the committed navigation tree.

    Returns:
        One entry per top-level section.

    Raises:
        AssertionError: ``nav.json`` is missing, or is not a list of sections.
    """
    if not NAV_JSON.is_file():
        raise AssertionError(f"{NAV_JSON} is missing; run python3 docs-site/scripts/gen_nav.py")
    tree = json.loads(NAV_JSON.read_text(encoding="utf-8"))
    if not isinstance(tree, list):
        raise AssertionError(f"{NAV_JSON} must hold a list of sections, got {type(tree).__name__}")
    return tree


def _flatten_nav(nodes: object) -> list[str]:
    """Collect page paths from nested nav nodes.

    Args:
        nodes: A ``pages`` list, which mixes leaves (they carry ``path``) and groups
            (they carry a nested ``pages`` list).

    Returns:
        Paths relative to ``docs/``, in menu order.
    """
    out: list[str] = []
    if not isinstance(nodes, list):
        return out
    for node in nodes:
        if not isinstance(node, dict):
            continue
        path = node.get("path")
        if isinstance(path, str) and path:
            out.append(path)
        out.extend(_flatten_nav(node.get("pages")))
    return out


def nav_pages_of(tab: object) -> list[dict[str, object]]:
    """Leaves below one section, as ``{"title", "path"}`` mappings.

    Args:
        tab: One section of ``nav.json``.

    Returns:
        Its leaves in menu order.
    """
    out: list[dict[str, object]] = []

    def walk(nodes: object) -> None:
        if not isinstance(nodes, list):
            return
        for node in nodes:
            if not isinstance(node, dict):
                continue
            if isinstance(node.get("path"), str):
                out.append(node)
            else:
                walk(node.get("pages"))

    if isinstance(tab, dict):
        walk(tab.get("pages"))
    return out


def load_nav_pages() -> list[str]:
    """Return every content path the static navigation lists.

    Returns:
        POSIX paths relative to ``docs/``.
    """
    pages: list[str] = []
    for tab in load_nav_tree():
        pages.extend(_flatten_nav(tab.get("pages")))
    assert pages, f"{NAV_JSON} lists no pages; run python3 docs-site/scripts/gen_nav.py"
    return pages


def _is_generated(rel: str) -> bool:
    """Whether a nav path sits in a generator-owned tree.

    Args:
        rel: Path relative to ``docs/``.

    Returns:
        ``True`` for anything under a ``generated/`` directory.
    """
    return GENERATED_DIR in Path(rel).parts


def hand_written_nav_pages() -> list[str]:
    """Navigable authored pages, with the generator-owned trees left out.

    Returns:
        Paths relative to ``docs/``.
    """
    return [p for p in load_nav_pages() if not _is_generated(p)]


def generated_nav_pages() -> list[str]:
    """Navigable pages a generator writes, which the generator is graded on.

    Returns:
        Paths relative to ``docs/``.
    """
    return [p for p in load_nav_pages() if _is_generated(p)]


def authored_pages() -> list[Path]:
    """Every authored page in the docs tree, generator output excluded.

    The generator owns ``docs/**/generated/``, so those trees are checked by their own
    lane (``docs/check_generated_render.sh``) and not graded for authored conventions.

    Returns:
        Sorted ``.md`` / ``.mdx`` paths under ``docs/``.
    """
    found: list[Path] = []
    for path in sorted(DOCS_DIR.rglob("*")):
        if path.suffix not in {".md", ".mdx"}:
            continue
        if GENERATED_DIR in path.relative_to(DOCS_DIR).parts:
            continue
        found.append(path)
    return found


def page_file(rel: str) -> Path:
    """Locate the file a nav entry points at, accepting either extension.

    Args:
        rel: Path relative to ``docs/`` as recorded in the navigation.

    Returns:
        The page on disk.

    Raises:
        AssertionError: Neither ``.md`` nor ``.mdx`` exists.
    """
    stem = rel[: rel.rfind(".")] if "." in rel else rel
    for candidate in (DOCS_DIR / f"{stem}.md", DOCS_DIR / f"{stem}.mdx"):
        if candidate.is_file():
            return candidate
    raise AssertionError(f"Missing content page for nav entry {rel!r}")


def page_source(rel: str) -> str:
    """Read a content page named by the navigation.

    Args:
        rel: Path relative to ``docs/``.

    Returns:
        Page text.
    """
    return page_file(rel).read_text(encoding="utf-8", errors="replace")


def site_source(rel: str) -> str:
    """Read a file of the Next.js app.

    Args:
        rel: Path relative to ``docs-site/``.

    Returns:
        File text.
    """
    path = SITE_DIR / rel
    if not path.is_file():
        raise AssertionError(f"missing docs-site file: docs-site/{rel}")
    return path.read_text(encoding="utf-8", errors="replace")


def frontmatter(text: str) -> str | None:
    """Return a page's frontmatter body.

    Args:
        text: Page source.

    Returns:
        The text between the leading ``---`` fences, or ``None`` when it has none.
    """
    match = FRONTMATTER_RE.match(text)
    return match.group("body") if match else None


def fence_scan(
    text: str,
) -> tuple[list[tuple[int, str, int]], list[tuple[int, str]], list[tuple[int, str]]]:
    """Walk a page's code fences.

    Args:
        text: Page source.

    Returns:
        ``(opens, outside, mermaid_lines)``: ``opens`` holds ``(line, info, marker_len)`` for
        every opening fence, ``outside`` holds ``(line, text)`` for lines no fence covers,
        and ``mermaid_lines`` holds ``(line, text)`` for the body of ``mermaid`` fences.
    """
    opens: list[tuple[int, str, int]] = []
    outside: list[tuple[int, str]] = []
    mermaid_lines: list[tuple[int, str]] = []
    in_fence = False
    marker = ""
    marker_len = 0
    info = ""
    for number, line in enumerate(text.splitlines(), start=1):
        match = FENCE_RE.match(line)
        fence = match.group("fence") if match else ""
        if match and not in_fence:
            in_fence = True
            marker = fence[0]
            marker_len = len(fence)
            info = match.group("info").strip()
            opens.append((number, info, marker_len))
            continue
        closes = (
            in_fence
            and match is not None
            and fence[0] == marker
            and len(fence) >= marker_len
            and not match.group("info").strip()
        )
        if closes:
            in_fence = False
            continue
        if not in_fence:
            outside.append((number, line))
        elif MERMAID_INFO_RE.match(info):
            mermaid_lines.append((number, line))
    return opens, outside, mermaid_lines


class NavContractTests(unittest.TestCase):
    """``docs-site/lib/nav.json`` is the navigation and it agrees with the tree."""

    def test_nav_json_exists_and_parses(self) -> None:
        """The transcribed navigation is committed and shaped like a list of sections."""
        tree = load_nav_tree()
        self.assertTrue(tree, f"{NAV_JSON} holds no sections")
        for tab in tree:
            self.assertIsInstance(tab.get("title"), str, f"section without a title: {tab}")
            self.assertIsInstance(
                tab.get("pages"), list, f"section without a page list: {tab.get('title')}"
            )

    def test_nav_pages_exist_on_disk(self) -> None:
        """Each nav path has a ``.md`` or ``.mdx`` file under ``docs/``."""
        missing: list[str] = []
        for rel in load_nav_pages():
            stem = rel[: rel.rfind(".")] if "." in rel else rel
            if not (DOCS_DIR / f"{stem}.md").is_file() and not (DOCS_DIR / f"{stem}.mdx").is_file():
                missing.append(rel)
        self.assertEqual([], missing, "nav.json names pages that are not in docs/")

    def test_every_tab_is_non_empty(self) -> None:
        """An empty section renders as a dead row in the sidebar."""
        empty = [str(tab.get("title")) for tab in load_nav_tree() if not tab.get("pages")]
        self.assertEqual([], empty, "sections with no pages")

    def test_tab_titles_are_the_sections_this_repo_has(self) -> None:
        """The sections are the ones ``gen_nav.py`` declares, not a transplanted list.

        Every value of ``DIRECTORY_TABS`` plus ``ROOT_TAB`` must appear. The one section
        allowed beyond that set is the section the curated nav holds the home page in.
        """
        gen_nav = _load_gen_nav()
        tree = load_nav_tree()
        titles = [str(tab["title"]) for tab in tree]
        derived = set(gen_nav.DIRECTORY_TABS.values()) | {gen_nav.ROOT_TAB}
        actual = set(titles)

        self.assertEqual(
            [], sorted(derived - actual), "sections gen_nav.py declares but nav.json dropped"
        )
        home = str(gen_nav.HOME_PAGE)
        home_tabs = sorted(
            {str(tab["title"]) for tab in tree if any(p.get("path") == home for p in nav_pages_of(tab))}
        )
        self.assertEqual(1, len(home_tabs), f"{home} must be curated into exactly one section")
        self.assertEqual(
            sorted(actual - derived),
            home_tabs,
            "nav.json carries sections the generator cannot produce",
        )
        self.assertEqual(
            home_tabs[0], titles[0], f"the section holding {home} must lead the menu"
        )

    def test_no_page_is_listed_twice(self) -> None:
        """One sidebar row per page: a duplicate menu links at the same page twice.

        The comparison ignores the extension, because ``docs-site/lib/nav.ts`` resolves a
        nav entry by its extension-less path, so ``page.md`` and ``page.mdx`` name the same
        page to the sidebar even though only one of them is a file.
        """
        seen: dict[str, list[str]] = {}
        for rel in load_nav_pages():
            stem = rel[: rel.rfind(".")] if "." in rel else rel
            seen.setdefault(stem, []).append(rel)
        duplicated = [f"{stem}: {paths}" for stem, paths in sorted(seen.items()) if len(paths) > 1]
        self.assertEqual([], duplicated, "nav.json lists the same page more than once")

    def test_the_site_enforces_the_same_contract(self) -> None:
        """``lib/nav.ts`` fails the build for a nav page the collection does not hold."""
        nav = site_source("lib/nav.ts")
        self.assertIn('import navData from "./nav.json"', nav)
        self.assertIn("export function buildPageTree", nav)
        self.assertIn("navigation references a page that is not in the content source", nav)


class LeftoverMkdocsTests(unittest.TestCase):
    """MkDocs-only syntax that Fumadocs prints as text must not remain authored."""

    @staticmethod
    def _scan(pattern: re.Pattern[str]) -> list[str]:
        """Find authored pages using a construct, ignoring anything inside a code fence.

        A page may document the retired syntax inside a fence, which renders as text on
        purpose; only lines the reader meets as prose are graded.

        Args:
            pattern: The construct to look for.

        Returns:
            ``docs/``-relative paths with a line number and the offending text.
        """
        hits: list[str] = []
        for path in authored_pages():
            rel = path.relative_to(DOCS_DIR).as_posix()
            _, outside, _ = fence_scan(path.read_text(encoding="utf-8", errors="replace"))
            for number, line in outside:
                if pattern.search(line):
                    hits.append(f"{rel}:{number}: {line.strip()[:80]}")
        return hits

    def test_authored_pages_have_no_grid_cards_divs(self) -> None:
        """``grid cards`` is a Material annotation; Fumadocs has no card grid for it."""
        self.assertEqual([], self._scan(GRID_CARDS_RE))

    def test_authored_pages_have_no_toc_or_include_or_snippet_syntax(self) -> None:
        """``[TOC]``, ``{! include !}`` and ``--8<--`` were pymdownx/MkDocs extensions."""
        for pattern in (TOC_RE, INCLUDE_RE, SNIPPET_RE):
            self.assertEqual([], self._scan(pattern), pattern.pattern)

    def test_authored_pages_have_no_pymdownx_tab_lines(self) -> None:
        """``=== "Title"`` produced Material's tab sets and is inert here."""
        self.assertEqual([], self._scan(TAB_LINE_RE))


class FrontmatterTests(unittest.TestCase):
    """Frontmatter satisfies the schemas ``source.config.ts`` applies."""

    def test_hand_written_pages_have_frontmatter_with_title(self) -> None:
        """Every authored page parses as YAML frontmatter and carries a ``title``.

        ``docSchema`` is ``pageSchema.extend(...)`` and ``pageSchema`` requires a string
        ``title``, so a page without one fails the collection.
        """
        yaml = _load_yaml()
        if yaml is None:
            print("NOTE: PyYAML is not importable; skipping the frontmatter parse assertion")
            self.skipTest("PyYAML is not installed")
        problems: list[str] = []
        for rel in hand_written_nav_pages():
            body = frontmatter(page_source(rel))
            if body is None:
                problems.append(f"{rel}: missing YAML frontmatter")
                continue
            try:
                data = yaml.safe_load(body)
            except yaml.YAMLError as error:  # pragma: no cover - content defect
                problems.append(f"{rel}: frontmatter is not valid YAML: {str(error).splitlines()[0]}")
                continue
            if not isinstance(data, dict):
                problems.append(f"{rel}: frontmatter is a {type(data).__name__}, not a mapping")
                continue
            title = data.get("title")
            if not isinstance(title, str) or not title.strip():
                problems.append(f"{rel}: frontmatter title must be a non-empty string")
        self.assertEqual([], problems)

    def test_hand_written_frontmatter_field_types_match_doc_schema(self) -> None:
        """``description``/``icon`` are strings, ``full`` is a bool, ``tags`` str or list.

        That is what ``docSchema`` (``pageSchema`` plus an optional ``tags``) accepts; a
        value of another type is stripped or rejected by the collection.
        """
        yaml = _load_yaml()
        if yaml is None:
            print("NOTE: PyYAML is not importable; skipping the frontmatter type assertion")
            self.skipTest("PyYAML is not installed")
        problems: list[str] = []
        for rel in hand_written_nav_pages():
            body = frontmatter(page_source(rel))
            if body is None:
                continue
            data = yaml.safe_load(body)
            if not isinstance(data, dict):
                continue
            for key in ("title", "description", "icon"):
                if key in data and not isinstance(data[key], str):
                    problems.append(f"{rel}: {key} is a {type(data[key]).__name__}, wants a string")
            if "full" in data and not isinstance(data["full"], bool):
                problems.append(f"{rel}: full is a {type(data['full']).__name__}, wants a bool")
            tags = data.get("tags")
            tags_ok = isinstance(tags, str) or (
                isinstance(tags, list) and all(isinstance(tag, str) for tag in tags)
            )
            if tags is not None and not tags_ok:
                problems.append(f"{rel}: tags must be a string or a list of strings")
        self.assertEqual([], problems)

    def test_generated_pages_may_omit_the_title(self) -> None:
        """``generatedSchema`` keeps ``title`` optional for generator output."""
        yaml = _load_yaml()
        if yaml is None:
            print("NOTE: PyYAML is not importable; skipping the generated frontmatter assertion")
            self.skipTest("PyYAML is not installed")
        self.assertTrue(generated_nav_pages(), "no generated tree in the nav to check")
        problems: list[str] = []
        for rel in generated_nav_pages():
            body = frontmatter(page_source(rel))
            if body is None:
                problems.append(f"{rel}: missing YAML frontmatter")
                continue
            try:
                data = yaml.safe_load(body)
            except yaml.YAMLError as error:  # pragma: no cover - content defect
                problems.append(f"{rel}: frontmatter is not valid YAML: {str(error).splitlines()[0]}")
                continue
            if not isinstance(data, dict):
                problems.append(f"{rel}: frontmatter is a {type(data).__name__}, not a mapping")
                continue
            if "title" in data and not isinstance(data["title"], str):
                problems.append(f"{rel}: title must be a string when the generator writes one")
        self.assertEqual([], problems)

    def test_source_config_routes_generated_pages_to_generated_schema(self) -> None:
        """The schema split lives in ``source.config.ts``, the shapes in ``lib/content.ts``."""
        config = site_source("source.config.ts")
        self.assertIn('from "./lib/content"', config)
        self.assertIn("docSchema, generatedSchema", config)
        self.assertIn("schema({ path })", config)
        split = [line for line in config.splitlines() if "generatedSchema : docSchema" in line]
        self.assertEqual(1, len(split), "the schema split must pick one schema per path")
        # ``/(^|\/)generated(\/|$)/`` with the slashes the source escapes.
        self.assertRegex(
            split[0].replace("\\", ""),
            r"\(\^\|/\)generated\(/\|\$\)/\.test\(path",
            "the split must match a generated path segment, not a substring of a file name",
        )
        content = site_source("lib/content.ts")
        self.assertIn("export const docSchema = pageSchema.extend", content)
        self.assertRegex(
            content,
            r"export const generatedSchema = pageSchema\.extend\(\{\s*title: z\.string\(\)\.optional\(\)",
        )


class FenceTests(unittest.TestCase):
    """Fences name their language; mermaid labels stay quotable."""

    def test_fences_have_languages(self) -> None:
        """Every three-backtick fence on an authored page carries an info string.

        An unlabelled fence gets no Shiki grammar, so this repo labels even prose-shaped
        blocks (``text`` for directory trees and ASCII diagrams). Four-backtick display
        fences may stay bare.
        """
        missing: list[str] = []
        for rel in hand_written_nav_pages():
            opens, _, _ = fence_scan(page_source(rel))
            for number, info, marker_len in opens:
                if not info and marker_len <= 3:
                    missing.append(f"{rel}:{number}: fence with no language")
        self.assertEqual([], missing)

    def test_mermaid_labels_do_not_use_unquoted_braces(self) -> None:
        """``[A {{ x }}]`` inside a node label fails to parse in the browser."""
        bad: list[str] = []
        for rel in hand_written_nav_pages():
            _, _, mermaid_lines = fence_scan(page_source(rel))
            for number, line in mermaid_lines:
                if BAD_MERMAID_LABEL_RE.search(line):
                    bad.append(f"{rel}:{number}: {line.strip()[:80]}")
        self.assertEqual([], bad)


class NextExportMemoryTests(unittest.TestCase):
    """The export survives a 7 GB runner: webpack, one worker, on-demand MDX."""

    def test_package_json_build_scripts_use_webpack(self) -> None:
        """Turbopack static generation OOMs the runner across ~870 pages."""
        manifest = json.loads(site_source("package.json"))
        scripts = manifest.get("scripts", {})
        for name in ("build", "build:latest", "build:development"):
            self.assertIn("next build --webpack", scripts.get(name, ""), f"scripts.{name}")
        self.assertEqual("next build --webpack", scripts.get("build"))

    def test_next_config_caps_static_generation(self) -> None:
        """One worker, no build worker, no prerender source maps, externals pinned."""
        config = site_source("next.config.ts")
        for needle in (
            "cpus: 1",
            "staticGenerationMaxConcurrency: 1",
            "webpackBuildWorker: false",
            "webpackMemoryOptimizations: true",
            "enablePrerenderSourceMaps: false",
            'serverExternalPackages: ["fumadocs-mdx", "shiki"]',
            'output: "export"',
            "trailingSlash: true",
        ):
            self.assertIn(needle, config)

    def test_mdx_collection_compiles_on_demand(self) -> None:
        """Webpack must not bundle ~870 MDX files; the Config API compiles each on load."""
        config = site_source("source.config.ts")
        self.assertIn("defineDocs", config)
        self.assertIn("defineConfig", config)
        self.assertIn("dynamic: true", config)
        self.assertIn('dir: "../docs"', config)
        for rel in ("source.config.ts", "lib/content.ts", "lib/source.ts"):
            self.assertNotRegex(site_source(rel), r'''from ["']fumadocs-mdx/macro["']''', rel)
        self.assertIn("../.source/dynamic", site_source("lib/source.ts"))
        page = site_source("app/[[...slug]]/page.tsx")
        self.assertRegex(page, r"await\s+data\.load\(\)")


class LayoutChromeTests(unittest.TestCase):
    """Repo entry, base-path search, docs-bug link, and the breadcrumb."""

    def test_docs_layout_has_one_github_entry(self) -> None:
        """``githubUrl`` is the repo button; a second ``links`` entry duplicates it."""
        page = site_source("app/[[...slug]]/page.tsx")
        self.assertEqual(1, len(re.findall(r"githubUrl=\{REPO_URL\}", page)))
        self.assertNotIn("links={", page)
        self.assertNotIn("RepoIcon", page)
        site = site_source("lib/site.ts")
        self.assertIn('export const REPO_URL = "https://github.com/toxicoder/inkorporated"', site)
        self.assertIn('user: "toxicoder", repo: "inkorporated"', site)
        self.assertIn("export function repoFileUrl", site)
        wordmark = site_source("components/wordmark.tsx")
        self.assertIn("export function Wordmark", wordmark)
        self.assertNotIn("RepoIcon", wordmark)
        self.assertIn("{BRAND}", wordmark)

    def test_search_fetches_under_the_published_base_path(self) -> None:
        """The static client must not request host-root ``/api/search`` on project Pages."""
        site = site_source("lib/site.ts")
        self.assertRegex(site, r"export function searchIndexPath[\s\S]{0,400}\$\{base\}/api/search")
        self.assertRegex(site, r"export function basePath\(\)[\s\S]{0,600}REPO\.repo\}/\$\{alias\}")
        layout = site_source("app/layout.tsx")
        self.assertIn("searchIndexPath", layout)
        self.assertIn("searchFrom={searchIndexPath()}", layout)
        provider = site_source("components/provider.tsx")
        self.assertIn("SearchFromContext.Provider value={searchFrom}", provider)
        search_from = site_source("components/search-from.tsx")
        self.assertIn("export function useSearchFrom", search_from)
        self.assertIn('createContext("/api/search")', search_from)
        dialog = site_source("components/search-dialog.tsx")
        self.assertIn("const from = useSearchFrom()", dialog)
        self.assertIn("staticClient({ locale, from })", dialog)
        self.assertIn("staticClient({ from })", dialog)
        route = site_source("app/api/search/route.ts")
        self.assertIn('export const dynamic = "force-static"', route)
        self.assertIn("staticGET: GET", route)

    def test_published_paths_name_this_repo_not_the_donor_site(self) -> None:
        """The chrome documents ``/inkorporated/<alias>/``, where this repo publishes."""
        offenders: list[str] = []
        for rel in (
            "app/layout.tsx",
            "app/[[...slug]]/page.tsx",
            "components/provider.tsx",
            "components/search-from.tsx",
            "components/search-dialog.tsx",
            "lib/site.ts",
            "next.config.ts",
        ):
            for number, line in enumerate(site_source(rel).splitlines(), start=1):
                for donor in DONOR_PAGES_PATHS:
                    if donor in line:
                        offenders.append(f"docs-site/{rel}:{number}: {line.strip()[:90]}")
        self.assertEqual([], offenders, "comments still name the site this chrome was ported from")

    def test_heading_offers_a_docs_bug_link_beside_the_anchor_copy(self) -> None:
        """Each id'd heading offers a prefilled GitHub issue next to copy-anchor."""
        heading = site_source("components/docs-heading.tsx")
        self.assertIn('aria-label="File a documentation bug"', heading)
        self.assertIn('"Copy anchor link"', heading)
        self.assertIn('from "@/lib/docs-bug"', heading)
        self.assertIn("docsBugHref(", heading)
        bug = site_source("lib/docs-bug.ts")
        self.assertIn("export function docsBugHref", bug)
        self.assertIn("const ISSUE_NEW = `${REPO_URL}/issues/new`", bug)
        self.assertIn('labels: "documentation"', bug)
        page = site_source("app/[[...slug]]/page.tsx")
        self.assertIn("<DocsPageProvider", page)
        self.assertIn("docsAlias: docsAlias()", page)
        self.assertIn("sourcePath: `docs/${page.path}`", page)
        mdx = site_source("components/mdx-components.ts")
        self.assertIn("h2: DocsH2", mdx)

    def test_breadcrumb_names_the_section_the_page_lives_under(self) -> None:
        """The menu folds every section beside the reader's own, so the trail must name it."""
        page = site_source("app/[[...slug]]/page.tsx")
        self.assertIn("trailFor(page.path)", page)
        self.assertIn("<DocsTrail", page)
        self.assertIn("trail.label", page)
        trail = site_source("components/docs-trail.tsx")
        self.assertIn('aria-label="Breadcrumb"', trail)
        self.assertIn("trail.tab", trail)
        self.assertIn("trail.groups", trail)
        nav = site_source("lib/nav.ts")
        self.assertIn("export function trailFor", nav)
        self.assertIn("export interface NavTrail", nav)


class ThemeTests(unittest.TestCase):
    """The chrome carries this repo's indigo identity, not Material's or the donor's."""

    def test_primary_token_is_the_indigo_identity(self) -> None:
        """``--color-fd-primary`` is the indigo the retired ``mkdocs.yml`` declared."""
        css = site_source("app/global.css")
        self.assertIn(f"--color-fd-primary: {INDIGO_PRIMARY}", css)
        self.assertIn(f"--color-fd-ring: {INDIGO_PRIMARY}", css)
        self.assertIn(f"--color-fd-primary: {INDIGO_PRIMARY_DARK}", css)
        self.assertRegex(css, r"@theme\s*\{")
        self.assertIn(".dark {", css)
        self.assertRegex(css, re.compile(r"indigo", re.I))

    def test_no_material_or_donor_palette_survives(self) -> None:
        """No ``--md-`` Material variables and none of the donor brand's oranges."""
        css = site_source("app/global.css")
        self.assertNotIn("--md-", css)
        for hexcode in ("#c46e16", "#e89424"):
            self.assertNotIn(hexcode, css, f"donor-brand token {hexcode} left in the palette")

    def test_chrome_classes_the_components_use_are_defined(self) -> None:
        """The table and TOC-bar styles the components assign exist in the stylesheet."""
        css = site_source("app/global.css")
        for selector in (".ez-table-pin", ".ez-table-hscroll", ".ez-tocbar"):
            self.assertIn(selector, css)
        self.assertIn("ez-table-pin", site_source("components/table-chrome.tsx"))


def export_state() -> str:
    """Classify the static export in ``docs-site/out/``.

    ``out/`` is gitignored scratch output that ``next build`` and ``next typegen`` both
    write into, so its mere presence proves nothing: a typegen run leaves ``out/types/``
    behind with no page in it. Only a directory holding rendered HTML is an export to grade.

    Returns:
        ``"missing"`` when there is no ``out/``, ``"unbuilt"`` when it holds no rendered
        page, and ``"built"`` once the export has produced HTML.
    """
    if not EXPORT_DIR.is_dir():
        return "missing"
    if (EXPORT_DIR / "index.html").is_file() or any(EXPORT_DIR.rglob("*.html")):
        return "built"
    return "unbuilt"


class ExportTests(unittest.TestCase):
    """Optional checks against the built export in ``docs-site/out/``."""

    def _skip_if_unbuilt(self) -> None:
        """Skip the export checks with a printed note until an export exists."""
        state = export_state()
        if state == "missing":
            print("NOTE: docs-site/out/ is absent; skipping the export checks")
        elif state == "unbuilt":
            print("NOTE: docs-site/out/ holds no rendered page; skipping the export checks")
        else:
            return
        self.skipTest(f"docs-site/out/ has no export ({state})")

    @staticmethod
    def _sample() -> list[str]:
        """A representative set of pages: the home page, one page per section, two persona
        pages from the generated roster.

        Returns:
            Paths relative to ``docs/``.
        """
        sample = [HOME_PAGE]
        for tab in load_nav_tree():
            leaves = nav_pages_of(tab)
            if leaves:
                sample.append(str(leaves[0]["path"]))
        personas = [p for p in generated_nav_pages() if Path(p).name not in {"index.md", "index.mdx"}]
        sample.extend(personas[:2])
        return sorted(set(sample))

    def test_export_has_index_when_built(self) -> None:
        """If an export exists, the home page is there."""
        self._skip_if_unbuilt()
        self.assertTrue((EXPORT_DIR / "index.html").is_file(), "out/index.html missing from the export")

    def test_exported_pages_have_no_mkdocs_syntax(self) -> None:
        """Rendered pages show no leftover MkDocs markup."""
        self._skip_if_unbuilt()
        leftovers = (TOC_RE, GRID_CARDS_RE, SNIPPET_RE, INCLUDE_RE, TAB_LINE_RE)
        problems: list[str] = []
        for rel in self._sample():
            stem = rel[: rel.rfind(".")]
            html = EXPORT_DIR / stem / "index.html"
            if not html.is_file():
                problems.append(f"{rel}: no {html.relative_to(SITE_DIR)} in the export")
                continue
            text = html.read_text(encoding="utf-8", errors="replace")
            for pattern in leftovers:
                if pattern.search(text):
                    problems.append(f"{rel}: rendered page still carries {pattern.pattern}")
        self.assertEqual([], problems)


def main() -> int:
    """Run the suite.

    Returns:
        ``0`` when every test passed or skipped, ``1`` otherwise.
    """
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
