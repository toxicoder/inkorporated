# Security Policy

## Reporting a vulnerability

If you discover a security issue in this repository or in deployments derived from it, report it privately to the repository maintainer (or `{{SECURITY_EMAIL}}` when configured). Do **not** open a public issue for undisclosed vulnerabilities.

## Secrets and credentials

This repository must never contain:

- Live API keys, tokens, or passwords
- Private keys (`.pem`, SSH keys, TLS private material)
- Cluster kubeconfig files with real credentials
- Populated `.devcontainer/.env` (use `.env.example` only)
- Production inventory with real host secrets

Use templates and local-only env files. Runtime secrets belong in environment variables, sealed secrets, or a vault — never in git.

### Agent CLIs

Do not put API keys in committed devcontainer env blocks. Authenticate interactively or via ephemeral shell environment. Do not commit `~/.grok` or similar auth state.

## Domain hardcoding

Ingress and public URLs must use templated domain configuration (for example `{{DOMAIN_BASE}}` / environment config). See `validate_domain_config.sh` and project conventions.

## Cyborg / agent safety

- CRITICAL personas require human approval for side effects
- Family Office (`PERS*`) agents are restricted-invoker
- Tool allowlists are mandatory in cyborg YAML

## Dependency and supply chain

- Prefer pinned versions in lockfiles and `docs/requirements.txt`
- Run repository validation (`./run_all_tests.sh`, docs strict build) before merging risky changes
- Review third-party charts and images before cluster bootstrap

## History hygiene

Before sharing clones outside trusted environments, scan the tree and git history for accidentally committed secrets.
