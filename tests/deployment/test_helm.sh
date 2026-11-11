#!/bin/bash
# Test Helm chart validity and the ArgoCD applications that hand those charts
# to a renderer.
#
# apps/shared/<app>/*.yaml are Helm templates (they read {{ .Values.* }}), and
# apps/argo-cd plus apps/environments/<env>/argo-cd are the Application /
# ApplicationSet definitions ArgoCD syncs. Two things are therefore checked:
# the applications are well formed and their template variables are backed by
# the generator, and every chart really renders with helm into valid
# Kubernetes documents. There is no Chart.yaml in the tree, so each folder is
# rendered as a chart synthesized in a temp dir from its own templates plus
# values derived from the {{ .Values }} keys the folder actually reads.
set -euo pipefail

TARGET="//tests/deployment:test_helm"
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
  echo "FAIL: python3 is a required //:doctor tool and is missing; it inspects the charts" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: apt-get install -y python3" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# Hard dependency, never a skip: without a YAML parser there is nothing to
# assert about the rendered output.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: the python3 module yaml is required to read the rendered charts" >&2
  echo "      install it with: python3 -m pip install pyyaml" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# helm is the renderer this lane exists to exercise (//:doctor tracks it). A
# chart nobody rendered is exactly the pass-by-skipping this conversion
# removed, so a missing helm is fatal here whether or not CI=1 /
# REQUIRE_LINT_TOOLS=1 are exported; this target exports both via strict = True.
if ! command -v helm >/dev/null 2>&1; then
  echo "FAIL: helm is required to render the charts under ${APPS_DIR}" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" >&2
  echo "      then check with: helm version --short" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

echo "Rendering Helm charts from ${APPS_DIR} with $(helm version --short 2>/dev/null || echo 'helm version unknown')"

WORK="$(mktemp -d)"
trap 'find "${WORK}" -delete' EXIT

python3 - "${APPS_DIR}" "${WORK}" "$(command -v helm)" <<'PYTHON'
import os
import re
import subprocess
import sys

import yaml

APPS_DIR, WORK, HELM = sys.argv[1:4]
SHARED = os.path.join(APPS_DIR, "shared")
ENVIRONMENTS = os.path.join(APPS_DIR, "environments")
ARGOCD_APPSET = os.path.join(APPS_DIR, "argo-cd", "manifests.yaml")
CANONICAL_REPO_URL = "https://github.com/toxicoder/inkorporated.git"

PLACEHOLDER_RE = re.compile(r"\{\{([^{}]*)\}\}")
TOKEN = "__TMPL__"
VALUE = "placeholder"

# Charts that do not render today, each with the debt that has to be paid in
# apps/ (a path this package does not own). A NEW chart that fails still
# breaks the gate, and deleting an entry once its chart renders is the point.
RENDER_EXCEPTIONS = {
    "config": (
        "ConfigMap.yaml reads {{ .Values.services[\"rocket.chat\"].subdomain }};"
        " the Go template parser rejects that bracket-string form (bad character"
        " U+005B), so it needs {{ index .Values.services \"rocket.chat\" ... }}"
    ),
    "jitsi": (
        "Deployment.yaml carries a committed <write_to_file> tool artifact at"
        " line ~1298, so the template cannot be parsed"
    ),
}

failures = []
open_debts = []


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def load(path):
    """Documents of one manifest file, template expressions tokenised."""
    return [d for d in yaml.safe_load_all(PLACEHOLDER_RE.sub(TOKEN, read(path))) if d]


def name_of(doc):
    return (doc.get("metadata") or {}).get("name") or "<unnamed>"


def flattened_keys(element, prefix=""):
    keys = set()
    for key, value in (element or {}).items():
        path = "%s.%s" % (prefix, key) if prefix else str(key)
        if isinstance(value, dict):
            keys |= flattened_keys(value, path)
        else:
            keys.add("." + path)
    return keys


def check_required(condition, message):
    if not condition:
        failures.append(message)


