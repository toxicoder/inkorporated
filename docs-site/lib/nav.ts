/**
 * Sidebar menu structure, hand-maintained in `lib/nav.json`.
 *
 * The site inherited its seven top-level sections from the old MkDocs `nav:` block, and
 * `scripts/gen_nav.py` transcribed that block into `lib/nav.json`. `mkdocs.yml` is long
 * gone, so `lib/nav.json` is now the single source of truth: edit it by hand and verify
 * with `bazelisk test //docs-site:nav_test`, the target that gates `scripts/gen_nav.py`
 * (its `--check` mode is what the `nav:check` npm script wraps). The top-level section
 * titles are pinned by `docs/test_docs_site_render.py`, and every page under `docs/` has
 * to appear in the tree exactly once (`tests/python/test_docs_nav_coverage.py` fails an
 * orphan or a stale entry).
 *
 * Inside a section, pages are grouped into collapsible folders that read as a progression:
 * the job-role catalog runs board to family office, the infrastructure pages run
 * architecture to runbook, and so on. A group is `{ title, pages }` with no `path`; its
 * leaves keep their order and nest to any depth. Keep each folder short enough to scan in
 * one glance - a flat list of twenty siblings tells a reader nothing about where they are.
 *
 * `scripts/gen_nav.py` writes the tree: it keeps the curated order of the retired
 * `mkdocs.yml` `nav:` block and folds every other page under `docs/` into the section that
 * owns its directory, so a new page lands in the menu without a hand edit and an orphan
 * fails `bazelisk test //docs-site:nav_test`. The per-persona pages under
 * `docs/cyborgs/generated/personas/` stay out of the menu by design, exactly as MkDocs had
 * them; they are reached from the roster, the namespace index and search.
 */

import type { Folder, Item, Node, Root } from "fumadocs-core/page-tree";
import type { ReactNode } from "react";
import type { LoaderOutput } from "fumadocs-core/source";
import { z } from "zod";

import navData from "./nav.json";

/**
 * The slice of the content loader the navigation needs.
 *
 * Declared structurally (rather than as a bare `LoaderOutput`) so the loader instance built
 * in `lib/source.ts` - whose page type is the specialised one from the collection schemas -
 * is accepted without a variance complaint.
 */
export type NavSource = Pick<LoaderOutput, "getPages">;

/** One leaf of the transcribed navigation. */
export interface NavPage {
  /** Label shown in the sidebar, exactly as MkDocs rendered it. */
  title: string;
  /** Path of the page relative to `docs/`, e.g. `operate/mcp.md`. */
  path: string;
}

/** A nested sidebar folder (a job-role family, an infrastructure runbook group, ...). */
export interface NavGroup {
  title: string;
  pages: NavNode[];
}

export type NavNode = NavPage | NavGroup;

/** One top-level section of the transcribed navigation (the old MkDocs tab). */
export interface NavTab {
  title: string;
  pages: NavNode[];
}

/**
 * The runtime shape `lib/nav.json` has to satisfy.
 *
 * `nav.json` is a JSON import, so TypeScript sees only the inferred literal shape and a
 * wrong key would surface as `undefined` deep in the sidebar. These schemas parse it once
 * at import time instead, and the `z.ZodType<...>` annotations tie the schema to the
 * declared interfaces above: a field added to one side and not the other fails
 * `bazelisk test //docs-site:typecheck`.
 */
const navPageSchema = z.object({ title: z.string(), path: z.string() });

const navNodeSchema: z.ZodType<NavNode> = z.lazy(() =>
  z.union([navPageSchema, z.object({ title: z.string(), pages: z.array(navNodeSchema) })])
);

export const navTabsSchema: z.ZodType<NavTab[]> = z.array(
  z.object({ title: z.string(), pages: z.array(navNodeSchema) })
);

/** A folder is the variant that carries `pages`; a leaf is the one that carries `path`. */
function isGroup(node: NavNode): node is NavGroup {
  return "pages" in node;
}

function isPage(node: NavNode): node is NavPage {
  return "path" in node;
}

const STATIC_NAV: NavTab[] = navTabsSchema.parse(navData);

/** Drop the directory suffix so `foo.md` and `foo.mdx` compare equal. */
export function stripExtension(path: string): string {
  return path.replace(/\.(?:md|mdx)$/u, "");
}

function toItem(source: NavSource, tabTitle: string, path: string, title: string): Item {
  const page = source.getPages().find((candidate) => stripExtension(candidate.path) === stripExtension(path));
  if (!page) {
    throw new Error(
      `navigation references a page that is not in the content source: ${path} (tab "${tabTitle}")`
    );
  }
  return { $id: `page:${path}`, type: "page", name: title, url: page.url, $ref: page.path };
}

