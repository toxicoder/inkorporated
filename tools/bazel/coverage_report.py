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

The shell half is measured, not assumed: every script named by --sh-test runs
with xtrace on and BASH_XTRACEFD pointed at a file, so the tracer sees the
child bash scripts those tests launch as well (SHELLOPTS is inherited). The
denominator is the set of lines bash can attribute a command to, which is not
every line of code: bash never reports a function definition, a lone clause
keyword, or a case pattern, and it tags a command that spans several physical
lines with the line its last token ended on.

Usage:
    coverage_report.py [--root DIR] [--py-scope FILE] [--sh-scope FILE]
                       [--exclusions FILE] [--test FILE]... [--sh-test FILE]...
                       [--sh-trace FILE]... [--min PERCENT] [--only PATTERN]
                       [--json] [--strict-ledger]

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
import tempfile
import unittest

# One trace line per command: bash expands $BASH_SOURCE and $LINENO itself, and
# prefixes one more `+` per nesting level, so the match tolerates any run of them.
PS4 = "+|${BASH_SOURCE}|${LINENO}|"
TRACE_RE = re.compile(r"^\++\|(.*?)\|(\d+)\|")


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

_REALPATH_CACHE = {}


def rpath(path):
    """os.path.realpath, memoised: the tracer calls it on every single frame."""
    try:
        cached = _REALPATH_CACHE.get(path)
        if cached is None:
            cached = os.path.realpath(path)
            _REALPATH_CACHE[path] = cached
        return cached
    except OSError:
        return path


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


# Words that are shell syntax rather than a command: bash never writes an
# xtrace line for a line whose whole command is one of these.
_SHELL_CLAUSE_WORDS = frozenset(
    ("{", "}", "(", ")", "fi", "done", "esac", "then", "else", "do", ";;", ";&",
     ";;&", "in", "esac", "!"))

# `name() {` and `function name {`: the definition itself is never traced, only
# the body when the function is called.
_SHELL_FUNCTION_HEAD = re.compile(
    r"^(function\s+[\w.\-]+(\s*\(\s*\))?|[\w.\-]+\s*\(\s*\))\s*\{?\s*$")

# `<<DELIM`, `<<-DELIM`, `<<'DELIM'`, `<<"DELIM"`. A `<<<` herestring is not a
# heredoc and the extra `<` keeps it out of this pattern.
_HEREDOC_RE = re.compile(r"<<(?!<)(-?)[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")


def _quote_state(single, double, text):
    """The single/double quote state after reading `text` from a known state."""
    escaped = False
    for char in text:
        if escaped:
            escaped = False
            continue
        if char == "\\" and not single:
            escaped = True
        elif char == "'" and not double:
            single = not single
        elif char == '"' and not single:
            double = not double
    return single, double


def _code_part(line, single, double):
    """The line with a trailing comment removed, and the quote state after it.

    A `#` only starts a comment where the shell is not inside a word and not
    inside quotes, so the cut has to walk the line rather than split on it.
    """
    escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\" and not single:
            escaped = True
        elif char == "'" and not double:
            single = not single
        elif char == '"' and not single:
            double = not double
        elif char == "#" and not single and not double:
            if index == 0 or line[index - 1].isspace():
                return line[:index], single, double
    return line, single, double


def heredoc_body_lines(text):
    """The physical lines that hold heredoc payloads, as a set of line numbers.

    bash reads a here-document after the command that asks for it and feeds it
    to the command's standard input; not one of its lines is a command, so the
    tracer never names them and they cannot be part of the denominator.
    """
    lines = text.split("\n")
    body = set()
    single = double = False
    index = 0
    while index < len(lines):
        code, single_after, double_after = _code_part(lines[index], single, double)
        cursor = index + 1
        if not single and not double:
            for match in _HEREDOC_RE.finditer(code):
                strip_tabs, delimiter = match.group(1), match.group(3)
                end = cursor
                while end < len(lines):
                    probe = lines[end].lstrip("\t") if strip_tabs else lines[end]
                    end += 1
                    if probe == delimiter:
                        break
                body.update(range(index + 2, end + 1))   # 1-based, body + delimiter
                cursor = end
        single, double = single_after, double_after
        index = max(index + 1, cursor)
    return body


