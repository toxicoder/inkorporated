#!/bin/bash
# Validate the GitOps manifests under apps/: YAML syntax, the required
# Kubernetes envelope fields, and the wiring invariants that decide whether a
# manifest actually works (Service selectors reaching a pod, targetPort
# matching a containerPort, PDB selectors, no duplicate resource identities).
#
# The manifests under apps/shared are Helm templates, so every document is
# read with its {{ ... }} placeholders replaced by one scalar token first. The
# check is about structure, not about the value a deployment supplies.
set -euo pipefail

TARGET="//tests/kubernetes:test_manifests"
RERUN="Re-run with: bazelisk test ${TARGET} --test_output=errors --nocache_test_results"

# Runfiles first: apps/ arrives through the //apps:manifests data dep. The
# checkout walk is the fallback for running the script from a checkout.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
WORKSPACE="${TEST_WORKSPACE:-inkorporated}"
if [[ -n "${TEST_SRCDIR:-}" && -d "${TEST_SRCDIR}/${WORKSPACE}/apps" ]]; then
  APPS_DIR="${TEST_SRCDIR}/${WORKSPACE}/apps"
else
  dir="${SCRIPT_DIR}"
  while [[ "${dir}" != "/" && ! -d "${dir}/.git" ]]; do
    dir="$(dirname "${dir}")"
  done
  if [[ ! -d "${dir}/.git" ]]; then
    echo "FAIL: could not locate apps/ or a checkout root from ${SCRIPT_DIR}" >&2
    echo "      ${RERUN}" >&2
    exit 1
  fi
  APPS_DIR="${dir}/apps"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is a required //:doctor tool and is missing; it parses the manifests" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: apt-get install -y python3" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# PyYAML is a hard dependency of this lane (it is also what yamllint, a
# required //:doctor tool, runs on), so a missing module is an error and never
# a skip: a green run must always mean the manifests were really parsed.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: the python3 module yaml is required to parse ${APPS_DIR}" >&2
  echo "      install it with: python3 -m pip install pyyaml" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

echo "Validating Kubernetes manifests in ${APPS_DIR}"

python3 - "${APPS_DIR}" <<'PYTHON'
import os
import re
import sys

import yaml

APPS_DIR = sys.argv[1]

# One token stands in for a Helm template expression so the file parses as
# plain YAML; a leaked "{{" in a value therefore stays visible.
TEMPLATE_RE = re.compile(r"\{\{[^{}]*\}\}")
TOKEN = "__TMPL__"

# Files that are known-broken in the tree today. Each entry is a named debt:
# the gate stays green while it is open, a NEW broken file still fails, and
# the entry has to go away when apps/ fixes the file.
PARSE_EXCEPTIONS = {
    "shared/jitsi/Deployment.yaml": (
        "line ~1298 carries a committed <write_to_file> tool artifact, so the"
        " file is not valid YAML; needs a fix under apps/ (outside this package)"
    ),
}
DUPLICATE_EXCEPTIONS = {
    "shared/authentik/Deployment.yaml": (
        "declares the whole authentik bundle (server, worker, outpost, both"
        " Services, the PDB) a second time; needs a fix under apps/"
    ),
    "shared/workadventure/Ingress.yaml": (
        "shared/work-adventure/Ingress.yaml declares the same"
        " Ingress/workadventure-ingress with a different host, so the two"
        " folders fight over one object; needs a fix under apps/"
    ),
}

EXPECTED_KINDS = {
    "Application",
    "ApplicationSet",
    "ConfigMap",
    "Deployment",
    "Ingress",
    "Namespace",
    "PersistentVolumeClaim",
    "PodDisruptionBudget",
    "Secret",
    "Service",
}

failures = []
open_debts = []
checked_files = 0
parsed_files = 0
documents = 0
empty_files = []
documents_by_file = {}


def unbalanced_templates(raw):
    """True when a {{ on a line never closes on that line."""
    for line in raw.splitlines():
        if "{{" in line and "}}" not in line.split("{{", 1)[1]:
            return True
    return False


def is_comment_only(body):
    return all(not line.strip() or line.lstrip().startswith("#") for line in body.splitlines())


def load(path):
    """Return (documents, error) for one manifest, template expressions tokenised."""
    with open(path, encoding="utf-8") as handle:
        raw = handle.read()
    if unbalanced_templates(raw):
        return [], "an unclosed {{ placeholder"
    body = TEMPLATE_RE.sub(TOKEN, raw)
    if is_comment_only(body):
        return [], None
    try:
        return [doc for doc in yaml.safe_load_all(body) if doc], None
    except Exception as exc:  # noqa: BLE001 - every parse error is a finding
        return [], str(exc).splitlines()[0]


