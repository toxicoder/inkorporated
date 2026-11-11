#!/usr/bin/env python3
"""Unit tests for the nav transcriber (docs-site/scripts/gen_nav.py).

Run: bazelisk test //docs-site:nav_test   (or, from docs-site/:
     python3 -m unittest -v test_gen_nav.py)

The transcriber turns the retired ``mkdocs.yml`` ``nav:`` block plus the ``docs/`` tree into
``docs-site/lib/nav.json``, which ``docs-site/lib/nav.ts`` reads as the single source of
truth for the sidebar (``buildPageTree`` throws when the tree names a page the content
collection does not hold). These tests pin the transcriber's own rules: how the nav block is
read, how unlisted pages are folded under the section that owns their directory, how titles
and order are chosen, what ``validate()`` refuses, and what ``main()`` writes.

The shape of the *built* tree - no root folders, sections open, groups collapsed, every
nav leaf resolving to a content page - is pinned on the TypeScript side by
``docs-site/tests/unit/nav.test.ts`` and is deliberately not repeated here.

Fixtures are throwaway checkouts under ``tempfile`` directories, with the generator's
module-level paths repointed at them by :class:`_point_at`. The only file any test writes
outside its temp dir is ``docs-site/lib/nav.json``: the repo-contract class regenerates it
with the generator's own ``main()`` in ``setUpClass``, so the contract keeps meaning after
the content migration renames pages from ``.md`` to ``.mdx``.
"""

from __future__ import annotations

import contextlib
import collections
import io
import json
import pathlib
import runpy
import sys
import tempfile
import unittest
from collections.abc import Iterator, Sequence

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "scripts"))

import gen_nav  # noqa: E402

GEN_NAV_SCRIPT = pathlib.Path(gen_nav.__file__).resolve()

#: Top-level directories this fixture folds into, taken from the generator's own table so a
#: fixture never invents a directory the generator would refuse.
FOLD_DIR = "guides"  # -> "Getting Started"
NEW_DIR = "training"  # -> "Training", listed in NEW_TAB_ORDER
OTHER_NEW_DIR = "onboarding"  # -> "Onboarding", listed first in NEW_TAB_ORDER
UNCLAIMED_DIR = "start"  # absent from DIRECTORY_TABS on purpose

TWO_TABS_NAV = """\
  - Home: index.md
  - Start:
      - Overview: start/index.md
      - Getting Started: getting-started.md
      - Subsection:
          - Deep: start/deep.md
  - Operate:
      - Overview: operate/index.md
"""

#: The pages ``TWO_TABS_NAV`` curates; a fixture that runs the folding or validation rules
#: has to have them on disk.
CURATED_PAGES = (
    "index.md",
    "start/index.md",
    "getting-started.md",
    "start/deep.md",
    "operate/index.md",
)


def mkdocs_yaml(nav_body: str) -> str:
    """Wrap a ``nav`` body in the other keys a real ``mkdocs.yml`` carries.

    The trailing ``plugins:`` key is what proves the transcriber stops reading at the next
    top-level key instead of swallowing the whole file.
    """
    return f"site_name: Inkorporated\nnav:\n{nav_body}plugins:\n  - search\n"


TWO_TABS = mkdocs_yaml(TWO_TABS_NAV)

INDENTED_TABS = mkdocs_yaml("    - Home: index.md\n    - Guide:\n        - Intro: guide/index.md\n")


def _write_pages(root: pathlib.Path, pages: Sequence[str], texts: dict[str, str] | None = None) -> None:
    """Lay out ``<root>/docs`` with ``pages``, creating any folder between.

    ``texts`` overrides the body of a named page; the default body carries no frontmatter, so
    a folded page title falls back to its file stem unless a test authors a ``title:``.
    """
    bodies = texts or {}
    for relative in pages:
        page = root / "docs" / relative
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text(bodies.get(relative, f"# {page.stem}\n"), encoding="utf-8")


def _checkout(
    root: pathlib.Path,
    *,
    pages: Sequence[str] = (),
    texts: dict[str, str] | None = None,
    mkdocs_text: str | None = None,
    nav_json: object | None = None,
) -> pathlib.Path:
    """Build a minimal checkout: a ``docs/`` tree, an optional ``mkdocs.yml``, a nav.json.

    Returns:
        The root, so a caller can keep writing into the fixture.
    """
    (root / "docs").mkdir(parents=True, exist_ok=True)
    _write_pages(root, pages, texts)
    if mkdocs_text is not None:
        (root / "mkdocs.yml").write_text(mkdocs_text, encoding="utf-8")
    if nav_json is not None:
        out = root / "docs-site" / "lib" / "nav.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(nav_json, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return root


def _run_main(root: pathlib.Path, argv: list[str]) -> tuple[int, str, str]:
    """Run ``main()`` over a fixture checkout and hand back its code plus what it printed."""
    out, err = io.StringIO(), io.StringIO()
    with _point_at(root), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = gen_nav.main(argv)
    return code, out.getvalue(), err.getvalue()


def _titles(nodes: object) -> list[str]:
    """Titles of the direct children of a tab or a folder, in order."""
    return [str(node["title"]) for node in nodes]  # type: ignore[index]


