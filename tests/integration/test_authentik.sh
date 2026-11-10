#!/bin/bash
# Test Authentik integration.
#
# Two halves. The manifest half proves that what ArgoCD would deploy is the
# Authentik this repository claims to run: the server, worker and outpost
# Deployments, their Services, and a PodDisruptionBudget that still allows a
# node drain. The live half asks the cluster whether that is what is actually
# running: the objects exist, the pods are ready, the images match the
# manifests, and the Service has endpoints.
#
# The live half needs a reachable cluster, so //tests/integration:test_authentik
# is tagged host + manual. There is no path through this script that reports
# success without having asked the cluster.
set -euo pipefail

TARGET="//tests/integration:test_authentik"
RERUN="Re-run with: bazelisk test ${TARGET} --test_output=errors --nocache_test_results"
NAMESPACE="authentik"

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
  echo "FAIL: python3 is a required //:doctor tool and is missing; it reads the Authentik manifests" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: apt-get install -y python3" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# Hard dependency, never a skip.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: the python3 module yaml is required to read the Authentik manifests" >&2
  echo "      install it with: python3 -m pip install pyyaml" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# kubectl is the host tool this lane talks to the cluster with (//:doctor
# tracks it). Under CI=1 / REQUIRE_LINT_TOOLS=1, which this target exports
# through strict = True, a missing kubectl is fatal with its install command:
# an integration test that could not reach the API server has not integrated
# anything and must say so.
if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl is required by ${TARGET} to reach the cluster" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: curl -fsSL https://dl.k8s.io/release/v1.30.14/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl" >&2
  echo "      point it at the cluster: export KUBECONFIG=/path/to/k3s.yaml, then" >&2
  echo "      check with: kubectl cluster-info" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

echo "Authentik integration: manifests in ${APPS_DIR}/shared/${NAMESPACE}, cluster via $(command -v kubectl)"

python3 - "${APPS_DIR}" "$(command -v kubectl)" "${NAMESPACE}" "${TARGET}" <<'PYTHON'
import json
import os
import re
import subprocess
import sys

import yaml

APPS_DIR, KUBECTL, NAMESPACE, TARGET = sys.argv[1:5]
RERUN = "Re-run with: bazelisk test %s --test_output=errors --nocache_test_results" % TARGET
AUTHENTIK_DIR = os.path.join(APPS_DIR, "shared", NAMESPACE)
PLACEHOLDER_RE = re.compile(r"\{\{[^{}]*\}\}")

# What the repository promises to run. A rename in apps/ has to be said here
# too, which is the point of writing it down.
EXPECTED_DEPLOYMENTS = {"authentik-server": 3, "authentik-worker": 1, "authentik-outpost": 1}
EXPECTED_SERVICES = {"authentik-server": 9000, "authentik-outpost": 9000}
EXPECTED_PDB = "authentik-server-pdb"

failures = []
checks = []


def record(text):
    checks.append(text)


def fail(text):
    failures.append(text)


def load(path):
    with open(path, encoding="utf-8") as handle:
        body = PLACEHOLDER_RE.sub("__TMPL__", handle.read())
    return [doc for doc in yaml.safe_load_all(body) if doc]


def name_of(doc):
    return (doc.get("metadata") or {}).get("name") or "<unnamed>"


def kubectl(*arguments):
    """Run kubectl, returning (ok, stdout-or-error) without touching the tree."""
    result = subprocess.run([KUBECTL] + list(arguments), capture_output=True, text=True,
                            timeout=120, check=False)
    if result.returncode != 0:
        return False, (result.stderr or result.stdout or "kubectl failed").strip()
    return True, result.stdout


if not os.path.isdir(AUTHENTIK_DIR):
    print("FAIL no apps/shared/%s directory; the Authentik manifests are gone" % NAMESPACE)
    sys.exit(1)

# --------------------------------------------------------------------------
# Phase 1: the manifests describe a working Authentik.
# --------------------------------------------------------------------------
documents = []
for filename in sorted(os.listdir(AUTHENTIK_DIR)):
    if not filename.endswith((".yaml", ".yml")):
        continue
    documents += [(filename, doc) for doc in load(os.path.join(AUTHENTIK_DIR, filename))]

deployments = {}
services = {}
pdbs = {}
for filename, doc in documents:
    kind = doc.get("kind")
    if kind == "Deployment":
        deployments.setdefault(name_of(doc), (filename, doc))
    elif kind == "Service":
        services.setdefault(name_of(doc), (filename, doc))
    elif kind == "PodDisruptionBudget":
        pdbs.setdefault(name_of(doc), []).append((filename, doc))

