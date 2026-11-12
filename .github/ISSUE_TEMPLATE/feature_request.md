---
name: Feature request
description: Propose new functionality, a new gate, or a change to an existing workflow.
labels: ["enhancement"]
body:
  - type: input
    id: summary
    attributes:
      label: One-line summary
      description: What you want to be possible, in the shape of a commit summary.
      placeholder: add a gate that fails a cyborg YAML missing allowed_invokers
    validations:
      required: true
  - type: textarea
    id: problem
    attributes:
      label: What you cannot do today
      description: >-
        The gap as you hit it, and what you do instead. Name the command, target, or page
        you were at when you hit it, and link the docs page that should answer the
        question and does not.
      placeholder: |
        I have to eyeball 205 files in cyborgs/ to find a persona without an invoker list.
    validations:
      required: true
  - type: textarea
    id: proposal
    attributes:
      label: What you would like to happen
      description: >-
        The behavior, stated as something a reviewer can check. Name the gate it belongs to
        (`bazelisk test //:gate`, `//:fast`, a lane of its own) and say whether it must be
        hermetic or needs a host tool, a cluster, network egress, or the docs tree.
      placeholder: >-
        A repo_sh_test from //build:defs.bzl over //cyborgs:personas that lists every persona
        whose allowed_invokers is empty, tagged gate so //:gate runs it.
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives you considered
      description: Other designs, and why you did not pick them. Leave blank if none.
    validations:
      required: false
  - type: textarea
    id: safety-and-flags
    attributes:
      label: Safety surface and flag
      description: >-
        Does this touch a non-negotiable invariant (secrets in git, hardcoded customer
        domains, push/PR/tag without an explicit request, cyborg CRITICAL side effects,
        the domain or secret scanners)? If the work is not finished in one pull request,
        name the key you would declare in `config/flags.yaml` with `default: false`, an
        owner, an expiry, and one reader, and confirm `bazelisk test //:gate` runs in both
        the on and off states. Otherwise write "No flag".
    validations:
      required: true
---