class ParseNavTests(unittest.TestCase):
    """Tab, page, and nested-group entries are read out of the nav block."""

    def test_tabs_and_pages_are_parsed_in_order(self) -> None:
        tabs = gen_nav.parse_nav(TWO_TABS)
        self.assertEqual(["Home", "Start", "Operate"], [tab["title"] for tab in tabs])
        self.assertEqual(["index.md"], [p["path"] for p in tabs[0]["pages"]])
        self.assertEqual(
            ["start/index.md", "getting-started.md", "start/deep.md"],
            [p["path"] for p in tabs[1]["pages"]],
        )

    def test_leaf_titles_are_preserved_verbatim(self) -> None:
        tabs = gen_nav.parse_nav(TWO_TABS)
        self.assertEqual("Getting Started", tabs[1]["pages"][1]["title"])
        self.assertEqual(["Overview", "Getting Started", "Deep"], _titles(tabs[1]["pages"]))

    def test_a_bare_page_tab_holds_its_own_page(self) -> None:
        """``- Home: index.md`` is one tab whose single leaf is that page."""
        tabs = gen_nav.parse_nav(TWO_TABS)
        self.assertEqual([{"title": "Home", "path": "index.md"}], tabs[0]["pages"])

    def test_nested_group_leaves_stay_in_their_tab(self) -> None:
        """A group inside a tab is a sidebar heading, not a new section."""
        tabs = gen_nav.parse_nav(TWO_TABS)
        self.assertEqual(3, len(tabs[1]["pages"]))
        self.assertEqual(["operate/index.md"], [p["path"] for p in tabs[2]["pages"]])

    def test_siblings_indented_like_tabs_are_read_as_tabs(self) -> None:
        """Nesting comes from the bullet column, so a deeper file style still parses."""
        tabs = gen_nav.parse_nav(INDENTED_TABS)
        self.assertEqual(["Home", "Guide"], [tab["title"] for tab in tabs])
        self.assertEqual(["guide/index.md"], [p["path"] for p in tabs[1]["pages"]])

    def test_nav_block_stops_at_the_next_top_level_key(self) -> None:
        tabs = gen_nav.parse_nav(TWO_TABS)
        self.assertNotIn("search", json.dumps(tabs))

    def test_comment_lines_inside_the_nav_are_ignored(self) -> None:
        body = "  # a comment at column two\n  - Home: index.md\n# a comment at column zero\n"
        tabs = gen_nav.parse_nav(mkdocs_yaml(body))
        self.assertEqual(["Home"], [tab["title"] for tab in tabs])

    def test_missing_nav_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, "no top-level nav:"):
            gen_nav.parse_nav("site_name: x\n")

    def test_empty_nav_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, "nav is empty"):
            gen_nav.parse_nav("nav:\nplugins: []\n")

    def test_unparsable_line_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, "unparsed nav line"):
            gen_nav.parse_nav("nav:\n  - just text\n")

    def test_leaf_before_any_tab_raises(self) -> None:
        """A page listed outside a tab has no sidebar to land in, so it is refused.

        The bullet sits deeper than the tab bullet that follows it, so it cannot belong to
        any group.
        """
        with self.assertRaisesRegex(ValueError, "before any tab"):
            gen_nav.parse_nav("nav:\n    - Orphan: orphan.md\n  - Start:\n      - Deep: deep.md\n")

    def test_curated_leaves_are_named_by_their_markdown_path(self) -> None:
        """The curated block names ``.md`` pages only; an ``.mdx`` leaf is not a nav line.

        The block was transcribed from MkDocs, which never knew ``.mdx``, and the coverage
        rule matches a renamed page through ``validate()`` rather than by editing the block.
        """
        with self.assertRaisesRegex(ValueError, "unparsed nav line"):
            gen_nav.parse_nav("nav:\n  - Home: index.mdx\n")


class NavBlockTests(unittest.TestCase):
    """``_nav_block`` slices the list out and ``_dash_column`` measures a bullet."""

    def test_nav_block_returns_only_the_nav_list(self) -> None:
        lines = gen_nav._nav_block(TWO_TABS.split("\n"))
        self.assertNotIn("nav:", lines)
        joined = "\n".join(lines)
        self.assertIn("- Deep: start/deep.md", joined)
        self.assertNotIn("plugins:", joined)
        self.assertNotIn("site_name", joined)

    def test_nav_block_without_a_nav_key_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, "no top-level nav:"):
            gen_nav._nav_block(["site_name: x", "theme: readthedocs"])

    def test_nav_block_keeps_a_column_zero_comment(self) -> None:
        """A comment at column zero belongs to the nav and must not end the block."""
        lines = gen_nav._nav_block(["nav:", "# note", "  - Home: index.md", "plugins: []"])
        self.assertEqual(["# note", "  - Home: index.md"], lines)

    def test_dash_column_reports_the_bullet_column(self) -> None:
        cases = {
            "- Home: index.md": 0,
            "  - Home: index.md": 2,
            "\t- Home: index.md": 1,
            "      - Deep: start/deep.md": 6,
        }
        for line, column in cases.items():
            with self.subTest(line=line):
                self.assertEqual(column, gen_nav._dash_column(line))


class FlattenPagesTests(unittest.TestCase):
    """The leaf walk reaches every depth and tolerates the shapes JSON can hold."""

    NESTED: list[dict[str, object]] = [
        {"title": "Home", "pages": [{"title": "Home", "path": "index.md"}]},
        {
            "title": "Operate",
            "pages": [
                {"title": "Daily", "path": "operate/daily.md"},
                {
                    "title": "Troubleshooting",
                    "pages": [
                        {"title": "Home", "path": "troubleshooting.md"},
                        {"title": "Deeper", "pages": [{"title": "Deep", "path": "deep.md"}]},
                    ],
                },
            ],
        },
    ]

    def test_nested_leaves_flatten_in_reader_order(self) -> None:
        """Group children keep their position and order; groups themselves are not pages."""
        paths = [page["path"] for page in gen_nav.flatten_pages(self.NESTED)]
        self.assertEqual(["index.md", "operate/daily.md", "troubleshooting.md", "deep.md"], paths)

    def test_a_leaf_keeps_its_title(self) -> None:
        self.assertEqual(
            {"title": "Daily", "path": "operate/daily.md"}, gen_nav.flatten_pages(self.NESTED)[1]
        )

    def test_a_bare_mapping_is_read_as_one_node(self) -> None:
        """A caller may hand the walk one leaf or one folder instead of a sequence."""
        self.assertEqual(
            [{"title": "Home", "path": "index.md"}],
            gen_nav.flatten_pages({"title": "Home", "path": "index.md"}),
        )

    def test_a_folder_whose_pages_is_a_bare_mapping_yields_its_leaf(self) -> None:
        tree: list[dict[str, object]] = [
            {"title": "Operate", "pages": {"title": "Daily", "path": "operate/daily.md"}}
        ]
        self.assertEqual(
            [{"title": "Daily", "path": "operate/daily.md"}], gen_nav.flatten_pages(tree)
        )

    def test_a_folder_without_pages_contributes_no_leaves(self) -> None:
        """An emptied folder is not read as a page whose path went missing."""
        tree: list[dict[str, object]] = [
            {
                "title": "Operate",
                "pages": [
                    {"title": "Daily", "path": "nope/daily.md"},
                    {"title": "Troubleshooting"},
                ],
            }
        ]
        self.assertEqual([{"title": "Daily", "path": "nope/daily.md"}], gen_nav.flatten_pages(tree))

    def test_a_scalar_among_the_entries_is_skipped(self) -> None:
        """A string or number slipped into the list has no leaf to give."""
        tree: list[object] = ["Home", {"title": "Home", "path": "index.md"}, None, 4]
        self.assertEqual([{"title": "Home", "path": "index.md"}], gen_nav.flatten_pages(tree))

    def test_a_tree_that_is_not_a_sequence_yields_no_leaves(self) -> None:
        for nodes in (None, "", 4, True, 3.5):
            with self.subTest(nodes=nodes):
                self.assertEqual([], gen_nav.flatten_pages(nodes))