for wanted, replicas in sorted(EXPECTED_DEPLOYMENTS.items()):
    if wanted not in deployments:
        fail("no Deployment %s in apps/shared/%s; Authentik cannot start" % (wanted, NAMESPACE))
        continue
    filename, doc = deployments[wanted]
    spec = doc.get("spec") or {}
    if (doc.get("metadata") or {}).get("namespace") != NAMESPACE:
        fail("%s: Deployment %s is not in namespace %s" % (filename, wanted, NAMESPACE))
    if spec.get("replicas") != replicas:
        fail("%s: Deployment %s declares %r replicas, expected %d"
             % (filename, wanted, spec.get("replicas"), replicas))
    selector = ((spec.get("selector") or {}).get("matchLabels") or {})
    template = (spec.get("template") or {})
    labels = (template.get("metadata") or {}).get("labels") or {}
    if not selector or any(labels.get(k) != v for k, v in selector.items()):
        fail("%s: Deployment %s selector %s does not match pod labels %s"
             % (filename, wanted, selector, labels))
    containers = (template.get("spec") or {}).get("containers") or []
    if not containers:
        fail("%s: Deployment %s has no containers" % (filename, wanted))
        continue
    if not all(c.get("image") for c in containers):
        fail("%s: Deployment %s has a container with no image" % (filename, wanted))
record("Deployments %s present with the promised replica counts"
       % ", ".join(sorted(EXPECTED_DEPLOYMENTS)))

# server and worker are the same upstream image; a tag that drifts between
# them is how a version skew starts.
server = deployments.get("authentik-server")
worker = deployments.get("authentik-worker")
if server and worker:
    server_images = {c.get("image") for c in
                     (((server[1].get("spec") or {}).get("template") or {}).get("spec") or {})
                     .get("containers") or []}
    worker_images = {c.get("image") for c in
                     (((worker[1].get("spec") or {}).get("template") or {}).get("spec") or {})
                     .get("containers") or []}
    if server_images != worker_images:
        fail("authentik-server %s and authentik-worker %s run different images;"
             " they are the same upstream image" % (server_images, worker_images))
    else:
        record("authentik-server and authentik-worker pin the same image %s"
               % ", ".join(sorted(str(i) for i in server_images)))

for wanted, port in sorted(EXPECTED_SERVICES.items()):
    if wanted not in services:
        fail("no Service %s in apps/shared/%s; nothing can reach %s" % (wanted, NAMESPACE, wanted))
        continue
    filename, doc = services[wanted]
    spec = doc.get("spec") or {}
    selector = spec.get("selector") or {}
    deployment = deployments.get(wanted)
    if not deployment:
        continue
    labels = ((((deployment[1].get("spec") or {}).get("template") or {})
               .get("metadata") or {}).get("labels") or {})
    if not selector or any(labels.get(k) != v for k, v in selector.items()):
        fail("%s: Service %s selector %s matches no pod of Deployment %s %s"
             % (filename, wanted, selector, wanted, labels))
    ports = spec.get("ports") or []
    if not any(p.get("port") == port for p in ports):
        fail("%s: Service %s does not expose port %d (has %s)"
             % (filename, wanted, port, [p.get("port") for p in ports]))
    container_ports = {p.get("containerPort") for d in deployments.values()
                       for c in ((((d[1].get("spec") or {}).get("template") or {})
                                  .get("spec") or {}).get("containers") or [])
                       for p in c.get("ports") or []}
    for entry in ports:
        target = entry.get("targetPort", entry.get("port"))
        if isinstance(target, int) and target not in container_ports:
            fail("%s: Service %s targets %s, which no Authentik container listens on %s"
                 % (filename, wanted, target, sorted(p for p in container_ports if p)))
record("Services %s select their Deployment pods and expose %s"
       % (", ".join(sorted(EXPECTED_SERVICES)),
          ", ".join("%s:%d" % (n, p) for n, p in sorted(EXPECTED_SERVICES.items()))))

if EXPECTED_PDB not in pdbs:
    fail("no PodDisruptionBudget %s; a node drain can take Authentik down entirely"
         % EXPECTED_PDB)
