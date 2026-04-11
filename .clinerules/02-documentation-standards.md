---
description: Documentation formatting, structure, and markdown guidelines
author: toxicoder
version: 2.0
globs: ["**/*.md", "**/*.mdx"]
tags: ["documentation", "markdown", "standards"]
---

# Documentation Standards

> **Purpose**: Documentation formatting, structure, and README guidelines

---

## Inline Comment Guidelines

- Add comments for **complex logic**, not obvious code
- Prefer **self-documenting code** through good naming
- Comments explain **why**, not **what**

### TODO Comments

Use consistent format:

```text
// TODO: Refactor this function to use async/await
// TODO(#42): Fix authentication token expiry issue
```

### README Files

- Include a `README.md` in each major directory
- Explain the directory's purpose and contents
- Document how to run tests and examples

---

## Markdown Standards

Always follow The [CommonMark specification](https://spec.commonmark.org/) when writing markdown.

### Fenced Code Blocks

Always include a language specifier:

````text
# Wrong

```
code here
```

# Right

```bash
code here
```
````

#### MDLINT Rules

| MDLINT | Issue                                        | Solution                            |
| ------ | -------------------------------------------- | ----------------------------------- |
| MD040  | Fenced code block without language specifier | Add `text` or `bash`                |
| MD032  | List after heading                           | Add blank line before list          |
| MD037  | `/\* _/` without backticks                   | Wrap in backticks: `` `/\* _/\*` `` |
| MD024  | Duplicate headings                           | Rename to unique names              |
| MD047  | Multiple trailing newlines                   | Ensure single `\n` at end           |

### Verification Commands

```bash
# Check for duplicate headings
grep "^## " README.md | sort | uniq -d

# Check file ends with single newline
tail -c 10 README.md | od -c

# Count lines
wc -l README.md
```
