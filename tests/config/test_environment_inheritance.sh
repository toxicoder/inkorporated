#!/bin/bash
# Asserts the environment-inheritance contract the config tree actually has: a
# base layer (config/domain-config.yaml plus the environments map in
# config/environment-config.yaml) that each config/environments/<env>/ overlay
# extends. Every environment the base declares has to exist on disk, every
# overlay has to say which environment it is, agree with itself, agree with the
# base about domains, inherit the service catalogue unchanged, be documented, and
# have a twin under apps/environments. The devcontainer template's DOMAIN_BASE is
# checked against the base layer too, because that is how the template inherits.
#
# Run it with: bazelisk test //tests/config:test_environment_inheritance
#
# The directory-existence checks this lane replaced all had an INFO branch, so a
# missing environment was a pass. Here every check has one outcome: it holds or it
# fails the lane.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
CONFIG="${REPO_ROOT}/config"
ENVIRONMENTS="${CONFIG}/environments"
ENV_TEMPLATE="${REPO_ROOT}/.devcontainer/.env.example"
TARGET="bazelisk test //tests/config:test_environment_inheritance"

failures=0
emitted=0

ok() {
    echo "ok   - $1"
}

fail() {
    local label="$1"
    shift
    local detail
    echo "FAIL - ${label}" >&2
    for detail in "$@"; do
        echo "       ${detail}" >&2
    done
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
}

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool python3 "apt-get install -y python3"
require_tool grep "apt-get install -y grep"

# A YAML library is not optional here: a lane that cannot parse the layers it
# compares has nothing to assert. It fails rather than skipping.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    echo "FAIL - python3 has no yaml module; this lane cannot read the config layers" >&2
    echo "       install it with: pip3 install pyyaml (the docs lane already needs it)" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

for required in "${CONFIG}/domain-config.yaml" "${CONFIG}/environment-config.yaml" \
    "${ENVIRONMENTS}/README.md" "$ENV_TEMPLATE"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done
if [ ! -d "$ENVIRONMENTS" ]; then
    echo "FAIL - ${ENVIRONMENTS} does not exist; there is no overlay layer at all" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# The comparison itself runs in python, which owns the YAML. It emits one
# `OK|label` or `FAIL|label|detail...` line per assertion and bash turns them into
# the lane's usual output, so a crash is a failed lane rather than an empty one.
cat >"${WORKDIR}/check_inheritance.py" <<'PY'
"""Compare each environment overlay against the base config layer.

Emits one line per assertion: OK|<label> or FAIL|<label>|<detail>|<detail>.
"""
import os
import sys

import yaml

root = sys.argv[1]
environments_dir = os.path.join(root, "config", "environments")
apps_dir = os.path.join(root, "apps", "environments")
env_template = os.path.join(root, ".devcontainer", ".env.example")
readme = os.path.join(environments_dir, "README.md")

results = []


def ok(label):
    results.append(["OK", label])


def fail(label, *details):
    results.append(["FAIL", label, *details])