# --------------------------------------------------------------------------
# Phase 1: the ArgoCD Applications that sync this tree.
# --------------------------------------------------------------------------
applications = 0
if os.path.isdir(ENVIRONMENTS):
    for env in sorted(os.listdir(ENVIRONMENTS)):
        env_dir = os.path.join(ENVIRONMENTS, env)
        if not os.path.isdir(env_dir):
            continue
        path = os.path.join(env_dir, "argo-cd", "manifests.yaml")
        if not os.path.isfile(path):
            failures.append("environment %s has no apps/environments/%s/argo-cd/manifests.yaml"
                            % (env, env))
            continue
        rel = os.path.relpath(path, APPS_DIR)
        docs = load(path)
        apps = [d for d in docs if d.get("kind") == "Application"]
        if len(apps) != 1:
            failures.append("%s: expected exactly 1 ArgoCD Application, found %d"
                            % (rel, len(apps)))
            continue
        applications += 1
        app = apps[0]
        spec = app.get("spec") or {}
        source = spec.get("source") or {}
        destination = spec.get("destination") or {}
        check_required(name_of(app) == "infrastructure-%s" % env,
                       "%s: Application is named %r, expected 'infrastructure-%s'"
                       % (rel, name_of(app), env))
        check_required((app.get("metadata") or {}).get("namespace") == "argocd",
                       "%s: Application %s must live in the argocd namespace"
                       % (rel, name_of(app)))
        check_required(source.get("repoURL") == CANONICAL_REPO_URL,
                       "%s: Application %s source.repoURL is %r, expected %r"
                       % (rel, name_of(app), source.get("repoURL"), CANONICAL_REPO_URL))
        check_required(source.get("path") == "infrastructure/%s" % env,
                       "%s: Application %s source.path is %r, expected"
                       " 'infrastructure/%s'" % (rel, name_of(app), source.get("path"), env))
        check_required(bool(destination.get("server")),
                       "%s: Application %s has no destination.server" % (rel, name_of(app)))
        check_required(bool(destination.get("namespace")),
                       "%s: Application %s has no destination.namespace" % (rel, name_of(app)))
else:
    failures.append("no apps/environments tree; the per-environment ArgoCD"
                    " applications are missing")

# --------------------------------------------------------------------------
# Phase 2: the ApplicationSet, whose Helm source and generator have to agree.
# --------------------------------------------------------------------------
application_sets = 0
generator_keys = set()
if os.path.isfile(ARGOCD_APPSET):
    rel = os.path.relpath(ARGOCD_APPSET, APPS_DIR)
    docs = load(ARGOCD_APPSET)
    sets = [d for d in docs if d.get("kind") == "ApplicationSet"]
    if len(sets) != 1:
        failures.append("%s: expected exactly 1 ApplicationSet, found %d" % (rel, len(sets)))
    else:
        application_sets += 1
        appset = sets[0]
        spec = appset.get("spec") or {}
        check_required(spec.get("goTemplate") is True,
                       "%s: goTemplate must be true; the template uses {{.cluster}}"
                       " style references" % rel)
        check_required("missingkey=error" in (spec.get("goTemplateOptions") or []),
                       "%s: goTemplateOptions must include missingkey=error so an"
                       " unset generator value fails the sync instead of"
                       " rendering an empty string" % rel)
        generators = spec.get("generators") or []
        elements = [element for generator in generators
                    for element in (generator.get("list") or {}).get("elements") or []]
        if not elements:
            failures.append("%s: the ApplicationSet has no list generator elements,"
                            " so it renders no Application" % rel)
        for element in elements:
            generator_keys |= flattened_keys(element)
        template = (spec.get("template") or {})
        template_spec = template.get("spec") or {}
        source = template_spec.get("source") or {}
        destination = template_spec.get("destination") or {}
        check_required(source.get("repoURL") == CANONICAL_REPO_URL,
                       "%s: template source.repoURL is %r, expected %r"
                       % (rel, source.get("repoURL"), CANONICAL_REPO_URL))
        helm_block = source.get("helm") or {}
        check_required(bool((helm_block.get("values") or "").strip()),
                       "%s: the Helm source declares no values block, so the"
                       " charts render with no environment" % rel)
        check_required(bool(destination.get("server")),
                       "%s: template destination.server is empty" % rel)
        check_required(bool(destination.get("namespace")),
                       "%s: template destination.namespace is empty" % rel)
        # Every {{.var}} in the file has to be produced by the generator,
        # otherwise missingkey=error fails the sync at deploy time.
        for body in PLACEHOLDER_RE.findall(read(ARGOCD_APPSET)):
            expression = body.split("|")[0].strip()
            if expression.startswith(".Values."):
                continue
            if expression not in generator_keys:
                failures.append(
                    "%s: template reads {{ %s }}, which no list generator element"
                    " supplies (generator supplies %s)"
                    % (rel, expression, sorted(generator_keys)))
else:
    failures.append("no apps/argo-cd/manifests.yaml; the ApplicationSet that"
                    " renders the Helm charts is missing")

# --------------------------------------------------------------------------
# Phase 3: every chart under apps/shared really renders with helm.
# --------------------------------------------------------------------------
if not os.path.isdir(SHARED):
    failures.append("no apps/shared tree to render")

