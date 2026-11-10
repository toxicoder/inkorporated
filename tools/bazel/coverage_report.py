#!/usr/bin/env python3
"""Line coverage for the gate's own code, measured and floored at 100%.

The repository's product is documentation and infrastructure-as-code, so the
code this gate is responsible for is its tooling: the Python checkers under
tools/bazel and the shell entry points they expose. A gate whose own helpers
are half-tested reports confidence it has not earned, so this runner measures
line coverage of exactly that set and fails below the floor.

Only the standard library is used: python coverage comes from sys.settrace and
the line table of the compiled module, shell coverage from `bash -x` with a
parseable PS4.

Scope and exclusions live in ledger-shaped files, one entry per line, pattern
and reason separated by a tab or two spaces. An entry without a reason fails,
and with --strict-ledger an entry that matches nothing fails too, so a
deletion cannot leave a claim behind.

Usage:
    coverage_report.py [--root DIR] [--py-scope FILE] [--sh-scope FILE]
                       [--exclusions FILE] [--test FILE]... [--sh-test FILE]...
                       [--min PERCENT] [--only PATTERN] [--json]
                       [--strict-ledger]

Exit codes: 0 clean, 1 below floor or ledger problem, 2 usage/environment error.
"""

import argparse
import fnmatch
import glob as globmod
import json
import os
import re
import subprocess
import sys
import unittest

PS4 = "+|%s|%L|"  # bash fills $LINENO via %L; $BASH_SOURCE is substituted per line


def read_ledger(path):
    """Parse `pattern<TAB>reason` lines into (pattern, reason) tuples."""
    entries = []
    if not os.path.isfile(path):
        return entries
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = re.split(r"\t+|\s{2,}", line.strip(), maxsplit=1)
            pattern = parts[0]
            reason = parts[1].strip() if len(parts) > 1 else ""
            entries.append((pattern, reason))
    return entries


_TREE_CACHE = {}


def tree(root):
    """Repo-relative paths under root, walked once per process."""
    if root not in _TREE_CACHE:
        _TREE_CACHE[root] = sorted(
            os.path.relpath(path, root)
            for path in globmod.glob(os.path.join(root, "**", "*"),
                                     recursive=True)
            if os.path.isfile(path))
    return _TREE_CACHE[root]


def expand(root, patterns):
    """Resolve ledger patterns to repo-relative paths that exist on disk."""
    found = []
    for pattern, reason in patterns:
        matches = sorted(fnmatch.filter(tree(root), pattern))
        for match in matches:
            found.append((match, reason))
    return found


def executable_lines(path):
    """Line numbers the Python compiler considers executable."""
    import types

    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    try:
        code = compile(source, path, "exec")
    except SyntaxError as exc:
        sys.stderr.write("error: %s: %s\n" % (path, exc))
        return None
    lines = set()
    stack = [code]
    while stack:
        current = stack.pop()
        for _, _, line in current.co_lines():
            if line:
                lines.add(line)
        for const in current.co_consts:
            if isinstance(const, types.CodeType):
                stack.append(const)
    return lines


def shell_executable_lines(path):
    """Non-blank, non-comment, non-structural lines of a shell script."""
    lines = set()
    with open(path, encoding="utf-8") as handle:
        for number, text in enumerate(handle, start=1):
            stripped = text.strip()
            if not stripped:
                continue
            if stripped.startswith("#") and number > 1:
                continue
            if stripped in ("{", "}", "done", "fi", "esac", "then", "else"):
                continue
            if re.match(r"^(local|local -\w+)\b", stripped):
                continue
            lines.add(number)
    return lines


def exclusion_lines(exclusions, rel):
    """Line numbers excluded for a module, from `path:LINE` and `path:*` forms."""
    lines = set()
    for pattern, reason in exclusions:
        if ":" not in pattern:
            continue
        target, _, selector = pattern.rpartition(":")
        if not fnmatch.fnmatch(rel, target):
            continue
        if selector == "*":
            lines.add("*")
        elif selector.isdigit():
            lines.add(int(selector))
    return lines


def run_python_tests(root, tests, instrumented):
    """Execute test files under a tracer, returning {abs path: set(lines)}."""
    hits = {}
    wanted = {os.path.realpath(p) for p in instrumented}

    def tracer(frame, event, _arg):
        if event != "call":
            return tracer
        if os.path.realpath(frame.f_code.co_filename) in wanted:
            hits.setdefault(os.path.realpath(frame.f_code.co_filename), set())
            hits[os.path.realpath(frame.f_code.co_filename)].add(frame.f_lineno)
        return tracer

    cwd = os.getcwd()
    for test in tests:
        abs_test = test if os.path.isabs(test) else os.path.join(root, test)
        if not os.path.isfile(abs_test):
            sys.stderr.write("error: test file not found: %s\n" % test)
            return None
        suite = _load_suite(abs_test)
        sys.settrace(tracer)
        try:
            os.chdir(root)
            result = unittest.TextTestRunner(stream=open(os.devnull, "w"),
                                             verbosity=0).run(suite)
        finally:
            sys.settrace(None)
            os.chdir(cwd)
        if not result.wasSuccessful():
            sys.stderr.write("error: %s failed (%d failures, %d errors)\n"
                             % (test, len(result.failures), len(result.errors)))
            for _case, tb in (result.failures + result.errors)[:3]:
                sys.stderr.write(tb[-1500:] + "\n")
            return None
    return hits


def _load_suite(abs_test):
    """Build a unittest suite from a file, its own __main__ block ignored."""
    loader = unittest.TestLoader()
    directory = os.path.dirname(abs_test)
    if directory not in sys.path:
        sys.path.insert(0, directory)
    name = os.path.basename(abs_test)[:-3]
    return loader.discover(directory, pattern=os.path.basename(abs_test),
                           top_level_dir=directory) if not name else \
        loader.loadTestsFromName(name)


