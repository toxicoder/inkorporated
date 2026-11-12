/**
 * Tests for the site-wide abbreviation tooltips.
 *
 * The plugin is the only thing between `docs/includes/abbreviations.md` and a reader
 * seeing a bare acronym, and it parses that file with the JavaScript named-group form of
 * the definition regex.  A Python-style `(?P<abbr>...)` is a pattern the engine rejects at
 * import time, which took the whole Next.js build down, so these cases assert that the
 * plugin runs and emits the node `components/abbr.tsx` renders.
 */

import type { PathLike } from "node:fs";

import { beforeEach, describe, expect, it, vi } from "vitest";

import { loadAbbreviations, remarkAbbreviations } from "../../lib/remark-abbreviations";

/**
 * The dictionary is read straight off disk with no seam, so the definition-line cases swap
 * the file content through `node:fs`.  Left as it is the real authored file is used, which
 * is what the prose cases assert against.
 */
const { dictionaryFile } = vi.hoisted(() => ({
  dictionaryFile: { content: null as string | null, present: true }
}));

vi.mock("node:fs", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:fs")>();
  return {
    ...actual,
    existsSync: (path: PathLike) => dictionaryFile.present && actual.existsSync(path),
    readFileSync: (path: PathLike, options: unknown) =>
      dictionaryFile.content ?? actual.readFileSync(path, options as BufferEncoding)
  };
});

beforeEach(() => {
  dictionaryFile.content = null;
  dictionaryFile.present = true;
});

/** The mdast shape the plugin walks, narrowed to the fields these tests read back. */
interface TestNode {
  type: string;
  value?: string;
  lang?: string;
  name?: string;
  attributes?: { type: string; name: string; value: string }[];
  children?: TestNode[];
}

/** An `Abbr` element as the plugin emits it. */
interface JsxNode {
  type: string;
  name?: string;
  attributes?: { name?: string; value?: string }[];
  children?: unknown[];
}

function text(value: string): TestNode {
  return { type: "text", value };
}

function inlineCode(value: string): TestNode {
  return { type: "inlineCode", value };
}

/** A child of a test container; prose may be written as a bare string. */
type Child = TestNode | string;

function toNode(child: Child): TestNode {
  return typeof child === "string" ? text(child) : child;
}

function parent(type: string, ...children: TestNode[]): TestNode {
  return { type, children };
}

/** Put the blocks through the plugin. */
function run(...blocks: TestNode[]): void {
  remarkAbbreviations()(parent("root", ...blocks));
}

/** Run the plugin over one paragraph and hand back the children it left behind. */
function transform(...children: Child[]): TestNode[] {
  return transformUnder("paragraph", ...children);
}

/** Same, under a named container, for the parents the plugin must not enter. */
function transformUnder(containerType: string, ...children: Child[]): TestNode[] {
  const container = parent(containerType, ...children.map(toNode));
  run(container);
  return container.children ?? [];
}

/** The `Abbr` elements anywhere under a node or a list of siblings, in document order. */
function abbrs(value: unknown, found: JsxNode[] = []): JsxNode[] {
  if (Array.isArray(value)) {
    for (const sibling of value) abbrs(sibling, found);
    return found;
  }
  if (typeof value === "object" && value !== null) {
    const node = value as JsxNode;
    if (node.type === "mdxJsxTextElement" && node.name === "Abbr") found.push(node);
    for (const child of node.children ?? []) abbrs(child, found);
  }
  return found;
}

/** The tooltip text of an `Abbr` element. */
function titleOf(node: JsxNode): string | undefined {
  return node.attributes?.find((attribute) => attribute.name === "title")?.value;
}

describe("loadAbbreviations", () => {
  it("parses the authored file through the JavaScript named-group regex", () => {
    const entries = loadAbbreviations();
    expect(entries).toContainEqual({ abbr: "RBAC", expansion: "Role-Based Access Control" });
    expect(entries).toContainEqual({
      abbr: "GitOps",
      expansion: "Git-based continuous delivery and operations"
    });
    expect(entries.length).toBeGreaterThanOrEqual(12);
    // Every entry is a regex match, so a group name the engine cannot parse throws here
    // rather than quietly returning a dictionary with no tooltips in it.
    for (const entry of entries) {
      expect(entry.abbr).not.toBe("");
      expect(entry.expansion).not.toBe("");
      expect(entry.abbr).not.toContain("[");
      expect(entry.expansion).not.toMatch(/^\s|\s$/u);
    }
  });

  it("skips malformed definition lines rather than throwing", () => {
    dictionaryFile.content = [
      "",
      "# A heading, not a definition",
      "Prose a contributor left in the file.",
      "*[NOEXPANSION]:",
      "*[EMPTY]: ",
      "*[]: no short form at all",
      "*[ ]: only a space as the short form",
      "[NOSTAR]: missing the leading star",
      "* NOBRACKETS: nope",
      "*[TAB]:\tTab-Separated Values",
      "   *[PADDED]:   spaced out on purpose   ",
      "*[GOOD]: A real definition"
    ].join("\n");

    expect(loadAbbreviations()).toEqual([
      { abbr: "TAB", expansion: "Tab-Separated Values" },
      { abbr: "PADDED", expansion: "spaced out on purpose" },
      { abbr: "GOOD", expansion: "A real definition" }
    ]);
  });

  it("lets the last definition of a repeated term win", () => {
    dictionaryFile.content = ["*[DUP]: the first expansion", "*[dup]: the second expansion"].join(
      "\n"
    );
    expect(loadAbbreviations()).toEqual([{ abbr: "dup", expansion: "the second expansion" }]);
  });

  it("yields nothing when the authored file is absent, so the page still builds", () => {
    dictionaryFile.present = false;
    expect(loadAbbreviations()).toEqual([]);
    expect(transform("Mentioning RBAC with no dictionary on disk.")).toEqual([
      text("Mentioning RBAC with no dictionary on disk.")
    ]);
  });
});

