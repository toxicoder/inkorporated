# Cyborg machine catalog

YAML persona specs for Inkorporated AI agents (role-aligned “cyborgs”).

## Layout

- `*.yaml` — one file per `job_id` (e.g. `EXEC0001.yaml`)
- `_index.yaml` — generated index of checked-in personas

## Schema

See [docs/cyborgs/schema.md](../docs/cyborgs/schema.md).

## Source

Initial 69 personas converted from [cyborg-conductor-core](https://github.com/toxicoder/cyborg-conductor-core) textproto definitions, then enriched toward the full enterprise schema.

## Rules

1. Keep `job_id` stable once published.
2. Prefer updating system prompts when job docs change.
3. Family Office (`PERS*`) must set restricted `security.allowed_invokers`.
4. Do not store secrets in YAML — reference tool names only.
