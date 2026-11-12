/**
 * Tests for search-index slimming.
 *
 * Generated pages must not dump every cell into Orama: the generated cyborg roster is
 * one card or table row per persona, and the unslimmed static `/api/search` export grows
 * past GitHub's blob limit and becomes too large to fetch in the browser anyway.
 */

import { describe, expect, it } from "vitest";

import {
  SEARCH_AUTHORED_CONTENTS_MAX,
  SEARCH_HEADINGS_MAX,
  isHeavySearchPath,
  slimSearchStructuredData,
  type SearchStructuredData
} from "../../lib/search-index";

function bulky(count: number): SearchStructuredData {
  return {
    headings: Array.from({ length: count }, (_, i) => ({
      id: `h-${i}`,
      content: `Heading ${i}`
    })),
    contents: Array.from({ length: count }, (_, i) => ({
      heading: `h-${i}`,
      content: `Cell ${i}`
    }))
  };
}

describe("isHeavySearchPath", () => {
  it("treats the generated cyborg roster as heavy", () => {
    expect(isHeavySearchPath("cyborgs/generated/index.md")).toBe(true);
    expect(isHeavySearchPath("cyborgs/generated/personas/BOARD0001.mdx")).toBe(true);
  });

  it("treats a generated directory at any depth as heavy", () => {
    expect(isHeavySearchPath("generated/index.md")).toBe(true);
    expect(isHeavySearchPath("architecture/generated/org_graph.mdx")).toBe(true);
  });

  it("leaves authored pages as full-text", () => {
    expect(isHeavySearchPath("index.md")).toBe(false);
    expect(isHeavySearchPath("cyborgs/catalog.md")).toBe(false);
    // "generated" only counts as its own path segment, not as part of a file name.
    expect(isHeavySearchPath("cyborgs/generated-notes.md")).toBe(false);
  });
});

describe("slimSearchStructuredData", () => {
  it("drops body blocks on generated pages and caps headings", () => {
    const slim = slimSearchStructuredData(
      "cyborgs/generated/personas/BOARD0001.mdx",
      bulky(200)
    );
    expect(slim.contents).toEqual([]);
    expect(slim.headings).toHaveLength(SEARCH_HEADINGS_MAX);
  });

  it("keeps a bounded body on authored pages", () => {
    const slim = slimSearchStructuredData("cyborgs/catalog.md", bulky(200));
    expect(slim.contents).toHaveLength(SEARCH_AUTHORED_CONTENTS_MAX);
    expect(slim.headings).toHaveLength(SEARCH_HEADINGS_MAX);
  });
});
