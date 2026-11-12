/**
 * Fumadocs MDX collection + compiler configuration.
 *
 * The collection is `dynamic: true` so production webpack compiles the app shell only and
 * each page's MDX is compiled when `page.data.load()` runs during static generation.
 * Bundling ~870 markdown files through `fumadocs-mdx/macro` OOMs GitHub's 7 GB runner.
 *
 * `mdxOptions` here is merged into Fumadocs' built-in remark/rehype chain (the preset
 * appends these `remarkPlugins` after GFM, heading, image and code-tab handling). Do not
 * set collection-level `mdxOptions` - that replaces the preset, including `rehypeToc`.
 */

import { defineConfig, defineDocs } from "fumadocs-mdx/config";
import { remarkAdmonition, remarkMdxMermaid } from "fumadocs-core/mdx-plugins";
import { metaSchema } from "fumadocs-core/source/schema";

import { docSchema, generatedSchema } from "./lib/content";
import { remarkGitRef } from "./lib/remark-git-ref";
import { remarkAbbreviations } from "./lib/remark-abbreviations";
import { remarkPageBrief } from "./lib/remark-page-brief";

/**
 * Point the collection at the repository `docs/` tree so the cyborg roster generator keeps
 * writing into `docs/cyborgs/generated/**` and contributors keep editing markdown where
 * they always have.
 *
 * Both extensions are listed because the compiler picks its syntax rules from the suffix:
 * `.md` compiles with MDX `format: "md"`, where `{` is literal text and raw HTML blocks are
 * dropped, and `.mdx` compiles with `format: "mdx"`, where tags are JSX and must be
 * well-formed. A page that carries HTML the reader needs (the roster grid) or that embeds a
 * component is authored as `.mdx`; everything else stays `.md`, exactly as MkDocs had it.
 *
 * The exclusions are the ones `mkdocs.yml` carried in `exclude_docs`: theme extras, the
 * abbreviation include, the roster generator's own JSON output, and the packaging files that
 * sit in the tree.
 */
export const docs = defineDocs({
  dir: "../docs",
  docs: {
    dynamic: true,
    files: [
      "**/*.md",
      "**/*.mdx",
      "!**/*.json",
      "!**/README.md",
      "!**/*.sh",
      "!**/*.py",
      "!**/BUILD.bazel",
      "!**/requirements.txt",
      "!**/Gemfile",
      "!includes/**",
      "!_data/**",
      "!assets/**",
      "!**/__pycache__/**"
    ],
    schema({ path }) {
      return /(^|\/)generated(\/|$)/.test(path.replace(/\\/g, "/")) ? generatedSchema : docSchema;
    }
  },
  meta: {
    // The only JSON in the tree is roster output (`docs/cyborgs/generated/_stats.json`),
    // which is not a Fumadocs folder meta.json file.
    files: [],
    schema: metaSchema
  }
});

export default defineConfig({
  mdxOptions: {
    remarkPlugins: [
      remarkAdmonition,
      remarkMdxMermaid,
      remarkGitRef,
      remarkAbbreviations,
      remarkPageBrief
    ]
  }
});
