---
name: Bug report
description: Report a failing gate, a wrong manifest, or behavior that does not match the docs.
labels: ["bug", "triage"]
body:
  - type: input
    id: summary
    attributes:
      label: One-line summary
      description: What broke, in the shape of a commit summary.
      placeholder: validate_domain_config fails on an ApplicationSet that templates the domain
    validations:
      required: true
  - type: textarea
    id: repro-command
    attributes:
      label: Exact reproduction command
      description: >-
        The full command, verbatim, as you typed it, from the repository root. One
        command per line. If a flag changes the outcome, give both the plain form and
        the exported form (`FEATURE_EXAMPLE=1 bazelisk test //:gate`).
      placeholder: |
        bazelisk test //:validate_domain_config
        ./validate_domain_config.sh
    validations:
      required: true
  - type: textarea
    id: repro-output
    attributes:
      label: Verbatim output
      description: >-
        Paste the real output; do not summarize, paraphrase, or trim it. Keep the
        failing target name, the exit status, and the first error line. Redact any
        secret rather than pasting it - no token, key, or `.devcontainer/.env` value
        belongs in an issue.
      render: text
      placeholder: |
        Target //:validate_domain_config failed
        ...
        FAIL: apps/environments/prod/ingress.yaml: hardcoded domain
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: What you expected instead
      description: The behavior the docs or the code promise, with the page or file that says so.
      placeholder: The lane passes, because the Ingress uses {{DOMAIN_BASE}}.
    validations:
      required: true
  - type: input
    id: environment
    attributes:
      label: Ref, digest, and where you ran it
      description: >-
        Output of `git rev-parse --short HEAD` (or the image digest), plus devcontainer,
        host, or CI runner, and the `bazelisk --version` line if a build lane is involved.
      placeholder: abc1234 on trunk, devcontainer, Bazel 9.x
    validations:
      required: true
  - type: textarea
    id: safety-surface
    attributes:
      label: Safety invariants it touches
      description: >-
        Say which of these the bug touches, or write "None": secrets in git; hardcoded
        customer domains in Ingress; a push, PR, or tag made without an explicit request;
        a cyborg CRITICAL side effect without human approval; a weakened domain or secret
        scanner. Name the area if you know it (`apps/`, `config/`, `cyborgs/`,
        `infrastructure/`, `docs/`, CI).
    validations:
      required: true
---