class PrettifyTests(unittest.TestCase):
    """Folder titles read as words, not as directory names."""

    def test_separators_become_spaces_and_words_are_title_cased(self) -> None:
        self.assertEqual(
            "Specialized Squads Cross Functional Teams",
            gen_nav.prettify("specialized_squads_cross_functional_teams"),
        )
        self.assertEqual("By Namespace", gen_nav.prettify("by-namespace"))

    def test_surrounding_separators_and_space_are_dropped(self) -> None:
        self.assertEqual("Data", gen_nav.prettify("  _data_ "))

    def test_a_plain_word_is_only_title_cased(self) -> None:
        self.assertEqual("Setup", gen_nav.prettify("setup"))


class GroupTitleTests(unittest.TestCase):
    """A folded folder reads under the words the old site used, when it can."""

    def test_a_curated_markdown_index_titles_the_folder(self) -> None:
        curated = {"job_roles/executive_leadership/index.md": "Executive leadership"}
        self.assertEqual(
            "Executive leadership",
            gen_nav._group_title("job_roles/executive_leadership", curated),
        )

    def test_a_curated_mdx_index_titles_the_folder_too(self) -> None:
        """A migrated folder still wears its authored label."""
        curated = {"cyborgs/generated/index.mdx": "Cyborg roster"}
        self.assertEqual("Cyborg roster", gen_nav._group_title("cyborgs/generated", curated))

    def test_the_curated_index_of_another_suffix_does_not_leak(self) -> None:
        curated = {"guides/setup/other.md": "Not The Index"}
        self.assertEqual("Setup", gen_nav._group_title("guides/setup", curated))

    def test_the_last_segment_is_prettified_without_a_curated_index(self) -> None:
        self.assertEqual("Setup", gen_nav._group_title("guides/setup", {}))
        self.assertEqual("Guides", gen_nav._group_title("guides", {}))


