/**
 * Tests for the published-site base path.
 *
 * GitHub project Pages serves the repo at `/<repo>/`, so an alias build that bakes
 * `basePath=/latest` asks the browser for `https://<user>.github.io/latest/_next/...` and
 * every stylesheet 404s.  The helper must prefix the repo name; local `next dev` and the
 * unprefixed export used by render-check keep an empty path.
 */

import { afterEach, describe, expect, it } from "vitest";

import { basePath, docsAlias, gitRef, REPO, searchIndexPath } from "../../lib/site";

const ENV_KEYS = ["NEXT_BASE_PATH", "DOCS_ALIAS", "INK_DOCS_VERSION", "INK_DOCS_GIT_REF"] as const;

const originalEnv: Record<string, string | undefined> = {};

afterEach(() => {
  for (const key of ENV_KEYS) {
    if (originalEnv[key] === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = originalEnv[key];
    }
  }
});

for (const key of ENV_KEYS) {
  originalEnv[key] = process.env[key];
  delete process.env[key];
}

describe("basePath", () => {
  it("is empty for local dev and the unprefixed export", () => {
    expect(basePath()).toBe("");
  });

  it("prefixes the GitHub Pages repo path for the latest alias", () => {
    process.env.DOCS_ALIAS = "latest";
    expect(basePath()).toBe(`/${REPO.repo}/latest`);
  });

  it("prefixes the GitHub Pages repo path for the development alias", () => {
    process.env.DOCS_ALIAS = "development";
    expect(basePath()).toBe(`/${REPO.repo}/development`);
  });

  it("lets NEXT_BASE_PATH override the alias", () => {
    process.env.DOCS_ALIAS = "latest";
    process.env.NEXT_BASE_PATH = "/custom";
    expect(basePath()).toBe("/custom");
  });

  it("treats NEXT_BASE_PATH=/ as no prefix", () => {
    process.env.NEXT_BASE_PATH = "/";
    process.env.DOCS_ALIAS = "latest";
    expect(basePath()).toBe("");
  });
});

describe("docsAlias", () => {
  it("is local when no publish env is set", () => {
    delete process.env.INK_DOCS_VERSION;
    delete process.env.DOCS_ALIAS;
    expect(docsAlias()).toBe("local");
  });

  it("follows INK_DOCS_VERSION for the development banner build", () => {
    process.env.INK_DOCS_VERSION = "development";
    expect(docsAlias()).toBe("development");
  });

  it("follows DOCS_ALIAS=latest when the version env is empty", () => {
    delete process.env.INK_DOCS_VERSION;
    process.env.DOCS_ALIAS = "latest";
    expect(docsAlias()).toBe("latest");
  });
});

describe("searchIndexPath", () => {
  it("stays at the host root for a local preview", () => {
    delete process.env.DOCS_ALIAS;
    delete process.env.NEXT_BASE_PATH;
    expect(searchIndexPath("")).toBe("/api/search");
    expect(searchIndexPath()).toBe("/api/search");
  });

  it("prefixes the GitHub Pages alias so the static index is not a root 404", () => {
    expect(searchIndexPath(`/${REPO.repo}/development`)).toBe(
      `/${REPO.repo}/development/api/search`
    );
    expect(searchIndexPath(`/${REPO.repo}/latest/`)).toBe(`/${REPO.repo}/latest/api/search`);
  });
});

describe("gitRef", () => {
  it("honours the ref the deploy was handed, which is how a release build names its tag", () => {
    process.env.INK_DOCS_GIT_REF = "v1.4.0";
    process.env.DOCS_ALIAS = "latest";
    expect(gitRef()).toBe("v1.4.0");
  });

  it("names the trunk for a trunk build", () => {
    process.env.INK_DOCS_VERSION = "development";
    expect(gitRef()).toBe("main");
  });

  it("names the trunk rather than a retired production branch when nothing is stamped", () => {
    // `remark-git-ref.ts` stamps every committed `blob/<ref>/` link with this value, so a
    // retired ref here would silently send ~580 source links into a deleted branch.
    delete process.env.INK_DOCS_GIT_REF;
    process.env.DOCS_ALIAS = "latest";
    expect(gitRef()).toBe("main");
  });
});