def _bare_assignment(statement):
    """True when the statement is only `NAME=value` words, with no command.

    bash tags a simple command with the line its command word sits on, but a
    statement made only of assignments has no command word, and there it uses
    the line the last value ends on. Both cases have to land on the line bash
    names, or the denominator asks a script to cover a line no trace reports.
    """
    index, length = 0, len(statement)
    saw_assignment = False
    while index < length:
        while index < length and statement[index].isspace():
            index += 1
        if index >= length:
            break
        start = index
        quote = ""
        depth = 0
        while index < length:
            char = statement[index]
            if char == "\\" and quote != "'":
                index += 2                  # a backslash makes the next char
                continue                    # literal, quote or no quote
            if quote:
                if char == quote:
                    quote = ""
            elif char in "'\"":
                quote = char
            elif depth:
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
            elif char == "(":
                depth += 1
            elif char.isspace():
                break
            index += 1
        # A multi-line array assignment is one word: `NAME=(` opens it and the
        # closing paren closes it, so the whitespace inside does not split it.
        word = statement[start:index]
        if depth or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*(\+?=)", word):
            return False
        saw_assignment = True
    return saw_assignment


def shell_executable_lines(path):
    """The lines of a shell script that `bash -x` is able to report.

    This is the denominator, so it has to be the set bash can actually name,
    not the set of lines that hold code. Measured against bash 5: it writes one
    trace line per command and tags it with the line the command *started* on,
    so the second and later physical lines of a backslash continuation, of a
    `$( ... )` spread over several lines, or of an array literal never get a
    trace of their own. Blanks, comments, the shebang, clause keywords, case
    patterns, function-definition heads and here-document payloads are not
    commands at all, so counting them would ask a script to cover lines the
    tracer cannot observe.
    """
    with open(path, encoding="utf-8") as handle:
        text = handle.read()

    heredocs = heredoc_body_lines(text)
    lines = set()
    lineno = 1
    single = double = False
    escaped = False
    depth = 0          # inside ( ... ) or [ ... ]
    case_depth = 0     # inside case ... esac
    token_line = 0     # line the first token character of this command started on
    end_line = 0       # line the last token character of this command ended on
    command = []       # characters of the command being scanned

    def flush():
        """Record the command at the line bash names it with.

        A command with a command word is named by that word's line, which is
        the first line of the statement; a statement of bare assignments has no
        command word and is named by the line its last value ends on.
        """
        nonlocal token_line, end_line
        statement = "".join(command).strip()
        at = end_line if _bare_assignment(statement) else token_line
        del command[:]
        token_line = end_line = 0
        if not at or not statement or statement.startswith("#"):
            return
        if statement in _SHELL_CLAUSE_WORDS:
            return
        if _SHELL_FUNCTION_HEAD.match(statement):
            return
        if case_depth and statement.endswith(")"):
            return                        # a case pattern is not a command
        lines.add(at)

    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if lineno in heredocs and not single and not double and depth == 0:
            # A here-document payload is stdin for a command, not a command
            # itself: no trace line is ever written for it.
            while index < length and text[index] != "\n":
                index += 1
            lineno += 1
            index += 1
            continue
        if escaped:                        # the previous character was a \
            escaped = False
            if char == "\n":
                lineno += 1                # bash counts a continued line
            else:
                command.append(char)
                # token_line is already set: the backslash branch that put a
                # character here named this line, and it cannot be skipped.
                end_line = lineno
            index += 1
            continue
        if char == "\\" and not single:
            escaped = True
            command.append(char)
            if not token_line:
                token_line = lineno
            end_line = lineno
            index += 1
            continue
        if char == "\n":
            if single or double or depth:
                command.append(char)      # the command continues on this line
            else:
                flush()
            lineno += 1
            index += 1
            continue
        if not single and not double and depth == 0 and char == "#" and \
                (not command or command[-1].isspace()):
            while index < length and text[index] != "\n":
                index += 1
            continue
        if char == "'":
            single = not single
        elif char == '"':
            double = not double
        elif not single and not double:
            if char in "([":
                depth += 1
            elif char in ")]":
                depth = max(0, depth - 1)
            elif depth == 0 and char in ";|&":
                flush()
                index += 1
                continue
        if char.isspace():
            command.append(char)
            index += 1
            continue
        if not single and not double and (not command or command[-1].isspace()):
            word = re.match(r"[\w.!\-]+", text[index:])
            if word:
                if word.group(0) == "case":
                    case_depth += 1
                elif word.group(0) == "esac":
                    case_depth = max(0, case_depth - 1)
        command.append(char)
        if not token_line:
            token_line = lineno
        end_line = lineno
        index += 1
    flush()
    if text.startswith("#!"):
        lines.discard(1)                   # the shebang is never reported
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
    """Execute test files under a tracer, returning {real path: set(lines)}.

    The suite is loaded and run inside the traced region: a module's
    top-level statements only execute once, at import, so a tracer installed
    after the loader has run never sees the imports, the constants and the
    function definitions that make up most of a checker's lines.
    """
    hits = {}
    wanted = {}
    for path in instrumented:
        real = rpath(path)
        wanted[path] = real
        wanted[os.path.abspath(path)] = real
        wanted[real] = real

    def tracer(frame, event, _arg):
        if event == "call" or event == "line":
            real = wanted.get(frame.f_code.co_filename)
            # A frame that has not reached a statement yet reports line 0.
            if real is not None and frame.f_lineno > 0:
                hits.setdefault(real, set()).add(frame.f_lineno)
        return tracer

    cwd = os.getcwd()
    for test in tests:
        abs_test = test if os.path.isabs(test) else os.path.join(root, test)
        if not os.path.isfile(abs_test):
            sys.stderr.write("error: test file not found: %s\n" % test)
            return None
        sys.settrace(tracer)
        try:
            os.chdir(root)
            suite = _load_suite(abs_test)
            with open(os.devnull, "w") as sink:
                result = unittest.TextTestRunner(stream=sink,
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


def wanted_map(instrumented):
    """Map every spelling of an instrumented path onto its real path."""
    wanted = {}
    for path in instrumented:
        real = rpath(path)
        for spelling in (path, os.path.abspath(path), real):
            wanted[spelling] = real
    return wanted


def collect_shell_trace(path, wanted, hits, root="."):
    """Fold one xtrace file into hits, keeping only the instrumented files.

    $BASH_SOURCE is whatever path the shell was handed, so a script a test
    started with a relative name is resolved against the test's cwd before it
    is compared with the scope. Anything that does not resolve to a file in
    scope is dropped rather than guessed at.
    """
    resolved = {}
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = TRACE_RE.match(line)
            if not match:
                continue
            name = match.group(1)
            number = int(match.group(2))
            if name not in resolved:
                real = wanted.get(name)
                if real is None and not os.path.isabs(name):
                    real = wanted.get(os.path.join(root, name))
                if real is None:
                    real = wanted.get(rpath(name))
                if real is None:
                    real = wanted.get(rpath(os.path.join(root, name)))
                resolved[name] = real
            real = resolved[name]
            if real is not None:
                hits.setdefault(real, set()).add(number)
    return hits


def run_shell_tests(root, tests, instrumented, trace_path=None):
    """Run shell test scripts with xtrace and collect covered lines.

    SHELLOPTS is inherited by every bash a test starts, so the wrappers and
    the doctor those tests launch are traced too, not just the test itself.
    BASH_XTRACEFD points the trace at a file of our own so it never lands on
    the descriptors the tests capture and assert against.
    """
    wanted = wanted_map(instrumented)
    hits = {}
    owns_trace = trace_path is None
    if owns_trace:
        fd, trace_path = tempfile.mkstemp(prefix="coverage-xtrace-", suffix=".log")
    else:
        parent = os.path.dirname(os.path.abspath(trace_path))
        if not os.path.isdir(parent):
            os.makedirs(parent)
        fd = os.open(trace_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    env = dict(os.environ, PS4=PS4, SHELLOPTS="xtrace", BASH_XTRACEFD=str(fd))
    try:
        for test in tests:
            abs_test = test if os.path.isabs(test) else os.path.join(root, test)
            if not os.path.isfile(abs_test):
                sys.stderr.write("error: shell test not found: %s\n" % test)
                return None
            proc = subprocess.run(["bash", "-x", abs_test], cwd=root, env=env,
                                  capture_output=True, text=True,
                                  pass_fds=(fd,))
            if proc.returncode != 0:
                sys.stderr.write("error: %s exited %d\n%s\n"
                                 % (test, proc.returncode, proc.stderr[-2000:]))
                return None
        return collect_shell_trace(trace_path, wanted, hits, root)
    finally:
        os.close(fd)
        if owns_trace:
            os.unlink(trace_path)


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
    ap.add_argument("--sh-trace", action="append", default=[],
                    help="extra xtrace file whose lines count as covered")
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
    sh_paths = [os.path.join(root, p) for p, _ in sh_modules]
    sh_hits = run_shell_tests(root, args.sh_test, sh_paths)
    if sh_hits is None:
        return 2
    # A script cannot be its own test: the coverage wrapper reports its own
    # executed lines through a trace file it wrote while it ran.
    if args.sh_trace:
        wanted = wanted_map(sh_paths)
        for trace in args.sh_trace:
            abs_trace = trace if os.path.isabs(trace) else os.path.join(root,
                                                                         trace)
            if not os.path.isfile(abs_trace):
                sys.stderr.write("error: shell trace not found: %s\n" % trace)
                return 2
            collect_shell_trace(abs_trace, wanted, sh_hits, root)

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