class LeafTitleTests(unittest.TestCase):
    """A folded page is labelled from its own frontmatter title."""

    def test_the_frontmatter_title_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(
                root,
                pages=["guides/one.md"],
                texts={"guides/one.md": "---\ntitle:   One Page  \ntags: [a]\n---\n# One\n"},
            )
            with _point_at(root):
                self.assertEqual("One Page", gen_nav._leaf_title("guides/one.md", {}))

    def test_quotes_around_the_frontmatter_title_are_dropped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(
                root,
                pages=["guides/one.md"],
                texts={"guides/one.md": '---\ntitle: "Quoted Title"\n---\n'},
            )
            with _point_at(root):
                self.assertEqual("Quoted Title", gen_nav._leaf_title("guides/one.md", {}))

    def test_the_curated_title_beats_the_frontmatter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(root, pages=["guides/one.md"], texts={"guides/one.md": "---\ntitle: Front\n---\n"})
            with _point_at(root):
                self.assertEqual("Authored", gen_nav._leaf_title("guides/one.md", {"guides/one.md": "Authored"}))

    def test_a_page_without_a_title_falls_back_to_its_stem(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(
                root,
                pages=["guides/deep_page.md", "guides/no_title.md"],
                texts={"guides/no_title.md": "---\ndescription: nothing here\n---\n# No title\n"},
            )
            with _point_at(root):
                self.assertEqual("deep_page", gen_nav._leaf_title("guides/deep_page.md", {}))
                self.assertEqual("no_title", gen_nav._leaf_title("guides/no_title.md", {}))

    def test_a_page_that_vanished_falls_back_to_its_stem(self) -> None:
        """``discover_pages`` only returns real files, but the walk must not raise anyway."""
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(root)
            with _point_at(root):
                self.assertEqual("gone", gen_nav._leaf_title("guides/gone.md", {}))


class SortKeyTests(unittest.TestCase):
    """Inside a folder the directory's own index comes first, then names."""

    def test_the_index_sorts_before_every_other_name(self) -> None:
        paths = ["guides/b.md", "guides/index.md", "guides/a.md", "guides/index_notes.md"]
        self.assertEqual(
            ["guides/index.md", "guides/a.md", "guides/b.md", "guides/index_notes.md"],
            sorted(paths, key=gen_nav._sort_key),
        )

    def test_a_migrated_index_sorts_first_too(self) -> None:
        self.assertEqual(
            ["guides/index.mdx", "guides/a.md"],
            sorted(["guides/a.md", "guides/index.mdx"], key=gen_nav._sort_key),
        )

    def test_the_key_pair_is_rank_then_file_name(self) -> None:
        self.assertEqual((0, "index.md"), gen_nav._sort_key("deep/here/index.md"))
        self.assertEqual((1, "a.md"), gen_nav._sort_key("deep/here/a.md"))


class IsCollectionPageTests(unittest.TestCase):
    """The page rule mirrors the collection globs in ``docs-site/source.config.ts``."""

    def test_the_exclude_lists_are_the_documented_ones(self) -> None:
        self.assertEqual({"includes", "_data", "assets", "__pycache__"}, set(gen_nav.EXCLUDED_DIRS))
        self.assertEqual(
            {"README.md", "BUILD.bazel", "requirements.txt", "Gemfile"}, set(gen_nav.EXCLUDED_NAMES)
        )
        self.assertEqual({".md", ".mdx"}, set(gen_nav.COLLECTION_SUFFIXES))

    def test_markdown_and_mdx_are_pages(self) -> None:
        for path in ("index.md", "index.mdx", "guides/one.md", "cyborgs/generated/index.mdx"):
            with self.subTest(path=path):
                self.assertTrue(gen_nav.is_collection_page(pathlib.PurePosixPath(path)))

    def test_content_directories_are_excluded_anywhere_in_the_path(self) -> None:
        for directory in sorted(gen_nav.EXCLUDED_DIRS):
            with self.subTest(directory=directory):
                self.assertFalse(gen_nav.is_collection_page(pathlib.PurePosixPath(f"{directory}/x.md")))
                self.assertFalse(
                    gen_nav.is_collection_page(pathlib.PurePosixPath(f"guides/{directory}/x.mdx"))
                )

    def test_the_excluded_names_are_excluded_anywhere_in_the_path(self) -> None:
        for name in sorted(gen_nav.EXCLUDED_NAMES):
            with self.subTest(name=name):
                self.assertFalse(gen_nav.is_collection_page(pathlib.PurePosixPath(name)))
                self.assertFalse(gen_nav.is_collection_page(pathlib.PurePosixPath(f"guides/{name}")))

    def test_suffixes_the_site_does_not_compile_are_not_pages(self) -> None:
        for name in ("notes.json", "build.sh", "tool.py", "notes.txt", "logo.png", "LICENSE"):
            with self.subTest(name=name):
                self.assertFalse(gen_nav.is_collection_page(pathlib.PurePosixPath(f"guides/{name}")))


class DiscoverPagesTests(unittest.TestCase):
    """``discover_pages`` is the coverage rule's view of the tree."""

    def test_it_lists_collection_pages_sorted_and_posix(self) -> None:
        pages = [
            "index.md",
            "guides/b.md",
            "guides/a.md",
            "guides/setup/index.mdx",
            "deep/nested/page.mdx",
        ]
        noise = [
            "includes/note.md",
            "_data/tpl.md",
            "assets/pic.md",
            "__pycache__/cached.md",
            "guides/__pycache__/x.md",
            "README.md",
            "BUILD.bazel",
            "requirements.txt",
            "Gemfile",
            "notes.json",
            "build.sh",
            "tool.py",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(root, pages=[*pages, *noise])
            with _point_at(root):
                self.assertEqual(sorted(pages), gen_nav.discover_pages())

    def test_it_returns_nothing_without_a_docs_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp) / "missing"
            with _point_at(root):
                self.assertEqual([], gen_nav.discover_pages())

    def test_a_directory_named_like_a_page_is_not_a_page(self) -> None:
        """``rglob`` returns folders too; only files are collected."""
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _checkout(root, pages=["index.md"])
            (root / "docs" / "not-a-page.md").mkdir()
            with _point_at(root):
                self.assertEqual(["index.md"], gen_nav.discover_pages())


class FoldUnlistedTests(unittest.TestCase):
    """Every page the curated block omits lands under the section that owns its directory."""

    def _fold(self, root: pathlib.Path, mkdocs_text: str) -> list[dict[str, object]]:
        with _point_at(root):
            return gen_nav.fold_unlisted(gen_nav.parse_nav(mkdocs_text))

    def test_curated_leaves_come_first_then_one_folder_per_directory(self) -> None:
        """The section front door is what the block authored; folders are appended below."""
        body = f"  - Getting Started:\n      - Handbook: {FOLD_DIR}/handbook.md\n  - Home: index.md\n"
        text = mkdocs_yaml(body)
        pages = [
            "index.md",
            f"{FOLD_DIR}/handbook.md",
            f"{FOLD_DIR}/two.md",
            f"{FOLD_DIR}/one.md",
            f"{FOLD_DIR}/setup/index.md",
            f"{FOLD_DIR}/setup/alpha.md",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=pages, mkdocs_text=text)
            tabs = self._fold(root, text)
            self.assertEqual(["Getting Started", "Home"], [str(tab["title"]) for tab in tabs])
            by_title = {str(tab["title"]): tab for tab in tabs}
            folded = by_title["Getting Started"]["pages"]
            self.assertEqual(["Handbook", "Guides", "Setup"], _titles(folded))
            self.assertEqual(
                [f"{FOLD_DIR}/one.md", f"{FOLD_DIR}/two.md"],
                [page["path"] for page in folded[1]["pages"]],
            )
            self.assertEqual(
                [f"{FOLD_DIR}/setup/index.md", f"{FOLD_DIR}/setup/alpha.md"],
                [page["path"] for page in folded[2]["pages"]],
            )
            self.assertEqual(["index", "alpha"], _titles(folded[2]["pages"]))

    def test_curated_leaves_keep_their_authored_order(self) -> None:
        """Folding appends; it never re-sorts the pages a human put in the block."""
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[*CURATED_PAGES, "about.md"], mkdocs_text=TWO_TABS)
            tabs = self._fold(root, TWO_TABS)
            by_title = {str(tab["title"]): tab for tab in tabs}
            self.assertEqual(
                ["start/index.md", "getting-started.md", "start/deep.md"],
                [page["path"] for page in by_title["Start"]["pages"]],
            )
            self.assertEqual(["index.md"], [page["path"] for page in by_title["Home"]["pages"]])

    def test_root_level_unlisted_pages_land_in_the_contributing_tab(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp), pages=[*CURATED_PAGES, "about.md", "notes.md"], mkdocs_text=TWO_TABS
            )
            tabs = self._fold(root, TWO_TABS)
            by_title = {str(tab["title"]): tab for tab in tabs}
            self.assertEqual(["about.md", "notes.md"], [p["path"] for p in by_title["Contributing"]["pages"]])
            self.assertEqual(["about", "notes"], _titles(by_title["Contributing"]["pages"]))

    def test_an_unlisted_home_page_opens_its_own_home_tab(self) -> None:
        """``index.md`` the block never named cannot be left without a section."""
        body = "  - Start:\n      - Overview: start/index.md\n"
        text = mkdocs_yaml(body)
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md", "start/index.md"], mkdocs_text=text)
            tabs = self._fold(root, text)
            self.assertEqual(["Start", "Home"], [str(tab["title"]) for tab in tabs])
            self.assertEqual(["index.md"], [p["path"] for p in tabs[1]["pages"]])

    def test_a_new_section_is_created_for_a_known_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp), pages=[*CURATED_PAGES, f"{NEW_DIR}/day-one.md"], mkdocs_text=TWO_TABS
            )
            tabs = self._fold(root, TWO_TABS)
            by_title = {str(tab["title"]): tab for tab in tabs}
            self.assertEqual(
                ["Home", "Start", "Operate", "Training"], [str(tab["title"]) for tab in tabs]
            )
            folders = by_title["Training"]["pages"]
            self.assertEqual([NEW_DIR.title()], _titles(folders))
            self.assertEqual([f"{NEW_DIR}/day-one.md"], [p["path"] for p in folders[0]["pages"]])

    def test_a_directory_no_section_claims_is_an_error_not_a_silent_drop(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp),
                pages=[*CURATED_PAGES, f"{UNCLAIMED_DIR}/orphan.md"],
                mkdocs_text=TWO_TABS,
            )
            with _point_at(root):
                with self.assertRaises(ValueError) as raised:
                    gen_nav.fold_unlisted(gen_nav.parse_nav(TWO_TABS))
        message = str(raised.exception)
        self.assertIn(f"{UNCLAIMED_DIR}/orphan.md", message)
        self.assertIn("DIRECTORY_TABS", message)

    def test_a_folder_title_comes_from_its_curated_index(self) -> None:
        """A directory the block labels through its index keeps those words when folded."""
        body = (
            "  - Home: index.md\n"
            "  - Reference:\n"
            f"      - Handbook: {FOLD_DIR}/setup/index.md\n"
        )
        text = mkdocs_yaml(body)
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp),
                pages=[f"{FOLD_DIR}/setup/index.md", f"{FOLD_DIR}/setup/alpha.md", "index.md"],
                mkdocs_text=text,
            )
            tabs = self._fold(root, text)
            by_title = {str(tab["title"]): tab for tab in tabs}
            folders = by_title["Getting Started"]["pages"]
            self.assertEqual(["Handbook"], _titles(folders))
            self.assertEqual([f"{FOLD_DIR}/setup/alpha.md"], [p["path"] for p in folders[0]["pages"]])

    def test_every_page_appears_exactly_once(self) -> None:
        pages = [
            *CURATED_PAGES,
            f"{FOLD_DIR}/one.md",
            f"{FOLD_DIR}/setup/index.md",
            "about.md",
            f"{NEW_DIR}/day-one.md",
            f"{OTHER_NEW_DIR}/index.md",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=pages, mkdocs_text=TWO_TABS)
            tabs = self._fold(root, TWO_TABS)
            listed = [page["path"] for page in gen_nav.flatten_pages(tabs)]
            self.assertEqual(sorted(pages), sorted(listed))
            counts = collections.Counter(listed)
            self.assertEqual([], [path for path, count in counts.items() if count > 1])

    def test_folding_is_idempotent(self) -> None:
        pages = [*CURATED_PAGES, f"{FOLD_DIR}/one.md", "about.md", f"{NEW_DIR}/day-one.md"]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=pages, mkdocs_text=TWO_TABS)
            with _point_at(root):
                once = gen_nav.fold_unlisted(gen_nav.parse_nav(TWO_TABS))
                twice = gen_nav.fold_unlisted(once)
            self.assertEqual(once, twice)

    def test_the_curated_tree_is_not_mutated(self) -> None:
        tabs = gen_nav.parse_nav(TWO_TABS)
        before = json.dumps(tabs)
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[*CURATED_PAGES, f"{FOLD_DIR}/one.md"])
            with _point_at(root):
                gen_nav.fold_unlisted(tabs)
        self.assertEqual(before, json.dumps(tabs))

    def test_a_renamed_curated_page_is_not_folded_a_second_time(self) -> None:
        """A curated page renamed to ``.mdx`` stays one row: ``claimed`` compares identities.

        The curated block names pages by the ``.md`` path MkDocs used. Once the content
        migration renames that page to ``.mdx``, the on-disk path no longer equals the
        curated one, so :func:`gen_nav.fold_unlisted` must still recognise it as claimed:
        :func:`docs_site.lib.nav.ts` matches a nav entry against the collection with the
        extension stripped, so two rows would put the same content page in the sidebar
        twice. :func:`gen_nav.validate` keys its duplicate count the same way, so the
        module's rule that "a page that is listed twice fails the run" fires.
        """
        text = mkdocs_yaml(f"  - Getting Started:\n      - Renamed: {FOLD_DIR}/renamed.md\n")
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[f"{FOLD_DIR}/renamed.mdx"], mkdocs_text=text)
            with _point_at(root):
                tabs = gen_nav.fold_unlisted(gen_nav.parse_nav(text))
                listed = [page["path"] for page in gen_nav.flatten_pages(tabs)]
                on_disk = gen_nav.discover_pages()
            self.assertEqual([f"{FOLD_DIR}/renamed.md"], listed)
            self.assertEqual(len(on_disk), len(listed), "one row per page on disk")


