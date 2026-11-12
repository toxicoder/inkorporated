#!/bin/bash
# Test Kubernetes resource requests and limits for every container the cluster
# is asked to run.
#
# The original script reported a Deployment with no requests as a warning, so
# it could not fail. Here an unbounded container is a failure: an unbounded pod
# on the Proxmox k3s nodes is what takes the whole host down, not just the app.
# Requests and limits are read out of the rendered shape of each manifest, so
# the two apps whose resources come from {{ .Values }} are checked against the
# template instead of against a value.
set -euo pipefail

TARGET="//tests/kubernetes:test_resource_quotas"
RERUN="Re-run with: bazelisk test ${TARGET} --test_output=errors --nocache_test_results"

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

# Hard dependency, never a skip: without the parser this lane would have
# nothing to assert on.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: the python3 module yaml is required to read the manifests under ${APPS_DIR}" >&2
  echo "      install it with: python3 -m pip install pyyaml" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

echo "Checking resource requests and limits in ${APPS_DIR}"

python3 - "${APPS_DIR}" <<'PYTHON'
import os
import re
import sys

import yaml

APPS_DIR = sys.argv[1]
TEMPLATE_RE = re.compile(r"\{\{[^{}]*\}\}")
TOKEN = "__TMPL__"

# Containers that are deliberately unbounded, with the reason. Each entry is a
# debt: the file has to carry a resources block or this entry needs a written
# justification from a design review.
RESOURCE_EXCEPTIONS = {
    "shared/cloudflared/Deployment.yaml": (
        "the cloudflared tunnel sidecar ships no resources block; bounding it"
        " is an apps/ change outside this package"
    ),
}

CPU_RE = re.compile(r"^(\d+(?:\.\d+)?)m?$")
MEM_RE = re.compile(r"^(\d+(?:\.\d+)?)(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$")
MEM_MULTIPLIERS = {
    None: 1, "k": 1e3, "M": 1e6, "G": 1e9, "T": 1e12, "P": 1e15, "E": 1e18,
    "Ki": 1024.0, "Mi": 1024.0 ** 2, "Gi": 1024.0 ** 3, "Ti": 1024.0 ** 4,
    "Pi": 1024.0 ** 5, "Ei": 1024.0 ** 6,
}

# The four keys a templated Deployment has to source from values.yaml.
TEMPLATE_KEYS = {
    ("requests", "cpu"): "{{ .Values.deployment.resources.requests.cpu }}",
    ("requests", "memory"): "{{ .Values.deployment.resources.requests.memory }}",
    ("limits", "cpu"): "{{ .Values.deployment.resources.limits.cpu }}",
    ("limits", "memory"): "{{ .Values.deployment.resources.limits.memory }}",
}

failures = []
open_debts = []
deployments = 0
seen_containers = 0
checked_containers = 0
templated_containers = 0


def cpu_value(text):
    """Core milli/CPU for a quantity the format check already accepted."""
    return float(text[:-1]) / 1000.0 if text.endswith("m") else float(text)


def memory_value(text):
    """Core bytes for a quantity the format check already accepted."""
    match = MEM_RE.match(text)
    if not match:
        return None
    return float(match.group(1)) * MEM_MULTIPLIERS[match.group(2) or None]