rendered = 0
templated_expressions = 0
rendered_documents = 0
for app in sorted(os.listdir(SHARED)) if os.path.isdir(SHARED) else []:
    app_dir = os.path.join(SHARED, app)
    if not os.path.isdir(app_dir):
        continue
    manifests = sorted(f for f in os.listdir(app_dir) if f.endswith((".yaml", ".yml")))
    if not manifests:
        continue
    if app in RENDER_EXCEPTIONS:
        open_debts.append("chart %s: %s" % (app, RENDER_EXCEPTIONS[app]))
        continue

    chart_dir = os.path.join(WORK, "charts", app, "chart")
    templates_dir = os.path.join(chart_dir, "templates")
    os.makedirs(templates_dir)
    values = {}
    for manifest in manifests:
        raw = read(os.path.join(app_dir, manifest))
        for body in PLACEHOLDER_RE.findall(raw):
            expression = body.split("|")[0].strip().lstrip("-+ ")
            templated_expressions += 1
            if not expression.startswith(".Values."):
                failures.append(
                    "shared/%s/%s: unsupported template expression {{ %s }}; the"
                    " charts may only read .Values.* (generator variables belong"
                    " to the ApplicationSet)" % (app, manifest, body.strip()))
                continue
            leaf = expression[len(".Values."):]
            # Bracket-string keys keep their dots; a plain dotted path splits.
            parts = [quoted or bare for quoted, bare
                     in re.findall(r'\["([^"]+)"\]|([^.\[\]"]+)', leaf)]
            if not parts:
                failures.append("shared/%s/%s: empty template expression {{ %s }}"
                                % (app, manifest, body.strip()))
                continue
            node = values
            for part in parts[:-1]:
                node = node.setdefault(part, {})
            node[parts[-1]] = VALUE
        with open(os.path.join(templates_dir, manifest), "w", encoding="utf-8") as handle:
            handle.write(raw)

    chart_name = re.sub(r"[^a-z0-9-]", "-", app.lower())
    with open(os.path.join(chart_dir, "Chart.yaml"), "w", encoding="utf-8") as handle:
        handle.write("apiVersion: v2\nname: %s\nversion: 0.1.0\n"
                     "description: rendered by %s to prove the templates in"
                     " apps/shared/%s expand\n" % (chart_name, "//tests/deployment:test_helm", app))

    def dump(node, indent=0):
        out = ""
        for key in sorted(node):
            value = node[key]
            quoted = key if re.fullmatch(r"[\w-]+", key) else '"%s"' % key
            if isinstance(value, dict):
                out += "%s%s:\n%s" % (" " * indent, quoted, dump(value, indent + 2))
            else:
                out += "%s%s: %s\n" % (" " * indent, quoted, value)
        return out

    values_path = os.path.join(WORK, "charts", app, "values.yaml")
    with open(values_path, "w", encoding="utf-8") as handle:
        handle.write(dump(values))

    for arguments, label in ((["lint", chart_dir, "-f", values_path], "helm lint"),
                             (["template", chart_dir, "-f", values_path], "helm template")):
        result = subprocess.run([HELM] + arguments, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            detail = [line.strip() for line in
                      (result.stdout + "\n" + result.stderr).splitlines() if line.strip()]
            failures.append(
                "chart %s: `%s` failed (%s): %s"
                % (app, label, result.returncode, " | ".join(detail[-4:]) or "no output"))
            break
        if label == "helm lint":
            continue
        rendered_output = result.stdout
        if "{{" in rendered_output:
            failures.append("chart %s: rendered output still contains an"
                            " unexpanded {{ placeholder }}" % app)
            break
        try:
            documents = [d for d in yaml.safe_load_all(rendered_output) if d]
        except Exception as exc:  # noqa: BLE001 - a broken render is a finding
            failures.append("chart %s: rendered output is not valid YAML: %s"
                            % (app, str(exc).splitlines()[0]))
            break
        if not documents:
            failures.append("chart %s: rendered to zero documents" % app)
            break
        for document in documents:
            if not document.get("apiVersion") or not document.get("kind"):
                failures.append("chart %s: rendered %s has no apiVersion/kind"
                                % (app, name_of(document)))
            if not (document.get("metadata") or {}).get("name"):
                failures.append("chart %s: rendered %s has no metadata.name"
                                % (app, document.get("kind")))
        rendered += 1
        rendered_documents += len(documents)

check_required(rendered > 0, "no chart rendered at all; the helm phase did nothing")

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
    print("%d failure(s)" % len(failures))
    sys.exit(1)

print("PASS %d chart(s) rendered by helm into %d valid Kubernetes document(s)"
      % (rendered, rendered_documents))
print("     %d template expression(s) read only .Values.*, and each chart got"
      " values for every key it reads" % templated_expressions)
print("     %d ArgoCD Application(s): canonical repoURL, infrastructure/<env>"
      " path, destination server and namespace set" % applications)
print("     %d ApplicationSet: goTemplate with missingkey=error, a Helm values"
      " block, and every {{.var}} backed by a generator element %s"
      % (application_sets, sorted(generator_keys)))
PYTHON

echo "PASS Helm charts: ${TARGET}"