class OrderNewTabsTests(unittest.TestCase):
    """Sections that exist only because a directory folded in are appended, in order."""

    @staticmethod
    def _tab(title: str) -> dict[str, object]:
        return {"title": title, "pages": []}

    def test_new_tabs_are_appended_in_the_declared_order(self) -> None:
        tabs = [
            self._tab("Training"),
            self._tab("Home"),
            self._tab("Onboarding"),
            self._tab("Zeta"),
            self._tab("Getting Started"),
        ]
        ordered = gen_nav._order_new_tabs(tabs, {"Home", "Getting Started"})
        self.assertEqual(
            ["Home", "Getting Started", "Onboarding", "Training", "Zeta"],
            [str(tab["title"]) for tab in ordered],
        )

    def test_curated_sections_keep_their_authored_position(self) -> None:
        """A curated section is never moved, even when its name is in ``NEW_TAB_ORDER``."""
        tabs = [self._tab("Training"), self._tab("Home"), self._tab("Playbooks")]
        ordered = gen_nav._order_new_tabs(tabs, {"Training", "Home"})
        self.assertEqual(["Training", "Home", "Playbooks"], [str(tab["title"]) for tab in ordered])

    def test_unlisted_new_sections_sort_by_title_after_the_known_ones(self) -> None:
        tabs = [self._tab("Zeta"), self._tab("Alpha"), self._tab("Onboarding"), self._tab("Beta")]
        ordered = gen_nav._order_new_tabs(tabs, set())
        self.assertEqual(["Onboarding", "Alpha", "Beta", "Zeta"], [str(tab["title"]) for tab in ordered])

    def test_the_ordering_is_stable_against_filesystem_enumeration(self) -> None:
        pages = [*CURATED_PAGES, f"{NEW_DIR}/day-one.md", f"{OTHER_NEW_DIR}/index.md"]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=pages, mkdocs_text=TWO_TABS)
            with _point_at(root):
                tabs = gen_nav.fold_unlisted(gen_nav.parse_nav(TWO_TABS))
        self.assertEqual(
            ["Home", "Start", "Operate", "Onboarding", "Training"],
            [str(tab["title"]) for tab in tabs],
        )