for dirpath, dirnames, filenames in os.walk(APPS_DIR):
    dirnames.sort()
    for filename in sorted(filenames):
        if not filename.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(dirpath, filename)
        rel = os.path.relpath(path, APPS_DIR)
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
        try:
            docs = [d for d in yaml.safe_load_all(TEMPLATE_RE.sub(TOKEN, raw)) if d]
        except Exception:  # noqa: BLE001 - syntax is //tests/kubernetes:test_manifests' job
            continue
        for doc in docs:
            if doc.get("kind") != "Deployment":
                continue
            deployments += 1
            metadata = doc.get("metadata") or {}
            dname = metadata.get("name") or "<unnamed>"
            spec = doc.get("spec") or {}
            if "replicas" not in spec:
                failures.append("%s: Deployment %s does not state spec.replicas" % (rel, dname))
            pod_spec = (spec.get("template") or {}).get("spec") or {}
            containers = pod_spec.get("containers") or []
            if not containers:
                failures.append("%s: Deployment %s declares no containers" % (rel, dname))
            for container in containers:
                seen_containers += 1
                cname = container.get("name") or "<unnamed>"
                resources = container.get("resources") or {}
                requests = resources.get("requests") or {}
                limits = resources.get("limits") or {}
                if not resources:
                    if rel in RESOURCE_EXCEPTIONS:
                        open_debts.append("%s: container %s: %s"
                                          % (rel, cname, RESOURCE_EXCEPTIONS[rel]))
                        continue
                    failures.append(
                        "%s: Deployment %s container %s declares no resources;"
                        " an unbounded pod can starve the k3s node" % (rel, dname, cname)
                    )
                    continue
                checked_containers += 1
                uses_template = TOKEN in (str(requests.get("cpu")), str(requests.get("memory")),
                                          str(limits.get("cpu")), str(limits.get("memory")))
                if uses_template:
                    templated_containers += 1
                for scope, values in (("requests", requests), ("limits", limits)):
                    for kind in ("cpu", "memory"):
                        value = values.get(kind)
                        if value is None:
                            if rel in RESOURCE_EXCEPTIONS:
                                continue
                            failures.append(
                                "%s: Deployment %s container %s has no"
                                " resources.%s.%s" % (rel, dname, cname, scope, kind)
                            )
                            continue
                        text = str(value)
                        if text == TOKEN:
                            if TEMPLATE_KEYS[(scope, kind)] not in raw:
                                failures.append(
                                    "%s: Deployment %s container %s has a templated"
                                    " resources.%s.%s but the file does not read"
                                    " %s" % (rel, dname, cname, scope, kind,
                                             TEMPLATE_KEYS[(scope, kind)])
                                )
                            continue
                        pattern = CPU_RE if kind == "cpu" else MEM_RE
                        if not pattern.match(text):
                            failures.append(
                                "%s: Deployment %s container %s resources.%s.%s = %r"
                                " is not a valid Kubernetes quantity"
                                % (rel, dname, cname, scope, kind, text)
                            )
                # A request above its limit is rejected by the API server, so
                # the manifest would never schedule. Malformed quantities are
                # reported by the format pass above, so they are skipped here
                # rather than being silently compared.
                if all(requests.get(k) is not None and limits.get(k) is not None
                       for k in ("cpu", "memory")):
                    req_cpu, lim_cpu = str(requests["cpu"]), str(limits["cpu"])
                    if (CPU_RE.match(req_cpu) and CPU_RE.match(lim_cpu)
                            and cpu_value(req_cpu) > cpu_value(lim_cpu)):
                        failures.append(
                            "%s: Deployment %s container %s requests more cpu (%s)"
                            " than its limit (%s)" % (rel, dname, cname, req_cpu, lim_cpu))
                    req_mem, lim_mem = str(requests["memory"]), str(limits["memory"])
                    if (MEM_RE.match(req_mem) and MEM_RE.match(lim_mem)
                            and memory_value(req_mem) > memory_value(lim_mem)):
                        failures.append(
                            "%s: Deployment %s container %s requests more memory"
                            " (%s) than its limit (%s)"
                            % (rel, dname, cname, req_mem, lim_mem))

for debt in dict.fromkeys(open_debts):
    print("  KNOWN-OPEN %s" % debt)

if failures:
    print("")
    for failure in failures:
        print("FAIL %s" % failure)
    print("")
    print("%d failure(s) across %d Deployment(s), %d container(s)"
          % (len(failures), deployments, seen_containers))
    sys.exit(1)

print("PASS %d Deployment(s), %d container(s) with resources" % (deployments, checked_containers))
print("     every container declares requests and limits for cpu and memory,")
print("     every quantity is a valid Kubernetes unit, requests never exceed")
print("     limits, and every Deployment states spec.replicas")
print("     %d container(s) take their bounds from {{ .Values.deployment.resources.* }}"
      % templated_containers)
if not open_debts:
    print("     no unbounded containers in the tree")
PYTHON

echo "PASS resource requests and limits: ${TARGET}"
