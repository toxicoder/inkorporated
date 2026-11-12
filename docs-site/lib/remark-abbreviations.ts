/**
 * Site-wide abbreviation tooltips from `docs/includes/abbreviations.md`.
 *
 * MkDocs rendered these with the `abbr` extension plus a `pymdownx.snippets`
 * `auto_append` of the same file, so every page carried the definitions and every
 * first occurrence became an `<abbr>` tooltip. Fumadocs has no snippet auto-append,
 * so the same file is parsed here and the wrapping happens in the remark chain
 * instead: one wrapper per term per page, first occurrence only.
 *
 * The authored file stays the single source of truth and stays markdown, so a
 * contributor adds a line there and every page picks it up.
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { visit } from "unist-util-visit";

/** One `*[API]: Application Programming Interface` line. */
export interface Abbreviation {
  /** Short form as authored, e.g. `RBAC`. */
  abbr: string;
  /** Expansion shown in the tooltip. */
  expansion: string;
}

/** `*[ABBR]: expansion`, tolerant of surrounding whitespace. */
const ABBR_LINE_RE = /^\*\[(?<abbr>[^\]]+)\]:[ \t]*(?<expansion>.+?)[ \t]*$/;

/** Path of the authored abbreviation file, relative to the repository root. */
const ABBREVIATIONS_RELATIVE = ["docs", "includes", "abbreviations.md"];

/**
 * Locate and parse the authored abbreviation file.
 *
 * The site package is one directory below the repository root in a checkout, so
 * both the working-directory and module-relative resolutions are tried; a build
 * that finds no file renders without tooltips rather than failing, because the
 * abbreviation layer is decoration and the page content is the product.
 *
 * @returns Parsed abbreviations in authored order, newest duplicate winning.
 */
export function loadAbbreviations(): Abbreviation[] {
  const here = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    resolve(process.cwd(), "..", ...ABBREVIATIONS_RELATIVE),
    resolve(here, "..", "..", ...ABBREVIATIONS_RELATIVE)
  ];
  const file = candidates.find((candidate) => existsSync(candidate));
  if (!file) return [];

  const byAbbr = new Map<string, Abbreviation>();
  for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = ABBR_LINE_RE.exec(line.trim());
    const abbr = match?.groups?.abbr?.trim();
    const expansion = match?.groups?.expansion?.trim();
    if (!abbr || !expansion) continue;
    byAbbr.set(abbr.toLowerCase(), { abbr, expansion });
  }
  return [...byAbbr.values()];
}

/** Node types whose text must not be wrapped (code, headings, links, ...). */
const SKIPPED_PARENTS = new Set([
  "link",
  "heading",
  "inlineCode",
  "code",
  "abbr",
  "mdxJsxTextElement",
  "mdxJsxFlowElement",
  "tableCell"
]);

interface ParentNodeLike {
  type: string;
  children: unknown[];
}

/** A node with the two fields a parent must have, or nothing when it is not a parent. */
function asParent(value: unknown): ParentNodeLike | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const candidate = value as { type?: unknown; children?: unknown };
  if (typeof candidate.type !== "string" || !Array.isArray(candidate.children)) return undefined;
  return { type: candidate.type, children: candidate.children };
}

/** The `value` of a text node, or the empty string when the node carries none. */
function textValue(node: unknown): string {
  if (typeof node !== "object" || node === null) return "";
  const value = (node as { value?: unknown }).value;
  return typeof value === "string" ? value : "";
}

const REGEX_METACHARACTERS = new Set([".", "*", "+", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]"]);

function escapeRe(term: string): string {
  return [...term].map((char) => (REGEX_METACHARACTERS.has(char) ? `\\${char}` : char)).join("");
}

/**
 * Wrap the first occurrence of each abbreviation in an `<Abbr>` element.
 *
 * @returns A remark transformer.
 */
export function remarkAbbreviations(): (tree: Parameters<typeof visit>[0]) => void {
  return (tree) => {
    const abbreviations = loadAbbreviations();
    if (abbreviations.length === 0) return;

    const lookup = new Map<string, Abbreviation>();
    for (const entry of abbreviations) lookup.set(entry.abbr.toLowerCase(), entry);

    // Longest first so `IaC` wins over a shorter form that could shadow it.
    const forms = abbreviations.map((entry) => entry.abbr).sort((a, b) => b.length - a.length || a.localeCompare(b));
    const matcher = new RegExp(
      `(?<![A-Za-z0-9_])(${forms.map(escapeRe).join("|")})(?![A-Za-z0-9_])`,
      "gi"
    );
    const seen = new Set<string>();

    visit(tree, "text", (node, index, rawParent) => {
      const parent = asParent(rawParent);
      if (!parent || typeof index !== "number") return;
      if (SKIPPED_PARENTS.has(parent.type)) return;

      const text = textValue(node);
      if (text.length === 0) return;
      matcher.lastIndex = 0;
      if (!matcher.test(text)) {
        matcher.lastIndex = 0;
        return;
      }
      matcher.lastIndex = 0;

      const children: unknown[] = [];
      let cursor = 0;
      for (const match of text.matchAll(matcher)) {
        const found = match[0];
        const entry = lookup.get(found.toLowerCase());
        if (!entry || seen.has(entry.abbr.toLowerCase()) || match.index === undefined) continue;
        seen.add(entry.abbr.toLowerCase());
        if (match.index > cursor) children.push({ type: "text", value: text.slice(cursor, match.index) });
        children.push({
          type: "mdxJsxTextElement",
          name: "Abbr",
          attributes: [
            { type: "mdxJsxAttribute", name: "title", value: entry.expansion },
            { type: "mdxJsxAttribute", name: "abbreviation", value: entry.abbr }
          ],
          children: [{ type: "text", value: found }],
          data: { _mdxExplicitJsx: true }
        });
        cursor = match.index + found.length;
      }
      if (children.length === 0) return;
      if (cursor < text.length) children.push({ type: "text", value: text.slice(cursor) });
      parent.children.splice(index, 1, ...children);
    });
  };
}
