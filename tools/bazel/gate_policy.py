#!/usr/bin/env python3
"""Keep the human-facing surface of this repository speaking in Bazel targets.

Three rules, all mechanical:

A. No prose, comment, docstring, or printed help tells a person to run a repo
   script by path. A command is a run instruction when it starts with `./` or
   `../`, or is preceded by an interpreter or runner (`bash`, `python3`, ...).
   A bare mention of a file ("docs/generate_cyborg_docs.py writes ...") is a
   file reference and stays legal. Run instructions must name a target.

B. Every Bazel label cited in markdown resolves. A doc that points at a
   deleted target is worse than a doc with no target at all.

C. A shell script that probes for an optional host binary with `if command -v`
   must be strictness-aware: under REQUIRE_LINT_TOOLS or CI the missing tool
   is fatal. Otherwise a green gate can mean the tool was never installed. Any
   tool probed this way must also be listed in the doctor's tool census, so
   `bazelisk run //:doctor` cannot drift from what the gates actually need.

Escape hatches, each with a written reason, in a comment on the offending line
or within two lines above it:

    # gate-policy: allow-script-path <reason>
    # gate-policy: allow-bazel-binary <reason>
    # gate-policy: tool-guard exempt <reason>

Usage:
    gate_policy.py [--root DIR] [--json] [--skip-rule A|B|C]

Exit codes: 0 clean, 1 violation, 2 usage/environment error.
"""

import argparse
import json
import os
import re
import subprocess
import sys

# Surfaces a person reads: prose, comments, docstrings, and printed help text.
DOC_SUFFIXES = (".md", ".mdx", ".markdown")
CODE_SUFFIXES = (".sh", ".py", ".bzl", ".yml", ".yaml", ".mjs", ".js")

INVOKE_RE = re.compile(
    r"""(?:^|[\s`'"|&(])                      # command position
        (?:(?:bash|sh|zsh|dash|python3|python2|python|node|deno|env|time|sudo|exec)\s+)?
        (?P<path>(?:\.\.?/)[\w./+-]+\.(?:sh|py|mjs|js)
                 |(?:bash|sh|zsh|dash|python3|python2|python|node|deno|env|time|sudo|exec)
                  \s+(?:[\w./-]+/)?[\w+-]+\.(?:sh|py|mjs|js))
    """,
    re.VERBOSE | re.MULTILINE,
)

# `bazel test //...` reads fine until someone runs it without Bazelisk and
# gets a Bazel the repository never pinned.
BAZEL_CMD_RE = re.compile(r"(?<![\w-])bazel\s+(test|run|build|query|cquery|aquery|mod)\b")

LABEL_RE = re.compile(r"(?<![:\w./-])//[\w.+-]+(?:/[\w.+-]+)*(?::[\w.+-]+)?")
SKIP_TOKENS = ("//visibility:public", "//visibility:private")

GUARD_RE = re.compile(r"^\s*(?:if|elif|while)\s+(?:!\s*)?command\s+-v\s+[\"']?([\w.+-]+)")
STRICT_RE = re.compile(r"REQUIRE_LINT_TOOLS|(?<![\w/])CI\b")
CENSUS_RE = re.compile(r"^\s*\"([\w.+-]+):")

POLICY_RE = re.compile(r"#\s*gate-policy\s*:\s*(\S.*?)$", re.I)
GUARD_WINDOW = 12
POLICY_WINDOW = 2
DOCTOR_REL = os.path.join("tools", "bazel", "sh", "doctor.sh")

# A nested `bazelisk query` needs its own output base: the invocation that runs
# this checker as a test still holds the default one. BAZEL_ARGS are startup
# options (they precede the verb), BAZEL_QUERY_ARGS are command options (they
# follow it).
BAZEL_ARGS = []
BAZEL_QUERY_ARGS = []


def tracked_files(root):
    proc = subprocess.run(["git", "ls-files", "-z"], cwd=root,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr[-4000:])
        raise SystemExit(2)
    return [f for f in proc.stdout.split("\0") if f]


