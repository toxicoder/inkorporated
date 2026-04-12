# AGENTS.md

Global instructions for Kilo Code agents working on the inkorporated repository.

Kilo loads this file on every session. Follow these rules strictly.

## Agent Roles - Use the Right One

| Agent          | Model                         | Mode     | Description                                           |
| -------------- | ----------------------------- | -------- | ----------------------------------------------------- |
| @code          | Qwen3.5-27B (big 256K)        | primary  | Main code generation & implementation agent           |
| @debug         | Qwen3.5-27B (big 256K)        | primary  | Debugging, error analysis, and troubleshooting        |
| @orchestrator  | Qwen3.5-27B (big 256K)        | primary  | Coordinates multiple sub-agents and complex workflows |
| @ask           | Qwen3-Coder-Next (small 256K) | primary  | Quick Q&A and general assistance (read-only)          |
| @plan          | Qwen3.5-27B (big 256K)        | primary  | High-level architecture and planning (read-only)      |
| @coder         | Qwen3-Coder-Next (small 256K) | subagent | Fast implementation, refactoring, bug fixes           |
| @general       | Qwen3-Coder-Next (small 256K) | subagent | General-purpose tasks (read-only)                     |
| @title         | Qwen3-Coder-Next (small 256K) | subagent | Title generation (read-only)                          |
| @summary       | Qwen3-Coder-Next (small 256K) | subagent | Content summarization (read-only)                     |
| @compaction    | Qwen3-Coder-Next (small 256K) | subagent | Content compaction (read-only)                        |
| @code-reviewer | Qwen3.5-27B (big 256K)        | subagent | Read-only security, performance, and style review     |

## Decisive Action Rules (Must Follow)

- Be proactive and decisive. Never stall or over-explain.
- When the user intent is clear (implement, update, fix, add, change, etc.), immediately read the file if needed and then call the edit tool in the same response.
- Do not say "I need to read the file first" and then stop. Chain tools: read -> edit -> validate -> test.
- Prefer @coder for almost all implementation and refactoring work.
- After every edit, automatically run the relevant validation scripts and tests.
- Kilo's Prettier formatter runs automatically - never fight it.

## Project Overview

- Name: inkorporated (toxicoder/inkorporated)
- Architecture: Hybrid Cloud (Proxmox persistent control plane + AWS/GCP ephemeral burst)
- Core stack: Bazel, Terraform, Ansible, k3s, ArgoCD, Jekyll

Secrets live only in .devcontainer/.env (must be chmod 600).

## Critical Rules (Never Violate)

- NEVER hardcode any domain. Always use {{ .Env.DOMAIN_BASE }} templates.
- Always run ./validate_config.sh and ./validate_domain_config.sh before and after changes.
- No glob() in Bazel data attributes. Use explicit labels.
- Write modular, reusable code with rich docstrings and full type hints.
- 100% test coverage is expected for all new or changed code.
- Update documentation for any change (docs/guides/, docs/architecture/, etc.).

## Standard Workflow

1. Understand the request (use codebase_search if needed)
2. Read relevant files
3. Make the edit (use edit tool immediately)
4. Run validation scripts
5. Run relevant tests
6. Confirm the change

## Available MCP Tools

| Tool         | Purpose                                    |
| ------------ | ------------------------------------------ |
| context7     | Long-term context and indexing             |
| brave-search | Web search                                 |
| playwright   | Browser automation (uses its own Chromium) |

Last updated: 2026-04-11