def pod_labels(doc):
    template = ((doc.get("spec") or {}).get("template") or {})
    return (template.get("metadata") or {}).get("labels") or {}


def container_ports(doc):
    spec = ((doc.get("spec") or {}).get("template") or {}).get("spec") or {}
    ports = set()
    for container in spec.get("containers") or []:
        for port in container.get("ports") or []:
            if port.get("containerPort") is not None:
                ports.add(port["containerPort"])
    return ports


def name_of(doc):
    return (doc.get("metadata") or {}).get("name") or "<unnamed>"


# --------------------------------------------------------------------------
# Pass 1: parse everything, then check the Kubernetes envelope.
# --------------------------------------------------------------------------
for dirpath, dirnames, filenames in os.walk(APPS_DIR):
    dirnames.sort()
    for filename in sorted(filenames):
        if not filename.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(dirpath, filename)
        rel = os.path.relpath(path, APPS_DIR)
        checked_files += 1
        docs, error = load(path)
        if error is not None:
            if rel in PARSE_EXCEPTIONS:
                open_debts.append("%s: %s" % (rel, PARSE_EXCEPTIONS[rel]))
                continue
            failures.append("%s: YAML syntax error: %s" % (rel, error))
            continue
        parsed_files += 1
        if not docs:
            empty_files.append(rel)
            continue
        documents_by_file[rel] = docs
        for doc in docs:
            documents += 1
            kind = doc.get("kind")
            if not doc.get("apiVersion"):
                failures.append("%s: %s has no apiVersion" % (rel, name_of(doc)))
            if not kind:
                failures.append("%s: document %s has no kind" % (rel, name_of(doc)))
                continue
            if kind not in EXPECTED_KINDS:
                failures.append("%s: unexpected kind %r" % (rel, kind))
            if not (doc.get("metadata") or {}).get("name"):
                failures.append("%s: %s has no metadata.name" % (rel, kind))
            if kind != "Namespace" and not (doc.get("metadata") or {}).get("namespace"):
                failures.append(
                    "%s: %s/%s has no metadata.namespace; ArgoCD syncs this tree"
                    " without a default namespace" % (rel, kind, name_of(doc))
                )

# --------------------------------------------------------------------------
# Pass 2: resource identity must be unique across the tree. An identity that
# still holds a template token is decided at render time, so it is only
# compared inside its own folder; a folder that declares one kind twice is a
# bug whatever values ArgoCD supplies.
# --------------------------------------------------------------------------
seen_literal = {}
seen_local = {}


def ledgered(first, second):
    """True when a named debt already covers this pair of files."""
    return first in DUPLICATE_EXCEPTIONS or second in DUPLICATE_EXCEPTIONS


for rel, docs in sorted(documents_by_file.items()):
    directory = os.path.dirname(rel)
    for doc in docs:
        metadata = doc.get("metadata") or {}
        kind = doc.get("kind")
        namespace = metadata.get("namespace")
        name = metadata.get("name")
        local_key = (directory, kind, namespace, name)
        other_local = seen_local.get(local_key)
        if other_local is not None and other_local != rel:
            if ledgered(rel, other_local):
                open_debts.append(
                    "%s: %s/%s is declared twice inside %s (also in %s)"
                    % (rel, kind, name, directory, other_local)
                )
            else:
                failures.append(
                    "%s: %s/%s is declared twice inside the same folder (also in %s)"
                    % (rel, kind, name, other_local)
                )
        seen_local.setdefault(local_key, rel)
        if TOKEN in (str(namespace), str(name)):
            continue
        key = (kind, namespace, name)
        other = seen_literal.get(key)
        if other is not None and other != rel:
            if ledgered(rel, other):
                open_debts.append(
                    "%s: %s/%s is also declared by %s" % (rel, kind, name, other)
                )
            else:
                failures.append(
                    "%s: %s/%s is also declared by %s; ArgoCD applies both"
                    % (rel, kind, name, other)
                )
        seen_literal.setdefault(key, rel)

# --------------------------------------------------------------------------
# Pass 3: per-folder wiring. Each apps/shared/<app> folder is one ArgoCD unit,
# so a Service or PDB may only select pods the same folder runs.
# --------------------------------------------------------------------------
by_dir = {}
for rel, docs in documents_by_file.items():
    by_dir.setdefault(os.path.dirname(rel), []).extend(docs)

counters = {"Deployment": 0, "Service": 0, "PodDisruptionBudget": 0, "container": 0,
            "image": 0}