describe("remarkAbbreviations", () => {
  it("wraps an authored abbreviation in an Abbr element carrying its expansion", () => {
    const children = transform("Access is decided by RBAC in the control plane.");
    expect(children).toHaveLength(3);
    expect(children[0]).toEqual({ type: "text", value: "Access is decided by " });
    expect(children[1]).toEqual({
      type: "mdxJsxTextElement",
      name: "Abbr",
      attributes: [
        { type: "mdxJsxAttribute", name: "title", value: "Role-Based Access Control" },
        { type: "mdxJsxAttribute", name: "abbreviation", value: "RBAC" }
      ],
      children: [{ type: "text", value: "RBAC" }],
      data: { _mdxExplicitJsx: true }
    });
    expect(children[2]).toEqual({ type: "text", value: " in the control plane." });
  });

  it("leaves prose that names no authored abbreviation alone", () => {
    const prose = "Nothing here uses a short form anybody authored.";
    expect(transform(prose)).toEqual([text(prose)]);
  });

  it("wraps every authored term in a text node, but only its first occurrence", () => {
    const children = transform("The API and the RBAC model. The API is documented.");
    expect(abbrs(children).map(titleOf)).toEqual([
      "Application Programming Interface",
      "Role-Based Access Control"
    ]);
    // The second `API` stays plain text: one tooltip per term per page, as MkDocs did it.
    expect(children.at(-1)).toEqual({ type: "text", value: " model. The API is documented." });
  });

  it("leaves code spans and code blocks alone and does not spend the first occurrence there", () => {
    const children = transform("Set ", inlineCode("RBAC_MODE"), text(" before RBAC is enforced."));
    expect(children).toContainEqual(inlineCode("RBAC_MODE"));
    expect(abbrs(children).map(titleOf)).toEqual(["Role-Based Access Control"]);
    expect(children.at(-1)).toEqual({ type: "text", value: " is enforced." });

    const fenced: TestNode = { type: "code", lang: "bash", value: "export RBAC_MODEL=$RBAC" };
    expect(() => run(fenced)).not.toThrow();
    expect(abbrs(fenced)).toHaveLength(0);
    expect(fenced.value).toBe("export RBAC_MODEL=$RBAC");
  });

  it("does not enter the containers it skips", () => {
    for (const containerType of ["code", "inlineCode", "heading", "link", "tableCell"]) {
      const inside = text("RBAC sits here");
      expect(transformUnder(containerType, inside), containerType).toEqual([inside]);
    }
  });

  it("does not wrap a short form that is glued to more word characters", () => {
    expect(transform("Many APIs were deprecated.")).toEqual([text("Many APIs were deprecated.")]);
    expect(transform("Use RBAC1 for the legacy cluster.")).toEqual([
      text("Use RBAC1 for the legacy cluster.")
    ]);
  });

  it("matches case-insensitively but keeps the authored short form in the attribute", () => {
    const children = transform("The rbac model is audited.");
    expect(abbrs(children)).toEqual([
      {
        type: "mdxJsxTextElement",
        name: "Abbr",
        attributes: [
          { type: "mdxJsxAttribute", name: "title", value: "Role-Based Access Control" },
          { type: "mdxJsxAttribute", name: "abbreviation", value: "RBAC" }
        ],
        // The page keeps the form the contributor wrote; only the tooltip is authored.
        children: [{ type: "text", value: "rbac" }],
        data: { _mdxExplicitJsx: true }
      }
    ]);
  });

  it("escapes metacharacters in a short form and prefers the longer of two overlapping ones", () => {
    dictionaryFile.content = [
      // Unescaped, `C++` is an invalid pattern and a bare `.` matches any character.
      "*[C++]: a systems language",
      "*[F.O]: family office",
      "*[FO]: Family Office",
      "*[FOC]: frequency of control"
    ].join("\n");

    expect(abbrs(transform("Written in C++ last week.")).map(titleOf)).toEqual([
      "a systems language"
    ]);
    expect(transform("The FXO note.")).toEqual([text("The FXO note.")]);
    expect(abbrs(transform("The F.O note.")).map(titleOf)).toEqual(["family office"]);
    expect(abbrs(transform("FOC is the metric.")).map(titleOf)).toEqual(["frequency of control"]);
  });
});
