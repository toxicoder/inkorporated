## Summary

<!-- What changed and why (1–2 sentences). -->

## Changes

-
-

## Safety / ops impact

<!-- Domains, secrets, prod access, GitOps, cyborg CRITICAL actions — or "No safety impact." -->

## Test plan

-
-

## Checklist

- [ ] Validation / tests pass for touched areas
- [ ] Docs updated (`bazelisk run //docs:manage-docs -- build --strict` if docs changed)
- [ ] No secrets committed
- [ ] No hardcoded customer domains in Ingress / public URLs
- [ ] Any new flag is declared in `config/flags.yaml` with `default: false`, an owner, an expiry, and one reader, and `bazelisk test //:gate` ran in both the on and off states