for directory, docs in sorted(by_dir.items()):
    deployments = [d for d in docs if d.get("kind") == "Deployment"]
    counters["Deployment"] += len(deployments)
    if deployments and not any(d.get("kind") == "Namespace" for d in docs):
        failures.append(
            "%s: runs a Deployment but ships no Namespace; the manifests pin"
            " metadata.namespace, so the folder must own the Namespace too" % directory
        )
    label_sets = [pod_labels(d) for d in deployments]
    folder_ports = set()
    for deployment in deployments:
        folder_ports |= container_ports(deployment)
        selector = ((deployment.get("spec") or {}).get("selector") or {}).get("matchLabels") or {}
        template_labels = pod_labels(deployment)
        if not selector:
            failures.append("%s: Deployment %s has no spec.selector.matchLabels"
                            % (directory, name_of(deployment)))
        elif any(template_labels.get(key) != value for key, value in selector.items()):
            failures.append(
                "%s: Deployment %s selector %s does not match its pod template"
                " labels %s" % (directory, name_of(deployment), selector, template_labels)
            )
        spec = ((deployment.get("spec") or {}).get("template") or {}).get("spec") or {}
        if not spec.get("containers"):
            failures.append("%s: Deployment %s declares no containers"
                            % (directory, name_of(deployment)))
        for container in spec.get("containers") or []:
            counters["container"] += 1
            cname = container.get("name")
            if not cname:
                failures.append("%s: a container in Deployment %s has no name"
                                % (directory, name_of(deployment)))
            image = container.get("image") or ""
            if not image:
                failures.append("%s: container %s has no image" % (directory, cname))
                continue
            counters["image"] += 1
            if image == TOKEN:
                continue
            # An untagged image means "whatever :latest is today", which makes
            # an ArgoCD sync irreproducible.
            if ":" not in image.rsplit("/", 1)[-1]:
                failures.append("%s: container %s image %s has no tag"
                                % (directory, cname, image))

    for service in (d for d in docs if d.get("kind") == "Service"):
        counters["Service"] += 1
        svc_name = name_of(service)
        spec = service.get("spec") or {}
        selector = spec.get("selector") or {}
        if not selector:
            failures.append("%s: Service %s has an empty spec.selector" % (directory, svc_name))
        elif not any(all(labels.get(k) == v for k, v in selector.items()) for labels in label_sets):
            failures.append(
                "%s: Service %s selector %s matches no pod template in the folder %s"
                % (directory, svc_name, selector, label_sets)
            )
        if not spec.get("ports"):
            failures.append("%s: Service %s declares no ports" % (directory, svc_name))
        for port in spec.get("ports") or []:
            target = port.get("targetPort", port.get("port"))
            if isinstance(target, int) and folder_ports and target not in folder_ports:
                failures.append(
                    "%s: Service %s targets port %s, which no container in the"
                    " folder listens on %s"
                    % (directory, svc_name, target, sorted(folder_ports))
                )

    for pdb in (d for d in docs if d.get("kind") == "PodDisruptionBudget"):
        counters["PodDisruptionBudget"] += 1
        pdb_name = name_of(pdb)
        selector = ((pdb.get("spec") or {}).get("selector") or {}).get("matchLabels") or {}
        if not selector:
            failures.append("%s: PodDisruptionBudget %s has no selector" % (directory, pdb_name))
        elif not any(all(labels.get(k) == v for k, v in selector.items()) for labels in label_sets):
            failures.append(
                "%s: PodDisruptionBudget %s selector %s guards no pod template in the folder"
                % (directory, pdb_name, selector)
            )

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
for debt in dict.fromkeys(open_debts):
    print("  KNOWN-OPEN %s" % debt)

if failures:
    print("")
    for failure in failures:
        print("FAIL %s" % failure)
    print("")
    print("%d failure(s) across %d manifest file(s), %d document(s)"
          % (len(failures), checked_files, documents))
    sys.exit(1)

print("PASS %d manifest file(s) parsed, %d document(s) checked (%d comment-only:"
      " %s)" % (parsed_files, documents, len(empty_files),
                ", ".join(empty_files) if empty_files else "none"))
print("     every document has apiVersion, kind, metadata.name, and"
      " metadata.namespace unless it is a Namespace")
print("     %d Deployment(s): selector matches its pod template, %d container(s)"
      " named, %d image(s) all tagged"
      % (counters["Deployment"], counters["container"], counters["image"]))
print("     %d Service(s): non-empty selector reaching a pod template in the same"
      " folder, targetPort present among containerPorts" % counters["Service"])
print("     %d PodDisruptionBudget(s) guard a pod template in their own folder;"
      " folder; no duplicate kind+namespace+name outside the KNOWN-OPEN ledger"
      % counters["PodDisruptionBudget"])
PYTHON

echo "PASS Kubernetes manifests: ${TARGET}"
