/**
 * Prefilled GitHub issue URLs for the heading bug button.
 */

import { describe, expect, it } from "vitest";

import { docsBugHref, type DocsBugReport } from "../../lib/docs-bug";

function report(overrides: Partial<DocsBugReport> = {}): DocsBugReport {
  return {
    pageUrl: "https://toxicoder.github.io/inkorporated/development/cyborgs/operating_model/#kill-switches",
    pageTitle: "Cyborg operating model",
    heading: "Kill switches",
    headingId: "kill-switches",
    sourcePath: "docs/cyborgs/operating_model.md",
    sourceUrl: "https://github.com/toxicoder/inkorporated/blob/development/docs/cyborgs/operating_model.md",
    gitRef: "development",
    docsAlias: "development",
    userAgent: "TestAgent/1.0",
    viewport: "1440x950",
    colorScheme: "dark",
    selection: "",
    ...overrides
  };
}

describe("docsBugHref", () => {
  it("opens a new GitHub issue with the page, heading, alias, and blanks", () => {
    const href = docsBugHref(report());
    const url = new URL(href);
    expect(url.origin + url.pathname).toBe("https://github.com/toxicoder/inkorporated/issues/new");
    expect(url.searchParams.get("title")).toBe("Docs: Cyborg operating model - Kill switches");
    // Only labels that exist in the repo survive: GitHub drops unknown ones silently.
    expect(url.searchParams.get("labels")).toBe("documentation");
    const body = url.searchParams.get("body") ?? "";
    expect(body).toContain("cyborgs/operating_model/#kill-switches");
    expect(body).toContain("`#kill-switches`");
    expect(body).toContain("Docs alias: development");
    expect(body).toContain("Git ref: development");
    expect(body).toContain("docs/cyborgs/operating_model.md");
    expect(body).toContain("https://github.com/toxicoder/inkorporated/blob/development/docs/cyborgs/operating_model.md");
    expect(body).toContain("## What is wrong");
    expect(body).toContain("## What it should say");
    expect(body).toContain("<!-- Replace this line. -->");
    expect(body).toContain("1440x950");
    expect(body).toContain("Color scheme: dark");
  });

  it("drops a huge selection so the URL stays openable", () => {
    const href = docsBugHref(report({ selection: "x".repeat(20_000), userAgent: "y".repeat(5_000) }));
    expect(href.length).toBeLessThanOrEqual(5500);
    expect(href).toContain("/issues/new");
  });
});