def read_lines(root, rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as handle:
            return handle.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return []


def policy_at(lines, index, needle):
    """True when a `# gate-policy: <needle> ...` comment guards this line."""
    start = max(0, index - POLICY_WINDOW)
    for line in lines[start:index + 1]:
        match = POLICY_RE.search(line)
        if match and match.group(1).lower().startswith(needle):
            return True
    return False


INTERPRETERS = ("bash", "sh", "zsh", "dash", "python3", "python2", "python",
                "node", "deno", "env", "time", "sudo", "exec")


def invocation_token(match):
    """The path a match tells a person to execute, without its interpreter."""
    token = (match.group("path") or match.group(0)).strip()
    parts = token.split(None, 1)
    if len(parts) == 2 and parts[0] in INTERPRETERS:
        token = parts[1].strip()
    return token.strip("`'\"")


def names_repo_script(token, rel, tracked):
    """Only flag paths that resolve to a file this repository actually tracks.

    Sample code inside a prose page (`node dist/index.js`) and host-absolute
    container paths (`bash /workspaces/inkorporated/setup.sh`) are not run
    instructions for this repo, and flagging them would bury the real hits.
    """
    if not tracked:
        return True
    cleaned = token
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    while cleaned.startswith("../"):
        cleaned = cleaned[3:]
    cleaned = cleaned.lstrip("/")
    here = os.path.normpath(os.path.join(os.path.dirname(rel), cleaned))
    root = os.path.normpath(cleaned)
    return here in tracked or root in tracked


def check_script_paths(rel, lines, tracked):
    """Rule A: no run instruction may name a repo script path."""
    findings = []
    if os.path.basename(rel) == os.path.basename(__file__):
        return findings
    for index, line in enumerate(lines):
        for match in INVOKE_RE.finditer(line):
            token = invocation_token(match)
            if not names_repo_script(token, rel, tracked):
                continue
            if policy_at(lines, index, "allow-script-path"):
                continue
            findings.append({"file": rel, "line": index + 1,
                             "rule": "A", "text": token[:80]})
    return findings


def bazel_binary_findings(rel, lines):
    """Rule A companion: Bazel invocations must go through Bazelisk."""
    findings = []
    for index, line in enumerate(lines):
        if not BAZEL_CMD_RE.search(line):
            continue
        if policy_at(lines, index, "allow-bazel-binary"):
            continue
        findings.append({"file": rel, "line": index + 1, "rule": "A",
                         "text": BAZEL_CMD_RE.search(line).group(0)[:80]})
    return findings


def collect_labels(root, files):
    """Every //pkg:target cited in markdown, with where it was cited."""
    cited = {}
    for rel in files:
        if not rel.endswith(DOC_SUFFIXES):
            continue
        for index, line in enumerate(read_lines(root, rel)):
            for match in LABEL_RE.finditer(line):
                label = match.group(0)
                if "..." in label or label in SKIP_TOKENS:
                    continue
                cited.setdefault(label, []).append({"file": rel, "line": index + 1})
    return cited


def resolvable_labels(root):
    """Rule labels from the build plus source files that exist on disk."""
    # Startup options lead, command options follow the verb; Bazel rejects
    # either in the other's position.
    proc = subprocess.run(["bazelisk"] + BAZEL_ARGS +
                          ["query", "//...", "--output=label"] +
                          BAZEL_QUERY_ARGS,
                          cwd=root, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr[-4000:])
        raise SystemExit(2)
    labels = set()
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.startswith("//"):
            labels.add(line)
    return labels


def label_exists(label, root, labels):
    if label in labels:
        return True
    body = label[2:]
    pkg, sep, name = body.partition(":")
    if not sep:
        name = pkg.rsplit("/", 1)[-1]
    candidate = os.path.join(root, pkg, name) if pkg else os.path.join(root, name)
    return os.path.isfile(candidate)


def check_labels(root, files, labels):
    findings = []
    for label, where in sorted(collect_labels(root, files).items()):
        if label_exists(label, root, labels):
            continue
        first = where[0]
        findings.append({"file": first["file"], "line": first["line"], "rule": "B",
                         "text": "%s cited by %d place(s)" % (label, len(where))})
    return findings


def doctor_census(root):
    """Tool names the doctor advertises, parsed from its two arrays."""
    lines = read_lines(root, DOCTOR_REL)
    census = set()
    inside = False
    for line in lines:
        if re.match(r"^\s*(REQUIRED_TOOLS|OPTIONAL_TOOLS)=\(", line):
            inside = True
            continue
        if inside and line.strip().startswith(")"):
            inside = False
            continue
        if inside:
            match = CENSUS_RE.match(line)
            if match:
                census.add(match.group(1))
    return census


def check_tool_guards(root, files, census):
    """Rule C: optional-binary probes must be strictness-aware and known.

    A probe passes when it honors REQUIRE_LINT_TOOLS/CI, when its else branch
    does real work instead of exiting 0, or when a written exemption sits
    nearby. Every probe, passing or not, must also appear in the doctor's
    census so //:doctor keeps reporting what the gates actually need.
    """
    findings = []
    for rel in files:
        if not rel.endswith(".sh"):
            continue
        lines = lines_of(root, rel)
        for index, line in enumerate(lines):
            match = GUARD_RE.match(line)
            if not match:
                continue
            tool = match.group(1)
            exempt = policy_at(lines, index, "tool-guard exempt")
            if not exempt:
                window = "\n".join(lines[index:index + GUARD_WINDOW])
                if STRICT_RE.search(window):
                    pass
                elif "else" in window and "exit 0" not in window:
                    pass  # a real fallback branch, not a silent skip
                else:
                    findings.append({
                        "file": rel, "line": index + 1, "rule": "C",
                        "text": "probes %s without honoring "
                                "REQUIRE_LINT_TOOLS/CI" % tool})
            if not exempt and tool not in census:
                findings.append({"file": rel, "line": index + 1, "rule": "C",
                                 "text": "%s is not listed in %s"
                                         % (tool, DOCTOR_REL)})
    return findings


_LINES_CACHE = {}


def lines_of(root, rel):
    if rel not in _LINES_CACHE:
        _LINES_CACHE[rel] = read_lines(root, rel)
    return _LINES_CACHE[rel]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--skip-rule", choices=("A", "B", "C"), action="append",
                    default=[], help="skip a rule (development only)")
    ap.add_argument("--bazel-args", default="",
                    help="startup options for the nested bazelisk query, "
                         "whitespace separated (e.g. --output_base=/tmp/b)")
    ap.add_argument("--bazel-query-args", default="",
                    help="command options for the nested bazelisk query, "
                         "whitespace separated (e.g. --lockfile_mode=off)")
    args = ap.parse_args(argv)

    global BAZEL_ARGS, BAZEL_QUERY_ARGS
    BAZEL_ARGS = args.bazel_args.split() if args.bazel_args else []
    BAZEL_QUERY_ARGS = (args.bazel_query_args.split()
                        if args.bazel_query_args else [])

    root = os.path.abspath(args.root)
    _LINES_CACHE.clear()
    if not os.path.isdir(os.path.join(root, ".git")):
        sys.stderr.write("error: %s is not a git repository\n" % root)
        return 2

    files = tracked_files(root)
    tracked = set(files)
    surfaces = [f for f in files
                if f.endswith(DOC_SUFFIXES) or f.endswith(CODE_SUFFIXES)]

    findings = []
    skipped = set(args.skip_rule)
    if "A" not in skipped:
        for rel in surfaces:
            lines = lines_of(root, rel)
            findings.extend(check_script_paths(rel, lines, tracked))
            findings.extend(bazel_binary_findings(rel, lines))
    if "B" not in skipped:
        findings.extend(check_labels(root, surfaces, resolvable_labels(root)))
    if "C" not in skipped:
        findings.extend(check_tool_guards(root, surfaces, doctor_census(root)))

    if args.json:
        print(json.dumps({"checked": len(surfaces), "violations": findings},
                         indent=2))
    else:
        for hit in findings:
            print("POLICY %s %s:%d  [%s] %s" % (hit["rule"], hit["file"],
                                                hit["line"], hit["rule"],
                                                hit["text"]))
        print("summary: %d human-facing files checked, %d violations, "
              "rules skipped: %s" % (len(surfaces), len(findings),
                                     ", ".join(sorted(skipped)) or "none"))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