def run_shell_tests(root, tests, instrumented):
    """Run shell test scripts with xtrace and collect covered lines."""
    wanted = {os.path.realpath(p) for p in instrumented}
    hits = {}
    env = dict(os.environ, PS4="+|${BASH_SOURCE}|${LINENO}|")
    for test in tests:
        abs_test = test if os.path.isabs(test) else os.path.join(root, test)
        if not os.path.isfile(abs_test):
            sys.stderr.write("error: shell test not found: %s\n" % test)
            return None
        proc = subprocess.run(["bash", "-x", abs_test], cwd=root, env=env,
                              capture_output=True, text=True)
        if proc.returncode != 0:
            sys.stderr.write("error: %s exited %d\n%s\n"
                             % (test, proc.returncode, proc.stderr[-2000:]))
            return None
        for line in proc.stderr.splitlines():
            match = re.match(r"^\+\|(.*)\|(\d+)\|", line)
            if not match:
                continue
            real = os.path.realpath(match.group(1))
            if real in wanted:
                hits.setdefault(real, set()).add(int(match.group(2)))
    return hits


def measure(root, modules, hits, exclusions, kind):
    """Compare covered lines against executable lines for each module."""
    rows = []
    for rel, reason in modules:
        abspath = os.path.join(root, rel)
        if kind == "py":
            total_lines = executable_lines(abspath)
            if total_lines is None:
                return None
        else:
            total_lines = shell_executable_lines(abspath)
        excluded = exclusion_lines(exclusions, rel)
        if "*" in excluded:
            rows.append({"path": rel, "reason": reason, "total": 0,
                         "covered": 0, "missing": [], "excluded": "all",
                         "percent": 100.0})
            continue
        covered = hits.get(os.path.realpath(abspath), set())
        relevant = total_lines - excluded
        hit = relevant & covered
        rows.append({"path": rel, "reason": reason,
                     "total": len(relevant), "covered": len(hit),
                     "missing": sorted(relevant - covered),
                     "excluded": sorted(excluded & total_lines),
                     "percent": (100.0 * len(hit) / len(relevant))
                                if relevant else 100.0})
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--py-scope", default="tools/bazel/coverage-scope.txt")
    ap.add_argument("--sh-scope", default="tools/bazel/sh/coverage-scope.txt")
    ap.add_argument("--exclusions", default="tools/bazel/coverage-exclusions.txt")
    ap.add_argument("--test", action="append", default=[])
    ap.add_argument("--sh-test", action="append", default=[])
    ap.add_argument("--min", type=float, default=100.0)
    ap.add_argument("--only", default=None, help="restrict to paths matching")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict-ledger", action="store_true")
    args = ap.parse_args(argv)

    root = os.path.abspath(args.root)
    ledger = {name: read_ledger(os.path.abspath(os.path.join(root, name)))
              for name in (args.py_scope, args.sh_scope, args.exclusions)}
    for name, entries in ledger.items():
        if not entries:
            sys.stderr.write("error: scope ledger %s is empty or missing\n" % name)
            return 2
        for pattern, reason in entries:
            if not reason:
                sys.stderr.write("error: %s: entry %r carries no reason\n"
                                 % (name, pattern))
                return 1

    def keep(pairs):
        if not args.only:
            return pairs
        return [(p, r) for p, r in pairs if fnmatch.fnmatch(p, args.only)]

    py_modules = keep(expand(root, ledger[args.py_scope]))
    sh_modules = keep(expand(root, ledger[args.sh_scope]))
    exclusions = ledger[args.exclusions]

    py_hits = run_python_tests(root, args.test,
                               [os.path.join(root, p) for p, _ in py_modules])
    if py_hits is None:
        return 2
    sh_hits = run_shell_tests(root, args.sh_test,
                              [os.path.join(root, p) for p, _ in sh_modules])
    if sh_hits is None:
        return 2

    rows = []
    for kind, modules, hits in (("py", py_modules, py_hits),
                                ("sh", sh_modules, sh_hits)):
        measured = measure(root, modules, hits, exclusions, kind)
        if measured is None:
            return 2
        rows.extend(measured)

    stale = []
    if args.strict_ledger:
        matched = {row["path"] for row in rows}
        for pattern, _ in ledger[args.py_scope] + ledger[args.sh_scope]:
            if not any(fnmatch.fnmatch(p, pattern) for p in matched):
                stale.append(pattern)

    total = sum(row["total"] for row in rows)
    covered = sum(row["covered"] for row in rows)
    percent = (100.0 * covered / total) if total else 100.0
    below = [row for row in rows if row["percent"] < args.min]

    if args.json:
        print(json.dumps({"modules": rows, "total_lines": total,
                          "covered_lines": covered, "percent": round(percent, 2),
                          "floor": args.min, "stale_scope": stale}, indent=2))
    else:
        for row in rows:
            flag = "OK " if row["percent"] >= args.min else "LOW"
            print("%s %-46s %4d/%-4d %6.2f%%  missing=%s"
                  % (flag, row["path"], row["covered"], row["total"],
                     row["percent"], row["missing"] if row["missing"] else "-"))
        for pattern in stale:
            print("STALE  scope entry %r matches no module" % pattern)
        print("summary: %d modules | %d/%d lines | %.2f%% | floor %.2f%%"
              % (len(rows), covered, total, percent, args.min))
        if below:
            for row in below:
                print("error: %s at %.2f%% is below the %.2f%% floor; add the "
                      "missing tests or record a reasoned exclusion"
                      % (row["path"], row["percent"], args.min))
    if below or stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