def load(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def services_of(doc, path):
    services = doc.get("services")
    if not isinstance(services, list):
        fail(f"{path} declares no services list", f"services: {services!r}")
        return None
    pairs = []
    for entry in services:
        if not isinstance(entry, dict) or "name" not in entry or "subdomain" not in entry:
            fail(f"{path} has a service entry without name and subdomain", repr(entry))
            return None
        pairs.append((entry["name"], entry["subdomain"]))
    return pairs


# --- the base layer -------------------------------------------------------
try:
    global_domain = load(os.path.join(root, "config", "domain-config.yaml"))
    ok("the base domain layer parses as YAML")
except Exception as error:  # noqa: BLE001 - any parse error is a failed lane
    fail("the base domain layer does not parse", str(error))
    print("\n".join("|".join(row) for row in results))
    raise SystemExit(1)

try:
    global_env = load(os.path.join(root, "config", "environment-config.yaml"))
    ok("the base environment layer parses as YAML")
except Exception as error:  # noqa: BLE001
    fail("the base environment layer does not parse", str(error))
    print("\n".join("|".join(row) for row in results))
    raise SystemExit(1)

declared = global_env.get("environments")
if not isinstance(declared, dict) or not declared:
    fail("the base layer declares no environments to inherit",
         f"environments: {declared!r}")
    declared = {}
else:
    ok(f"the base layer declares {len(declared)} environment(s) to inherit")

base_domain = (global_domain.get("domain") or {}).get("base")
if not isinstance(base_domain, str) or not base_domain:
    fail("the base domain layer declares no domain.base",
         f"domain: {global_domain.get('domain')!r}")
    print("\n".join("|".join(row) for row in results))
    raise SystemExit(1)

global_services = services_of(global_domain, "config/domain-config.yaml")

default_env = global_env.get("default")
if not isinstance(default_env, str) or not default_env:
    fail("the base layer declares no default environment", f"default: {default_env!r}")
elif default_env not in declared:
    fail("the default environment is not one the base layer declares",
         f"default: {default_env}", "declared: " + ", ".join(sorted(declared)))
elif not os.path.isdir(os.path.join(environments_dir, default_env)):
    fail("the default environment has no overlay directory",
         f"default: {default_env}")
else:
    ok(f"the default environment ({default_env}) is declared and overlaid")

# --- the overlay layer ----------------------------------------------------
if not os.path.isdir(apps_dir):
    fail("apps/environments does not exist", f"expected: {apps_dir}")
    app_envs = []
else:
    app_envs = sorted(name for name in os.listdir(apps_dir)
                      if os.path.isdir(os.path.join(apps_dir, name)))

on_disk = sorted(name for name in os.listdir(environments_dir)
                 if os.path.isdir(os.path.join(environments_dir, name)))
if not on_disk:
    fail("no environment overlay directory exists", f"looked in: {environments_dir}")
else:
    ok(f"{len(on_disk)} environment overlay director(ies) under config/environments")

undocumented = [name for name in on_disk
                if name not in open(readme, encoding="utf-8").read()]
if undocumented:
    fail("environment overlays nobody documents",
         "missing from config/environments/README.md: " + ", ".join(undocumented))
else:
    ok("every environment overlay is documented in the environments README")

orphan_apps = [name for name in app_envs if name not in on_disk]
if orphan_apps:
    fail("apps/environments has overlays with no config twin",
         "orphans: " + ", ".join(orphan_apps),
         "an app overlay with no environment config deploys against nothing")
else:
    ok(f"each of the {len(app_envs)} apps/environments overlay(s) has a config twin")

for name in sorted(set(list(declared) + on_disk)):
    env_dir = os.path.join(environments_dir, name)
    if not os.path.isdir(env_dir):
        fail(f"the base layer declares {name} but no overlay directory exists",
             f"expected: config/environments/{name}")
        continue

    missing = []
    docs = {}
    for kind in ("domain-config.yaml", "environment-config.yaml"):
        path = os.path.join(env_dir, kind)
        if not os.path.isfile(path):
            missing.append(f"config/environments/{name}/{kind}")
            continue
        try:
            docs[kind] = load(path)
        except Exception as error:  # noqa: BLE001
            fail(f"the {name} overlay file {kind} does not parse", str(error))

    if missing:
        fail(f"the {name} overlay is incomplete", "missing: " + ", ".join(missing))
        continue

    env_doc = docs["environment-config.yaml"]
    dom_doc = docs["domain-config.yaml"]

    if env_doc.get("environment") != name:
        fail(f"the {name} overlay does not name itself",
             f"environment: {env_doc.get('environment')!r}", f"directory: {name!r}",
             "an overlay that labels itself another environment is applied to the wrong one")
    else:
        ok(f"the {name} overlay names itself environment: {name}")

    inner = env_doc.get("domain") or {}
    outer = dom_doc.get("domain") or {}
    if inner != outer or not inner:
        fail(f"the {name} overlay disagrees with itself about the domain",
             f"environment-config.yaml: {inner!r}", f"domain-config.yaml: {outer!r}")
    else:
        ok(f"the {name} overlay states one domain in both of its files")

    if name in declared:
        want = declared[name].get("domain")
        if want != inner:
            fail(f"the {name} overlay drifts from what the base layer promises",
                 f"base layer: {want!r}", f"overlay: {inner!r}")
        else:
            ok(f"the {name} overlay inherits the domain the base layer declares")

    derived = base_domain if name == "prod" else f"{name}.{base_domain}"
    if inner.get("base") != derived:
        fail(f"the {name} overlay invents a domain instead of deriving it",
             f"base: {inner.get('base')!r}", f"expected: {derived!r}",
             f"base layer domain.base: {base_domain!r}")
    else:
        ok(f"the {name} overlay derives its domain from the base layer")

    wildcard = (inner.get("wildcard") or "").lstrip("*.")
    if wildcard != (inner.get("base") or ""):
        fail(f"the {name} overlay wildcard does not match its own base",
             f"wildcard: {inner.get('wildcard')!r}", f"base: {inner.get('base')!r}")
    else:
        ok(f"the {name} overlay wildcard is the wildcard of its own base")

    services = services_of(dom_doc, f"config/environments/{name}/domain-config.yaml")
    if services is not None and global_services is not None:
        if services != global_services:
            fail(f"the {name} overlay does not inherit the service catalogue",
                 f"base has {len(global_services or [])} service(s), "
                 f"overlay has {len(services)}",
                 "an overlay that drops a service silently stops deploying it")
        else:
            ok(f"the {name} overlay inherits all {len(services)} service(s) unchanged")

# --- the devcontainer template inherits the base domain -------------------
template_base = None
with open(env_template, encoding="utf-8") as handle:
    for line in handle:
        if line.startswith("DOMAIN_BASE="):
            template_base = line.split("=", 1)[1].strip().strip('"').strip("'")
if template_base is None:
    fail("the devcontainer template declares no DOMAIN_BASE",
         f"file: .devcontainer/.env.example",
         "templated Ingress references have nothing to expand without it")
elif template_base != base_domain:
    fail("the devcontainer template does not inherit the base domain",
         f"DOMAIN_BASE: {template_base!r}", f"config/domain-config.yaml: {base_domain!r}")
else:
    ok(f"the devcontainer template inherits DOMAIN_BASE ({template_base}) from the base layer")

print("\n".join("|".join(row) for row in results))
raise SystemExit(1 if any(row[0] == "FAIL" for row in results) else 0)
PY

if ! python3 "${WORKDIR}/check_inheritance.py" "$REPO_ROOT" >"${WORKDIR}/results" 2>"${WORKDIR}/stderr"; then
    if [ ! -s "${WORKDIR}/results" ]; then
        fail "the inheritance checker could not run" \
            "$(head -5 "${WORKDIR}/stderr")"
    fi
fi

while IFS='|' read -r verdict label detail detail2 detail3; do
    [ -n "$verdict" ] || continue
    emitted=$((emitted + 1))
    if [ "$verdict" = "OK" ]; then
        ok "$label"
    else
        details=()
        for candidate in "$detail" "$detail2" "$detail3"; do
            [ -n "$candidate" ] && details+=("$candidate")
        done
        fail "$label" "${details[@]}"
    fi
done <"${WORKDIR}/results"

# An inheritance lane that compared nothing must not be able to report success.
if [ "$emitted" -lt 10 ]; then
    fail "the inheritance checker emitted only ${emitted} assertion(s)" \
        "the config tree has a base layer and per-environment overlays; fewer than" \
        "ten comparisons means the checker stopped early" \
        "$(head -5 "${WORKDIR}/stderr")"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} environment-inheritance assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: every environment overlay exists, names itself, agrees with the base" \
    "layer, inherits the service catalogue, and is documented"