else:
    server_labels = ((((deployments.get("authentik-server", ("", {}))[1].get("spec") or {})
                       .get("template") or {}).get("metadata") or {}).get("labels") or {})
    server_replicas = EXPECTED_DEPLOYMENTS.get("authentik-server", 0)
    for filename, doc in pdbs[EXPECTED_PDB]:
        spec = doc.get("spec") or {}
        selector = ((spec.get("selector") or {}).get("matchLabels") or {})
        if not selector or any(server_labels.get(k) != v for k, v in selector.items()):
            fail("%s: PodDisruptionBudget %s selector %s guards no authentik-server pod %s"
                 % (filename, EXPECTED_PDB, selector, server_labels))
        min_available = spec.get("minAvailable")
        if not isinstance(min_available, int) or min_available < 1 or min_available >= server_replicas:
            fail("%s: PodDisruptionBudget %s sets minAvailable %r; with %d replicas it"
                 " must be between 1 and %d or drains block forever"
                 % (filename, EXPECTED_PDB, min_available, server_replicas, server_replicas - 1))
        else:
            record("PodDisruptionBudget %s in %s keeps %d of %d authentik-server pods"
                   " through a drain" % (EXPECTED_PDB, filename, min_available, server_replicas))

# --------------------------------------------------------------------------
# Phase 2: the cluster. No cluster means no pass: this lane exists to ask it.
# --------------------------------------------------------------------------
ok, detail = kubectl("version", "--request-timeout=15s")
if not ok:
    print("")
    for check in checks:
        print("     %s" % check)
    print("FAIL the cluster is not reachable: %s" % detail.splitlines()[0])
    print("     export KUBECONFIG so kubectl points at the k3s cluster, then %s" % RERUN)
    for failure in failures:
        print("FAIL manifest: %s" % failure)
    sys.exit(1)

live = {}
for kind, wanted in ([("deployment", name) for name in sorted(EXPECTED_DEPLOYMENTS)]
                     + [("service", name) for name in sorted(EXPECTED_SERVICES)]
                     + [("poddisruptionbudget", EXPECTED_PDB), ("namespace", NAMESPACE)]):
    ok, output = kubectl("get", kind, wanted, "-n", NAMESPACE, "-o", "json")
    if not ok:
        fail("cluster has no %s/%s in %s: %s"
             % (kind, wanted, NAMESPACE, output.splitlines()[0] if output else "no output"))
        continue
    import json
    live[kind + "/" + wanted] = json.loads(output)
record("cluster answers for namespace %s and every expected object" % NAMESPACE)

for wanted, replicas in sorted(EXPECTED_DEPLOYMENTS.items()):
    deployment = live.get("deployment/" + wanted)
    if not deployment:
        continue
    status = deployment.get("status") or {}
    ready = status.get("readyReplicas", 0)
    if ready != replicas:
        fail("cluster: Deployment %s has %s of %d replicas ready" % (wanted, ready, replicas))
    if (deployment.get("spec") or {}).get("replicas") != replicas:
        fail("cluster: Deployment %s runs %r replicas, the manifest says %d"
             % (wanted, (deployment.get("spec") or {}).get("replicas"), replicas))
    live_images = {c.get("image") for c in
                   (((deployment.get("spec") or {}).get("template") or {})
                    .get("spec") or {}).get("containers") or []}
    manifest = deployments.get(wanted)
    if manifest:
        want_images = {c.get("image") for c in
                       ((((manifest[1].get("spec") or {}).get("template") or {})
                          .get("spec") or {}).get("containers") or [])}
        if live_images != want_images:
            fail("cluster: Deployment %s runs %s but apps/ declares %s"
                 % (wanted, sorted(live_images), sorted(want_images)))
record("live deployments match apps/shared/%s on replicas and image" % NAMESPACE)

for wanted, port in sorted(EXPECTED_SERVICES.items()):
    service = live.get("service/" + wanted)
    if not service:
        continue
    ports = [p.get("port") for p in (service.get("spec") or {}).get("ports") or []]
    if port not in ports:
        fail("cluster: Service %s exposes %s, expected %d" % (wanted, ports, port))
    ok, output = kubectl("get", "endpoints", wanted, "-n", NAMESPACE, "-o", "json")
    if not ok:
        fail("cluster: no endpoints object for Service %s: %s"
             % (wanted, output.splitlines()[0] if output else "no output"))
        continue
    import json
    subsets = json.loads(output).get("subsets") or []
    addresses = [a for subset in subsets for a in subset.get("addresses") or []]
    if not addresses:
        fail("cluster: Service %s has no ready endpoints; Authentik is unreachable on"
             " port %d" % (wanted, port))
record("live services %s have ready endpoints" % ", ".join(sorted(EXPECTED_SERVICES)))

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
if failures:
    print("")
    for failure in failures:
        print("FAIL %s" % failure)
    print("")
    print("%d failure(s); %d check(s) passed" % (len(failures), len(checks)))
    sys.exit(1)

print("PASS Authentik integration against the cluster kubectl points at")
for text in checks:
    print("     %s" % text)
PYTHON

echo "PASS Authentik integration: ${TARGET}"