function toNodes(source: NavSource, tabTitle: string, nodes: NavNode[], idPrefix: string): Node[] {
  return nodes.map((node, index) => {
    if (isGroup(node)) {
      const children = toNodes(source, tabTitle, node.pages, `${idPrefix}/${index}`);
      const folder: Folder = {
        $id: `folder:${idPrefix}/${index}:${node.title}`,
        type: "folder",
        name: node.title,
        defaultOpen: false,
        children
      };
      const first = node.pages[0];
      if (first && isPage(first) && /(^|\/)index$/.test(stripExtension(first.path))) {
        folder.index = toItem(source, tabTitle, first.path, first.title);
      }
      return folder;
    }
    return toItem(source, tabTitle, node.path, node.title);
  });
}

/**
 * Build the page tree the docs layout renders.
 *
 * Every section is a plain collapsible folder - deliberately not a root folder.
 * fumadocs turns each root folder into a layout tab and shows those tabs as a dropdown
 * selector above the sidebar, which would leave the sidebar holding only the current
 * section. Without root folders the sidebar is one traditional vertical menu: all seven
 * sections listed at once, each expandable, the reader's own section opened by fumadocs.
 * The right-hand table of contents comes from `DocsPage`'s `toc` prop and is untouched by
 * this choice.
 */
export function buildPageTree(source: NavSource): Root {
  const nav = STATIC_NAV;
  const children: Node[] = nav.map((tab, index) => {
    const pages = toNodes(source, tab.title, tab.pages, `tab:${index}`);
    const folder: Folder = {
      $id: `tab:${index}:${tab.title}`,
      type: "folder",
      name: tab.title,
      defaultOpen: true,
      children: pages
    };
    const first = tab.pages[0];
    if (first && isPage(first) && /(^|\/)index$/.test(stripExtension(first.path))) {
      folder.index = toItem(source, tab.title, first.path, first.title);
    }
    return folder;
  });

  return { $id: "root", type: "root", name: "Documentation", children };
}

function flattenPages(nodes: NavNode[]): NavPage[] {
  const out: NavPage[] = [];
  for (const node of nodes) {
    if (isPage(node)) out.push(node);
    else out.push(...flattenPages(node.pages));
  }
  return out;
}

/** Paths of every page in the static navigation (no generated injection), in menu order. */
export const NAVIGATED_PATHS: string[] = STATIC_NAV.flatMap((tab) => flattenPages(tab.pages).map((page) => page.path));

/**
 * Previous and next pages in reading order, after generated children are merged.
 */
export function neighborsOf(
  source: NavSource,
  path: string
): { previous?: PageNodeEntry; next?: PageNodeEntry } {
  const wanted = stripExtension(path);
  const nav = STATIC_NAV;
  const flat = nav.flatMap((tab) => flattenPages(tab.pages).map((page) => ({ tab: tab.title, page })));
  const index = flat.findIndex((entry) => stripExtension(entry.page.path) === wanted);
  if (index === -1) return {};
  const at = (offset: number): PageNodeEntry | undefined => {
    const entry = flat[index + offset];
    if (!entry) return undefined;
    const item = toItem(source, entry.tab, entry.page.path, entry.page.title);
    return { name: item.name, url: item.url };
  };
  const previous = at(-1);
  const next = at(1);
  // exactOptionalPropertyTypes: omit the key when there is no neighbour so consumers can
  // pass this straight into a footer slot that declares `previous?: PageNodeEntry`.
  return { ...(previous ? { previous } : {}), ...(next ? { next } : {}) };
}

/** A prev/next footer entry shaped the way the footer slot expects. */
export interface PageNodeEntry {
  name: ReactNode;
  url: string;
}

/** Where a page sits in the sidebar menu: its section, then each collapsible folder above it. */
export interface NavTrail {
  /** Title of the section the page is filed under. */
  tab: string;
  /** Folder titles between the section and the page, outermost first. */
  groups: string[];
  /** Label the sidebar shows for the page, so the trail and the sidebar agree. */
  label: string;
}

/**
 * Sidebar location of one page, for the breadcrumb above the title.
 *
 * fumadocs' own breadcrumb prints page titles, so it cannot name the section the reader is
 * in or agree with the wording the menu rows use. This walks the same tree the sidebar
 * renders and returns both.
 *
 * Arguments: path - page path relative to `docs/`, with or without its extension.
 * Returns: the section, folder titles, and sidebar label, or undefined when the page is not
 * filed in the tree.
 */
export function trailFor(path: string): NavTrail | undefined {
  const wanted = stripExtension(path);
  const walk = (nodes: NavNode[], groups: string[]): NavTrail | undefined => {
    for (const node of nodes) {
      if (isPage(node)) {
        if (stripExtension(node.path) === wanted) return { tab: "", groups, label: node.title };
        continue;
      }
      const found = walk(node.pages, [...groups, node.title]);
      if (found) return found;
    }
    return undefined;
  };
  for (const tab of STATIC_NAV) {
    const found = walk(tab.pages, []);
    if (found) return { tab: tab.title, groups: found.groups, label: found.label };
  }
  return undefined;
}
