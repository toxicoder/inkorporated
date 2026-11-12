# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to adhere to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `config/flags.yaml`, the one place a switch is declared, with `default: false`, an owner,
  an expiry, and one reader per flag; `REQUIRE_LINT_TOOLS` is the first entry
- Trunk-based branch model documented in `docs/guides/git_workflow.md`, with promotion by
  tag and a retirement note for the branches that left
- `docs/guides/environments.md` value-home table and per-mechanism promotion commands
- Fumadocs (Next.js) documentation site in `docs-site/`, publishing the `docs/` tree to the
  `latest` and `development` GitHub Pages aliases
- Enterprise operating system documentation ported from devset (strategy, roles, policies, interviews, standards, style guides, playbooks, onboarding, training, support)
- Organization system: master org chart, matrix, leveling, headcount, RACI, cyborg deployment map, coverage matrix
- Cyborg machine catalog (`cyborgs/*.yaml`) converted from cyborg-conductor-core (69) plus initial enterprise expansion roles
- CONTRIBUTING.md, SECURITY.md, project conventions, PR template, pre-commit, dependabot, CI on development
- Family Office integrated under CEO in org documentation

### Changed

- `development` is the only long-lived branch; `CONTRIBUTING.md`, `AGENTS.md`, and
  `docs/project-conventions.md` state one model, and CI gates the trunk alone
- Docs deploy is triggered by a release tag or the trunk and publishes under the
  `production` / `staging` GitHub Environments; no deploy path reads a branch name
- Docs source links commit the trunk ref, and `docs/validate_docs_links.py` now fails a link
  pinned to a retired branch
- `docs-site/lib/site.ts` `gitRef()` falls back to the trunk instead of the retired
  production branch, so Edit-this-page links survive its deletion
- Documentation engine target migrated from Jekyll-primary to MkDocs Material, then to the
  Fumadocs site in `docs-site/`
- AGENTS.md rewritten as agent workflow guide pointing at project conventions