class ValidateTests(unittest.TestCase):
    """The validator is what keeps the tree and the files on disk in step."""

    def _validate(self, root: pathlib.Path, tabs: list[dict[str, object]]) -> list[str]:
        with _point_at(root):
            return gen_nav.validate(tabs)

    def test_a_consistent_nav_reports_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md", "guides/one.md"])
            tabs = [
                {
                    "title": "Home",
                    "pages": [
                        {"title": "Home", "path": "index.md"},
                        {"title": "One", "path": "guides/one.md"},
                    ],
                }
            ]
            self.assertEqual([], self._validate(root, tabs))

    def test_a_nav_page_missing_on_disk_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[])
            tabs = [{"title": "T", "pages": [{"title": "x", "path": "definitely-not-here.md"}]}]
            self.assertEqual(
                ["nav page missing on disk: docs/definitely-not-here.md"], self._validate(root, tabs)
            )

    def test_a_page_listed_twice_is_reported(self) -> None:
        page = {"title": "x", "path": "index.md"}
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"])
            tabs = [{"title": "A", "pages": [page]}, {"title": "B", "pages": [dict(page)]}]
            self.assertEqual(
                ["nav page listed 2 times: docs/index.md"], self._validate(root, tabs)
            )

    def test_a_page_listed_twice_across_groups_is_reported(self) -> None:
        tree = [
            {
                "title": "Operate",
                "pages": [
                    {"title": "A", "path": "index.md"},
                    {"title": "Group", "pages": [{"title": "B", "path": "index.md"}]},
                ],
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"])
            self.assertEqual(["nav page listed 2 times: docs/index.md"], self._validate(root, tree))

    def test_an_on_disk_page_listed_nowhere_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md", "guides/orphan.md"])
            tabs = [{"title": "Home", "pages": [{"title": "Home", "path": "index.md"}]}]
            self.assertEqual(
                ["page missing from the nav: docs/guides/orphan.md"], self._validate(root, tabs)
            )

    def test_a_page_missing_inside_a_group_is_reported(self) -> None:
        """A leaf buried in a folder is still checked against the tree on disk."""
        tree = [
            {
                "title": "Operate",
                "pages": [
                    {"title": "Daily", "path": "index.md"},
                    {"title": "Troubleshooting", "pages": [{"title": "Deep", "path": "deep.md"}]},
                ],
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"])
            self.assertEqual(["nav page missing on disk: docs/deep.md"], self._validate(root, tree))

    def test_a_curated_page_renamed_to_mdx_is_not_called_missing(self) -> None:
        """A curated ``.md`` entry covers the ``.mdx`` file the migration left behind.

        A page's identity is its path with the collection suffix removed - that is how
        ``docs-site/lib/nav.ts`` matches a nav entry against the content source - so the
        curated row and the renamed file are the same page: neither missing, and no
        second row for it.
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["guides/renamed.mdx"])
            tabs = [{"title": "T", "pages": [{"title": "Renamed", "path": "guides/renamed.md"}]}]
            self.assertEqual([], self._validate(root, tabs))

    def test_the_missing_page_report_is_capped(self) -> None:
        """Forty rows then a count, so a bad merge does not bury the terminal."""
        pages = ["index.md"] + [f"guides/p{n:03d}.md" for n in range(45)]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=pages)
            tabs = [{"title": "Home", "pages": [{"title": "Home", "path": "index.md"}]}]
            problems = self._validate(root, tabs)
        self.assertEqual(41, len(problems))
        self.assertTrue(all(p.startswith("page missing from the nav: ") for p in problems[:-1]))
        self.assertIn("and 5 more pages missing from the nav", problems[-1])


class BuildTreeTests(unittest.TestCase):
    """``build_tree`` transcribes from ``mkdocs.yml`` while it exists, then from nav.json."""

    def test_it_transcribes_the_curated_block_and_folds_the_rest(self) -> None:
        pages = [*CURATED_PAGES, f"{FOLD_DIR}/one.md"]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp),
                pages=pages,
                mkdocs_text=TWO_TABS,
                nav_json=[{"title": "Stale", "pages": [{"title": "S", "path": "index.md"}]}],
            )
            with _point_at(root):
                tabs = gen_nav.build_tree()
        self.assertEqual(["Home", "Start", "Operate", "Getting Started"], [str(t["title"]) for t in tabs])
        self.assertNotIn("Stale", [str(tab["title"]) for tab in tabs])
        self.assertEqual(sorted(pages), sorted(p["path"] for p in gen_nav.flatten_pages(tabs)))

    def test_it_falls_back_to_the_committed_nav_json_without_mkdocs(self) -> None:
        committed = [
            {
                "title": "Home",
                "pages": [
                    {"title": "Home", "path": "index.md"},
                    {"title": "Folder", "pages": [{"title": "One", "path": "guides/one.md"}]},
                ],
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md", "guides/one.md"], nav_json=committed)
            self.assertFalse((root / "mkdocs.yml").exists())
            with _point_at(root):
                tabs = gen_nav.build_tree()
        self.assertEqual(["Home"], [str(tab["title"]) for tab in tabs])
        self.assertEqual(
            [{"title": "Home", "path": "index.md"}, {"title": "One", "path": "guides/one.md"}],
            gen_nav.flatten_pages(tabs),
        )

    def test_it_folds_a_new_page_into_the_committed_tree(self) -> None:
        """A page added after the last generation reaches the menu without a hand edit."""
        committed = [{"title": "Home", "pages": [{"title": "Home", "path": "index.md"}]}]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(
                pathlib.Path(tmp), pages=["index.md", f"{FOLD_DIR}/newcomer.md"], nav_json=committed
            )
            with _point_at(root):
                tabs = gen_nav.build_tree()
        self.assertEqual(
            ["index.md", f"{FOLD_DIR}/newcomer.md"],
            [page["path"] for page in gen_nav.flatten_pages(tabs)],
        )

    def test_it_raises_when_neither_source_exists(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"])
            with _point_at(root):
                with self.assertRaises(FileNotFoundError) as raised:
                    gen_nav.build_tree()
        self.assertIn("nav.json", str(raised.exception))
        self.assertIn("mkdocs.yml", str(raised.exception))


class MainCliTests(unittest.TestCase):
    """``main()`` is what Bazel and the docs scripts call, so its modes are contract."""

    def test_writes_nav_json_and_reports_the_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[*CURATED_PAGES, f"{FOLD_DIR}/one.md"], mkdocs_text=TWO_TABS)
            code, out, err = _run_main(root, [])
            self.assertEqual(0, code, err)
            written = json.loads((root / "docs-site" / "lib" / "nav.json").read_text(encoding="utf-8"))
            self.assertEqual(["Home", "Start", "Operate", "Getting Started"], [t["title"] for t in written])
            self.assertIn("wrote docs-site/lib/nav.json", out)
            self.assertIn("4 tabs, 6 pages", out)

    def test_print_mode_writes_stdout_only(self) -> None:
        """``--print`` feeds the pipeline without touching the working tree."""
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=CURATED_PAGES, mkdocs_text=TWO_TABS)
            code, out, err = _run_main(root, ["--print"])
            self.assertEqual(0, code, err)
            self.assertEqual(["Home", "Start", "Operate"], [t["title"] for t in json.loads(out)])
            self.assertFalse((root / "docs-site" / "lib" / "nav.json").exists())

    def test_check_accepts_an_up_to_date_nav_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=CURATED_PAGES, mkdocs_text=TWO_TABS)
            self.assertEqual(0, _run_main(root, [])[0])
            code, out, err = _run_main(root, ["--check"])
            self.assertEqual(0, code, err)
            self.assertIn("up to date", out)

    def test_check_reports_a_stale_nav_json(self) -> None:
        """A committed file that no longer matches the tree fails instead of riding along."""
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=CURATED_PAGES, mkdocs_text=TWO_TABS)
            (root / "docs-site" / "lib").mkdir(parents=True)
            (root / "docs-site" / "lib" / "nav.json").write_text("[]\n", encoding="utf-8")
            code, out, err = _run_main(root, ["--check"])
            self.assertEqual(1, code)
            self.assertIn("stale", err)
            self.assertIn("gen_nav.py", err)

    def test_check_validates_against_disk_once_mkdocs_is_gone(self) -> None:
        """After the retirement ``--check`` guards nav.json against the files on disk."""
        committed = [{"title": "Home", "pages": [{"title": "Home", "path": "index.md"}]}]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"], nav_json=committed)
            code, out, err = _run_main(root, ["--check"])
            self.assertEqual(0, code, err)
            self.assertIn("up to date", out)

    def test_check_fails_when_a_nav_page_went_missing(self) -> None:
        """A nav entry that no longer has a page on disk is still caught."""
        committed = [{"title": "Home", "pages": [{"title": "Gone", "path": "gone.md"}]}]
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=[], nav_json=committed)
            code, _, err = _run_main(root, ["--check"])
            self.assertEqual(1, code)
            self.assertIn("nav problem: nav page missing on disk: docs/gone.md", err)

    def test_a_validation_problem_fails_the_write(self) -> None:
        """A curated page the tree does not hold stops the generator before it writes."""
        text = mkdocs_yaml("  - Home: index.md\n  - Broken:\n      - Gone: guides/gone.md\n")
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"], mkdocs_text=text)
            code, _, err = _run_main(root, [])
            self.assertEqual(1, code)
            self.assertIn("nav problem: nav page missing on disk: docs/guides/gone.md", err)
            self.assertFalse((root / "docs-site" / "lib" / "nav.json").exists())

    def test_no_nav_source_at_all_is_a_loud_error(self) -> None:
        """With no nav to read and no committed file to verify, the run must fail loudly.

        The message has to say what to do instead, because in a migrated repository
        ``mkdocs.yml`` is gone and this is the command a contributor reaches for first.
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = _checkout(pathlib.Path(tmp), pages=["index.md"])
            code, _, err = _run_main(root, [])
            self.assertEqual(1, code)
            self.assertIn("nav.json", err)
            self.assertIn("mkdocs.yml", err)


class RepoContractTests(unittest.TestCase):
    """What this checkout owes the site: a current nav.json that covers every page.

    ``setUpClass`` regenerates the committed file with the generator's own ``main()`` over
    the real tree, so these assertions read what the generator produces today rather than a
    hand-copied expectation that the ``.md`` to ``.mdx`` migration would age out.
    """

    tabs: list[dict[str, object]]
    pages: list[str]

    @classmethod
    def setUpClass(cls) -> None:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = gen_nav.main([])
        if code != 0:
            raise AssertionError(f"gen_nav.main([]) exited {code}\n{out.getvalue()}{err.getvalue()}")
        cls.printed = out.getvalue()
        cls.committed = json.loads(gen_nav.OUT_JSON.read_text(encoding="utf-8"))
        cls.tabs = gen_nav.build_tree()
        cls.pages = gen_nav.discover_pages()

    def test_generator_ran_over_the_real_tree(self) -> None:
        self.assertIn("wrote docs-site/lib/nav.json", self.printed)
        self.assertTrue(gen_nav.OUT_JSON.is_file())

    def test_regenerating_a_second_time_changes_nothing(self) -> None:
        """A run over an unchanged tree is a no-op, so the gate cannot churn the file."""
        first = gen_nav.OUT_JSON.read_text(encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = gen_nav.main([])
        self.assertEqual(0, code, err.getvalue())
        self.assertEqual(first, gen_nav.OUT_JSON.read_text(encoding="utf-8"))
        self.assertEqual(self.printed, out.getvalue())

    def test_committed_nav_json_equals_a_fresh_generation(self) -> None:
        self.assertEqual(self.tabs, self.committed)
        payload = json.dumps(self.tabs, indent=2, ensure_ascii=False) + "\n"
        self.assertEqual(payload, gen_nav.OUT_JSON.read_text(encoding="utf-8"))

    def test_the_committed_tree_validates_clean(self) -> None:
        self.assertEqual([], gen_nav.validate(self.committed))

    def test_every_on_disk_collection_page_appears_exactly_once(self) -> None:
        # Both sides are keyed by page identity, so a curated entry that still names the
        # ``.md`` path matches the ``.mdx`` file the migration left behind - the same rule
        # ``docs-site/lib/nav.ts`` applies when it resolves a nav entry.
        counts = collections.Counter(gen_nav._page_key(p["path"]) for p in gen_nav.flatten_pages(self.committed))
        self.assertEqual(
            [], [path for path in self.pages if counts.get(gen_nav._page_key(path), 0) == 0], "orphaned page"
        )
        self.assertEqual(
            [],
            [path for path in self.pages if counts.get(gen_nav._page_key(path), 0) > 1],
            "page filed more than once",
        )

    def test_no_tab_is_empty(self) -> None:
        for tab in self.committed:
            with self.subTest(tab=tab["title"]):
                self.assertTrue(tab["pages"], f"tab {tab['title']!r} holds no page")

    def test_every_tab_title_is_a_usable_label(self) -> None:
        titles = []
        for tab in self.committed:
            title = tab["title"]
            with self.subTest(title=title):
                self.assertIsInstance(title, str)
                self.assertNotEqual("", title.strip())
                self.assertEqual(title, title.strip())
            titles.append(title)
        self.assertEqual(len(titles), len(set(titles)), "two tabs share a title")

    def test_the_committed_tree_covers_the_whole_corpus(self) -> None:
        """Counted on the suffix-stripped path, so a rename to ``.mdx`` cannot dodge the rule."""
        strip = lambda path: path[:-4] if path.endswith(".mdx") else path[:-3]
        listed = {strip(page["path"]) for page in gen_nav.flatten_pages(self.committed)}
        self.assertEqual({strip(path) for path in self.pages}, listed)

    def test_the_main_module_guard_still_exits_zero(self) -> None:
        """The script form CI invokes works, and the committed file it checks is current.

        Re-executing the module re-reads its paths from its own file location, so the
        fixture patching cannot apply here; ``--check`` is the mode the pipeline runs.
        """
        with _captured_args(["--check"]), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                runpy.run_path(str(GEN_NAV_SCRIPT), run_name="__main__")
        self.assertEqual(0, raised.exception.code, "the committed nav.json must be current")


@contextlib.contextmanager
def _captured_args(argv: list[str]) -> Iterator[None]:
    """Pin ``sys.argv`` so a module run as ``__main__`` sees a known command line."""
    original = sys.argv
    sys.argv = ["gen_nav.py", *argv]
    try:
        yield
    finally:
        sys.argv = original


class _point_at:
    """Temporarily repoint the transcriber's module-level paths at a fixture root.

    ``DOCS_DIR`` has to move with the rest: the coverage rule, the folding, and the leaf
    titles all read the real ``docs/`` tree through it, so an unpatched value would judge a
    fixture against a corpus it never wrote.
    """

    def __init__(self, root: pathlib.Path) -> None:
        self._paths = {
            "REPO_ROOT": root,
            "MKDOCS_YML": root / "mkdocs.yml",
            "DOCS_DIR": root / "docs",
            "OUT_JSON": root / "docs-site" / "lib" / "nav.json",
        }
        self._saved: dict[str, pathlib.Path] = {}

    def __enter__(self) -> "_point_at":
        for name, value in self._paths.items():
            self._saved[name] = getattr(gen_nav, name)
            setattr(gen_nav, name, value)
        return self

    def __exit__(self, *_exc: object) -> None:
        for name, value in self._saved.items():
            setattr(gen_nav, name, value)


if __name__ == "__main__":
    unittest.main(verbosity=2)
