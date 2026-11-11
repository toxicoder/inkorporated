# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to adhere to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Fumadocs (Next.js) documentation site in `docs-site/`, publishing the `docs/` tree to the
  `latest` and `development` GitHub Pages aliases
- Enterprise operating system documentation ported from devset (strategy, roles, policies, interviews, standards, style guides, playbooks, onboarding, training, support)
- Organization system: master org chart, matrix, leveling, headcount, RACI, cyborg deployment map, coverage matrix
- Cyborg machine catalog (`cyborgs/*.yaml`) converted from cyborg-conductor-core (69) plus initial enterprise expansion roles
- CONTRIBUTING.md, SECURITY.md, project conventions, PR template, pre-commit, dependabot, CI on development
- Family Office integrated under CEO in org documentation

### Changed

- Documentation engine target migrated from Jekyll-primary to MkDocs Material, then to the
  Fumadocs site in `docs-site/`
- AGENTS.md rewritten as agent workflow guide pointing at project conventions
