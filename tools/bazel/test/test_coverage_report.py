#!/usr/bin/env python3
"""Unit tests for tools/bazel/coverage_report.py.

The runner is pointed at scratch trees it builds itself: a small Python module
plus the unittest that covers it, and a small shell script plus the script that
runs it under xtrace. Nothing here touches the repository.

    bazelisk test //tools/bazel/sh:coverage --test_arg=--only=coverage_report
"""

import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import coverage_report  # noqa: E402

MOD_TEMPLATE = '''"""Module under measurement."""

VALUE = 1


def used(x):
    return x + VALUE


def unused(x):
    if x:
        return 1
    return 2
'''

# Every statement of this module sits on a `def` line, which is the shape the
# tracer can observe whichever events it records.
TINY_TEMPLATE = '''def used(x): return x + 1
def unused(x): return 2 if x else 3
'''

TEST_TEMPLATE = '''import unittest

import {module}
import {tiny}


class MeasuredTest(unittest.TestCase):
    def test_used(self):
        self.assertEqual({module}.used(1), 2)
        self.assertEqual({tiny}.used(1), 2)

    def test_unused(self):
        self.assertEqual({module}.unused(0), 2)
        self.assertEqual({module}.unused(1), 1)
        self.assertEqual({tiny}.unused(0), 3)
        self.assertEqual({tiny}.unused(1), 2)
'''

FAILING_TEMPLATE = '''import unittest


class AlwaysFails(unittest.TestCase):
    def test_nope(self):
        self.assertEqual(1, 2)
'''

SCRIPT = '''#!/usr/bin/env bash
set -euo pipefail
GREETING=hello
echo "$GREETING"
echo "a line on stderr that is not a trace" >&2
'''

HELPER_SCRIPT = '''#!/usr/bin/env bash
echo "not instrumented"
'''

SH_TEST = '''#!/usr/bin/env bash
set -euo pipefail
bash -x script.sh >/dev/null
bash -x helper.sh >/dev/null
'''

FAILING_SH_TEST = '''#!/usr/bin/env bash
exit 3
'''

# One script that holds every shape the scanner has an opinion about, written so
# that a plain `bash script` executes every line of it. The scanner's set and the
# set `bash -x` reports must be equal, and both must be this literal set: an
# expectation read off bash rather than off the scanner is the only way the test
# can catch a scanner that agrees with itself and disagrees with the shell.
SHAPES = [
    "#!/usr/bin/env bash",                      #  1 shebang: never tagged
    "# a leading comment",                      #  2 comment: never tagged
    "",                                         #  3 blank: never tagged
    "GREETING=hello",                           #  4 assignment: tagged here
    "printf '%s\\n' one \\",                    #  5 continuation: tagged once
    "  two",                                    #  6 continuation: no tag of its own
    "ITEMS=(",                                  #  7 array head
    "  alpha",                                  #  8 array element
    "  beta",                                   #  9 array element
    ")",                                        # 10 array: tagged where it ends
    "cat <<'LITERAL'",                          # 11 heredoc with a quoted delimiter
    "$GREETING stays literal",                  # 12 payload: never tagged
    "LITERAL",                                  # 13 delimiter: never tagged
    "cat <<-INDENTED",                          # 14 heredoc that strips tabs
    "\tbody padded",                            # 15 payload: never tagged
    "\tINDENTED",                               # 16 tab-indented delimiter
    "read -r pair <<< 'a b'",                   # 17 a herestring is not a heredoc
    "printf '%s\\n' \"hash # inside quotes\" # a comment with <<EOF in it",
                                                # 18 only the trailing comment is code
    "joined=\"$(printf '%s\\n' \\",             # 19 assignment with a $( ) inside
    "  left \\",                                # 20
    "  right",                                  # 21
    ")\"",                                      # 22 tagged where the value ends
    "show() {",                                 # 23 function head: never tagged
    "  local label=\"$1\"",                     # 24
    "  printf '%s\\n' \"${label}\"",            # 25
    "}",                                        # 26 lone brace: never tagged
    "show called",                              # 27 the call is the command
    "for letter in a b; do",                    # 28
    "  printf '%s\\n' \"loop ${letter}\"",      # 29
    "done",                                     # 30 lone done: never tagged
    "for mode in yes no; do",                   # 31
    "  if [[ \"${mode}\" == yes ]]; then",      # 32
    "    then_ran=\"${mode}\"",                 # 33 runs on the first turn
    "  else",                                   # 34 lone else: never tagged
    "    else_ran=\"${mode}\"",                 # 35 runs on the second turn
    "  fi",                                     # 36 lone fi: never tagged
    "done",                                     # 37
    "case \"${mode}\" in",                      # 38
    "  no)",                                    # 39 case pattern: not a command
    "    printf '%s\\n' \"case arm\"",          # 40
    "    ;;",                                   # 41 clause word: never tagged
    "  *)",                                     # 42 pattern of an arm that does not run
    "    ;;",                                   # 43
    "esac",                                     # 44 lone esac: never tagged
    "\\printf '%s\\n' escaped-command-word",    # 45 an escaped first character
    "printf unquoted\\ escaped\\ spaces",       # 46 an escape inside a word
    "printf '%s\\n' \"${then_ran}${else_ran}${joined}${pair}\"",
                                                # 47
]
SHAPES_SCRIPT = "\n".join(SHAPES) + "\n"

# What `bash -x` with PS4='+|${BASH_SOURCE}|${LINENO}|' names for SHAPES.
SHAPES_TRACED = {4, 5, 10, 11, 14, 17, 18, 22, 24, 25, 27, 28, 29, 31, 32, 33,
                 35, 38, 40, 45, 46, 47}

# A test file that hands back the tracer run_python_tests installs, so the
# tracer itself can be driven with frames of our own: the interpreter does not
# trace a trace function's own frame, so nothing else ever runs those lines.
CAPTURE_TEMPLATE = '''import sys
import unittest

import {module}

CAPTURED = []


class CaptureTracerTest(unittest.TestCase):
    def test_capture_the_installed_tracer(self):
        CAPTURED.append(sys.gettrace())
        self.assertEqual({module}.used(1), 2)
'''


class _Frame(object):
    """Stand-in for a stack frame: the tracer reads only these two attributes."""

    def __init__(self, filename, lineno):
        self.f_code = type("Code", (object,), {"co_filename": filename})()
        self.f_lineno = lineno


@contextlib.contextmanager
def tracing_preserved():
    """Keep the outer coverage tracer installed across run_python_tests.

    That function clears the global trace function when it finishes; without
    restoring it, the lines executed afterwards would never be reported.
    """
    outer = sys.gettrace()
    real = sys.settrace

    def settrace(func):
        real(outer if func is None else func)

    sys.settrace = settrace
    try:
        yield
    finally:
        sys.settrace = real
        if sys.gettrace() is not outer:
            real(outer)


class CoverageReportTestCase(unittest.TestCase):
    # Scratch module names must be unique for the whole run: unittest's loader
    # caches by module name, so a second tree reusing `mod1` would silently
    # import the first tree's module.
    _serial = 0

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = os.path.join(self._tmp.name, "repo")
        os.makedirs(os.path.join(self.root, "cov"))
        self.test_arg = None

    @contextlib.contextmanager
    def in_root(self):
        """Run with the process cwd at the scratch root, as the wrapper does."""
        cwd = os.getcwd()
        os.chdir(self.root)
        try:
            yield
        finally:
            os.chdir(cwd)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        parent = os.path.dirname(path)
        if not os.path.isdir(parent):
            os.makedirs(parent)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        return path

    def ledger(self, name, *entries):
        return self.write(os.path.join("cov", name),
                          "".join("%s\t%s\n" % (pattern, reason)
                                  for pattern, reason in entries))

    def make_project(self):
        """Lay down two modules, the test that covers them, and two scripts."""
        CoverageReportTestCase._serial += 1
        self.module = "mod%d" % self._serial
        self.tiny = "tiny%d" % self._serial
        self.test_arg = "cov_test_%d_ok.py" % self._serial
        self.write(self.module + ".py", MOD_TEMPLATE)
        self.write(self.tiny + ".py", TINY_TEMPLATE)
        self.write(self.test_arg,
                   TEST_TEMPLATE.format(module=self.module, tiny=self.tiny))
        self.write("script.sh", SCRIPT)
        self.write("helper.sh", HELPER_SCRIPT)
        self.write("cov_test_all.sh", SH_TEST)
        self.ledger("py-scope.txt", (self.tiny + ".py", "the measured module"))
        self.ledger("sh-scope.txt", ("script.sh", "the script"),
                    ("helper.sh", "the helper"))
        self.ledger("exclusions.txt", ("script.sh:1", "shebang"),
                    ("helper.sh:1", "shebang"))
        return self.module

    def main_argv(self, *argv):
        return ["--root", self.root,
                "--py-scope", "cov/py-scope.txt",
                "--sh-scope", "cov/sh-scope.txt",
                "--exclusions", "cov/exclusions.txt"] + list(argv)

    def trace_lines(self, script):
        """Run a script under xtrace and return the lines bash names for it.

        The same wiring run_shell_tests uses: PS4 carries the file and the line,
        BASH_XTRACEFD points the trace at a file of our own, and SHELLOPTS is
        what turns the option on in the child.
        """
        fd, log = tempfile.mkstemp(prefix="probe-", suffix=".trace")
        self.addCleanup(os.unlink, log)
        env = dict(os.environ, PS4=coverage_report.PS4, SHELLOPTS="xtrace",
                   BASH_XTRACEFD=str(fd))
        try:
            proc = subprocess.run(["bash", script], cwd=self.root, env=env,
                                  capture_output=True, text=True, pass_fds=(fd,))
        finally:
            os.close(fd)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        real = os.path.realpath(script)
        hits = coverage_report.collect_shell_trace(log, {real: real}, {})
        return hits.get(real, set())

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with self.in_root(), tracing_preserved():
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = coverage_report.main(self.main_argv(*argv))
        return code, out.getvalue(), err.getvalue()

    # -- read_ledger --------------------------------------------------------

    def test_read_ledger_of_a_missing_file_is_empty(self):
        self.assertEqual(
            coverage_report.read_ledger(os.path.join(self.root, "none.txt")), [])

    def test_read_ledger_parses_comments_blanks_and_both_separators(self):
        path = self.write("ledger.txt",
                          "# a comment\n"
                          "\n"
                          "   \n"
                          "tools/a.py\ta reason\n"
                          "tools/b.py   another reason\n"
                          "tools/c.py\n")
        self.assertEqual(coverage_report.read_ledger(path),
                         [("tools/a.py", "a reason"),
                          ("tools/b.py", "another reason"),
                          ("tools/c.py", "")])

    # -- rpath --------------------------------------------------------------

    def test_rpath_of_an_unresolvable_path_is_the_path_it_was_given(self):
        # The tracer runs inside a sandbox where realpath can fail; a checker
        # must not die over a path it cannot canonicalise.
        exotic = os.path.join(self.root, "unresolvable", "mod.py")
        with mock.patch.object(os.path, "realpath",
                               side_effect=OSError("no such file or directory")):
            self.assertEqual(coverage_report.rpath(exotic), exotic)

    def test_rpath_answers_from_the_cache_after_the_first_call(self):
        target = self.write("cached.py", "x = 1\n")
        with mock.patch.object(os.path, "realpath",
                               side_effect=os.path.realpath) as real:
            first = coverage_report.rpath(target)
            second = coverage_report.rpath(target)
        self.assertEqual(first, second)
        self.assertEqual(real.call_count, 1)

    # -- tree / expand ------------------------------------------------------

    def test_tree_walks_files_once_and_skips_directories(self):
        self.write("pkg/inside.txt", "x\n")
        os.makedirs(os.path.join(self.root, "pkg", "empty-dir"))
        first = coverage_report.tree(self.root)
        self.assertIn("pkg/inside.txt", first)
        self.assertNotIn("pkg/empty-dir", first)
        self.assertIs(coverage_report.tree(self.root), first)

    def test_expand_resolves_only_patterns_that_exist(self):
        self.write("pkg/inside.txt", "x\n")
        self.write("pkg/other.log", "y\n")
        self.assertEqual(
            coverage_report.expand(self.root, [("pkg/*.txt", "a reason"),
                                               ("pkg/*.log", "a reason"),
                                               ("pkg/gone*", "a reason")]),
            [("pkg/inside.txt", "a reason"), ("pkg/other.log", "a reason")])

    # -- executable_lines ---------------------------------------------------

    def test_executable_lines_of_a_broken_module_is_none(self):
        path = self.write("broken.py", "def (\n")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertIsNone(coverage_report.executable_lines(path))
        self.assertIn("error: ", err.getvalue())
        self.assertIn("broken.py", err.getvalue())

    def test_executable_lines_walks_nested_code_objects(self):
        path = self.write("nested.py", "def outer():\n    return [x for x in (1, 2)]\n")
        self.assertEqual(coverage_report.executable_lines(path), {1, 2})

    def test_shell_executable_lines_skips_structure_and_comments(self):
        path = self.write("shape.sh",
                          "#!/usr/bin/env bash\n"   # 1 shebang: a comment to bash
                          "# a comment\n"           # 2 skipped
                          "\n"                      # 3 blank
                          "run() {\n"               # 4 a definition is not a command
                          "  local x=1\n"           # 5 bash traces this one
                          "  echo hi\n"             # 6
                          "}\n"                     # 7 brace skipped
                          "for a in 1; do\n"        # 8
                          "  :\n"                   # 9
                          "done\n"                  # 10 skipped
                          "if true; then\n"         # 11
                          "  :\n"                   # 12
                          "fi\n"                    # 13 skipped
                          "case x in\n"             # 14
                          "esac\n")                 # 15 skipped
        # The denominator is what `bash -x` can name: the shebang, the
        # function-definition head, and the bare clause keywords never produce a
        # trace line, so a script could never cover them.
        self.assertEqual(coverage_report.shell_executable_lines(path),
                         {5, 6, 8, 9, 11, 12, 14})

    # -- shell scanner: the bash -x contract --------------------------------

    def test_shell_executable_lines_is_exactly_the_traced_set(self):
        # The invariant the whole shell half rests on: a line is in the
        # denominator if and only if bash can name it. Ask bash, not the scanner.
        path = self.write("shapes.sh", SHAPES_SCRIPT)
        traced = self.trace_lines(path)
        self.assertEqual(traced, SHAPES_TRACED)
        self.assertEqual(coverage_report.shell_executable_lines(path),
                         SHAPES_TRACED)

    def test_shell_executable_lines_names_the_continuation_once_at_its_head(self):
        # A command spread over lines is one command: bash names its first line,
        # so the tail lines must not join the denominator or they are forever
        # reported uncovered.
        path = self.write("continued.sh", "printf '%s\\n' a \\\n  b \\\n  c\n")
        self.assertEqual(self.trace_lines(path), {1})
        self.assertEqual(coverage_report.shell_executable_lines(path), {1})

    def test_shell_executable_lines_puts_a_multiline_array_on_its_last_line(self):
        # A statement of assignments alone has no command word, so bash names
        # the line its last value ends on instead of the line it opens on.
        path = self.write("array.sh", "NAME=(\n  one\n  two\n)\n")
        self.assertEqual(self.trace_lines(path), {4})
        self.assertEqual(coverage_report.shell_executable_lines(path), {4})

    def test_shell_executable_lines_ignores_a_heredoc_whole(self):
        # Only the command that opens the here-document is a command; the
        # payload and its delimiter line are stdin, and no trace names them.
        path = self.write("docs.sh",
                          "cat <<'EOF'\nnot a command\nEOF\necho after\n")
        self.assertEqual(self.trace_lines(path), {1, 4})
        self.assertEqual(coverage_report.shell_executable_lines(path), {1, 4})

    def test_shell_executable_lines_keeps_a_herestring_and_a_hashed_comment(self):
        # `<<<` is a herestring: its right side is a word, not a document, so
        # the line is a command. And a `<<EOF` inside a comment must not make
        # the scanner swallow the lines below it.
        path = self.write("strings.sh",
                          "read -r x <<< 'a b'\n"
                          "echo done # shaped like <<EOF but it is a comment\n"
                          "echo last\n")
        self.assertEqual(self.trace_lines(path), {1, 2, 3})
        self.assertEqual(coverage_report.shell_executable_lines(path), {1, 2, 3})

    def test_shell_executable_lines_puts_an_escaped_quote_inside_the_value(self):
        # The shape //tools/bazel/sh/doctor.sh writes: a double-quoted value
        # holding \" and a command substitution spread over lines. An escaped
        # quote is not the end of the word, so the statement is still a bare
        # assignment and bash names the line the value ends on. Read the
        # backslash as a closing quote and the statement splits at the next
        # space, looks like a command, and asks this script to cover a line no
        # trace ever reports.
        path = self.write("json.sh",
                          'x=1\n'
                          'json_rows="{\\"a\\":\\"$( \n'
                          '  [[ "1" == "1" ]] && echo present || echo MISSING\n'
                          '  )\\",\\"b\\":\\"pin ${x}\\"}"\n'
                          'echo done\n')
        traced = self.trace_lines(path)
        self.assertEqual(traced, {1, 4, 5})
        self.assertEqual(coverage_report.shell_executable_lines(path), traced)

    def test_shell_executable_lines_counts_an_escaped_command_word_once(self):
        # A command word can be introduced by an escaped character, which is
        # where the scanner appends to the statement without seeing a token
        # start; the line is still exactly one command.
        path = self.write("escaped.sh", "\\ls -l\nprintf '%s' a\\\n b\n")
        traced = self.trace_lines(path)
        self.assertEqual(coverage_report.shell_executable_lines(path), traced)
        self.assertEqual(traced, {1, 2})

    # -- _quote_state -------------------------------------------------------

    def test_quote_state_closes_only_the_quote_it_opened(self):
        self.assertEqual(coverage_report._quote_state(False, False, ""),
                         (False, False))
        self.assertEqual(coverage_report._quote_state(False, False, "it's"),
                         (True, False))
        self.assertEqual(coverage_report._quote_state(False, False, 'say "hi"'),
                         (False, False))
        self.assertEqual(coverage_report._quote_state(False, False, 'say "hi'),
                         (False, True))
        self.assertEqual(coverage_report._quote_state(True, False, "still open"),
                         (True, False))
        self.assertEqual(coverage_report._quote_state(False, True, "still open"),
                         (False, True))
        # A double quote closes a word that was already open in one.
        self.assertEqual(coverage_report._quote_state(False, True, 'still "open'),
                         (False, False))

    def test_quote_state_treats_a_nested_quote_as_literal(self):
        # An apostrophe inside double quotes does not open a single-quoted word,
        # and a double quote inside single quotes does not open a double one.
        self.assertEqual(coverage_report._quote_state(False, False, '"a\'b"'),
                         (False, False))
        self.assertEqual(coverage_report._quote_state(False, False, "'a\"b'"),
                         (False, False))

    def test_quote_state_honours_a_backslash_escape(self):
        # Outside single quotes a backslash hides the next character, which is
        # what keeps \" from closing a double-quoted word.
        self.assertEqual(coverage_report._quote_state(False, False, 'a\\"b'),
                         (False, False))
        self.assertEqual(coverage_report._quote_state(False, False, '"a\\"b"'),
                         (False, False))
        # Inside single quotes a backslash is literal, so the quote still closes.
        self.assertEqual(coverage_report._quote_state(False, False, r"'a\'b'"),
                         (True, False))

    # -- _code_part ---------------------------------------------------------

    def test_code_part_cuts_a_trailing_comment_but_not_a_quoted_hash(self):
        self.assertEqual(coverage_report._code_part("echo hi # note", False, False),
                         ("echo hi ", False, False))
        self.assertEqual(coverage_report._code_part("echo 'a # b'", False, False),
                         ("echo 'a # b'", False, False))
        self.assertEqual(coverage_report._code_part('echo "a # b" # cut',
                                                    False, False),
                         ('echo "a # b" ', False, False))
        self.assertEqual(coverage_report._code_part("echo a#b", False, False),
                         ("echo a#b", False, False))
        self.assertEqual(coverage_report._code_part("# whole line", False, False),
                         ("", False, False))

    def test_code_part_walks_past_an_escaped_character(self):
        # A backslash hides the next character, so the quote state after the
        # line is the state the shell is really in.
        self.assertEqual(coverage_report._code_part(r"echo a\ b # cut", False, False),
                         (r"echo a\ b ", False, False))
        # An escaped quote is not a quote, so the hash after it still opens a
        # comment instead of hiding inside a word.
        self.assertEqual(coverage_report._code_part(r'echo \" # cut', False, False),
                         (r'echo \" ', False, False))
        self.assertEqual(coverage_report._code_part('echo "a\\" # still quoted',
                                                    False, False),
                         ('echo "a\\" # still quoted', False, True))

    def test_code_part_reports_an_open_quote_so_the_next_line_continues_it(self):
        self.assertEqual(coverage_report._code_part("echo 'open", False, False),
                         ("echo 'open", True, False))

    # -- heredoc_body_lines -------------------------------------------------

    def test_heredoc_body_lines_marks_the_payload_and_its_delimiter(self):
        text = "\n".join([
            "cat <<'LITERAL'",         # 1  the command, not part of the body
            "$value stays literal",    # 2  body
            "LITERAL",                 # 3  delimiter
            "cat <<-TABS",             # 4
            "\tbody padded",           # 5  body, tab-indented
            "\tTABS",                  # 6  delimiter, tab-indented
            "read x <<< 'a b'",        # 7  a herestring is not a heredoc
            "echo hi # shaped like <<EOF",  # 8 a comment is not a command
            "echo end",                # 9
            "",
        ])
        self.assertEqual(coverage_report.heredoc_body_lines(text),
                         {2, 3, 5, 6})

    def test_heredoc_body_lines_of_an_unterminated_document_runs_to_the_end(self):
        # A script that falls off the end without its delimiter has no commands
        # below the opener either; the scan must stop rather than wander.
        self.assertEqual(coverage_report.heredoc_body_lines("cat <<EOF\none\ntwo\n"),
                         {2, 3, 4})

    def test_heredoc_body_lines_of_a_script_without_heredocs_is_empty(self):
        self.assertEqual(coverage_report.heredoc_body_lines("echo one\necho two\n"),
                         set())

    # -- _bare_assignment ---------------------------------------------------

    def test_bare_assignment_accepts_a_statement_of_assignments_only(self):
        for statement in ("A=1", "A=1 B=2", "A=1 ", "count+=1",
                          "A='a b'", 'B="c d"', "A=(\n  x\n  y\n)",
                          "A=((nested))", "A=x B=(\n y\n)",
                          # The value carries escaped quotes and a space, so a
                          # scanner that reads \" as the end of the word splits
                          # the statement and calls the tail a command.
                          'json="{\\"a\\":\\"b c\\"}"',
                          'rows="{\\"k\\":\\"$( \n echo hi\n )\\"}"'):
            self.assertTrue(coverage_report._bare_assignment(statement), statement)

    def test_bare_assignment_rejects_anything_with_a_command_in_it(self):
        for statement in ("", "echo hi", "A=1 echo hi", "1A=x", "A",
                          "A=(unterminated", "A=1 (subshell)",
                          # A space the backslash does not protect still splits
                          # the word, and the tail is a command word.
                          'A=1 \\ echo'):
            self.assertFalse(coverage_report._bare_assignment(statement), statement)

    # -- exclusion_lines ----------------------------------------------------

    def test_exclusion_lines_reads_both_selector_forms(self):
        exclusions = [("a.py", "whole file"),
                      ("a.py:*", "the lot"),
                      ("a.py:12", "the shebang"),
                      ("a.py:oops", "not a number"),
                      ("b.py:7", "another module"),
                      ("a.py:7:8", "two numbers")]
        self.assertEqual(coverage_report.exclusion_lines(exclusions, "a.py"),
                         {"*", 12})

    # -- run_python_tests ---------------------------------------------------

    def test_run_python_tests_records_the_lines_the_test_touched(self):
        module = self.make_project()
        with tracing_preserved():
            hits = coverage_report.run_python_tests(
                self.root, [self.test_arg],
                [os.path.join(self.root, module + ".py")])
        real = os.path.realpath(os.path.join(self.root, module + ".py"))
        entered = hits[real]
        self.assertIn(6, entered)
        self.assertIn(10, entered)
        self.assertTrue(entered <= {1, 3, 6, 7, 10, 11, 12, 13}, entered)

    def test_run_python_tests_of_a_missing_file_is_an_error(self):
        err = io.StringIO()
        with tracing_preserved():
            with contextlib.redirect_stderr(err):
                self.assertIsNone(coverage_report.run_python_tests(
                    self.root, ["cov_test_nope.py"], []))
        self.assertIn("error: test file not found: cov_test_nope.py",
                      err.getvalue())

    def test_run_python_tests_of_a_failing_test_is_an_error(self):
        self.make_project()
        self.write("cov_test_bad.py", FAILING_TEMPLATE)
        err = io.StringIO()
        with tracing_preserved():
            with contextlib.redirect_stderr(err):
                self.assertIsNone(coverage_report.run_python_tests(
                    self.root, ["cov_test_bad.py"], []))
        self.assertIn("cov_test_bad.py failed (1 failures, 0 errors)",
                      err.getvalue())
        self.assertIn("AssertionError", err.getvalue())

    def test_run_python_tests_accepts_an_absolute_test_path(self):
        self.make_project()
        absolute = os.path.join(self.root, self.test_arg)
        with tracing_preserved():
            hits = coverage_report.run_python_tests(self.root, [absolute], [])
        self.assertEqual(hits, {})

    def test_the_installed_tracer_records_only_instrumented_frames(self):
        # Nothing else ever runs the tracer's own body: the interpreter does not
        # trace a trace function's frame while it is installed. Capture it from
        # inside the suite it is tracing and drive it with frames of our own.
        module = self.make_project()
        capture = "cov_test_capture_%d.py" % self._serial
        self.write(capture, CAPTURE_TEMPLATE.format(module=module))
        target = os.path.join(self.root, module + ".py")
        with tracing_preserved():
            hits = coverage_report.run_python_tests(self.root, [capture], [target])
        captured = sys.modules[capture[:-3]].CAPTURED
        self.assertEqual(len(captured), 1)
        tracer = captured[0]
        real = os.path.realpath(target)
        before = set(hits[real])

        # A frame of an instrumented file is recorded, and the tracer returns
        # itself so every later event in that frame keeps being reported.
        self.assertIs(tracer(_Frame(real, 999), "line", None), tracer)
        self.assertEqual(hits[real] - before, {999})
        # A frame that has not reached a statement yet has no line to record.
        tracer(_Frame(real, 0), "line", None)
        self.assertEqual(hits[real], before | {999})
        # A frame of anything else is not instrumented and must not appear.
        tracer(_Frame(os.path.join(self.root, "elsewhere.py"), 7), "call", None)
        self.assertEqual(list(hits), [real])
        # An event that is neither a call nor a line is not a statement.
        tracer(_Frame(real, 998), "return", None)
        self.assertNotIn(998, hits[real])

    # -- _load_suite --------------------------------------------------------

    def test_load_suite_reuses_the_sys_path_entry(self):
        self.make_project()
        absolute = os.path.join(self.root, self.test_arg)
        suite = coverage_report._load_suite(absolute)
        self.assertEqual(suite.countTestCases(), 2)
        self.assertIn(os.path.dirname(absolute), sys.path)
        coverage_report._load_suite(absolute)

    def test_load_suite_of_a_file_without_a_module_name_discovers(self):
        path = self.write(".py", "import unittest\n")
        suite = coverage_report._load_suite(path)
        self.assertEqual(suite.countTestCases(), 0)

    # -- collect_shell_trace ------------------------------------------------

    def test_collect_shell_trace_ignores_lines_that_are_not_a_trace(self):
        # A script that writes to stderr while xtrace points at the same file
        # (BASH_XTRACEFD unset, which is how a person runs it by hand) fills the
        # log with prose. Only a well-formed trace line may count.
        self.make_project()
        path = self.write("driver.trace",
                          "some script said this\n"
                          "++|script.sh|3|\n"
                          "|script.sh|4|\n"
                          "+|script.sh|not-a-line|\n"
                          "+|script.sh|5|echo hi\n")
        wanted = coverage_report.wanted_map([os.path.join(self.root, "script.sh")])
        real = os.path.realpath(os.path.join(self.root, "script.sh"))
        hits = coverage_report.collect_shell_trace(path, wanted, {}, self.root)
        self.assertEqual(hits, {real: {3, 5}})

    def test_collect_shell_trace_keeps_only_the_scripts_in_scope(self):
        # $BASH_SOURCE is whatever path the shell was handed: a relative name
        # resolves against the test's cwd, a path from elsewhere is dropped.
        self.make_project()
        path = self.write("driver.trace",
                          "+|/elsewhere/helper.sh|3|\n"
                          "+|helper.sh|4|\n")
        wanted = coverage_report.wanted_map([os.path.join(self.root, "helper.sh")])
        real = os.path.realpath(os.path.join(self.root, "helper.sh"))
        hits = coverage_report.collect_shell_trace(path, wanted, {}, self.root)
        self.assertEqual(hits, {real: {4}})

    # -- run_shell_tests ----------------------------------------------------

    def test_run_shell_tests_collects_only_instrumented_lines(self):
        self.make_project()
        with self.in_root(), tracing_preserved():
            hits = coverage_report.run_shell_tests(
                self.root, ["cov_test_all.sh"],
                [os.path.join(self.root, "script.sh")])
        real = os.path.realpath(os.path.join(self.root, "script.sh"))
        self.assertEqual(list(hits), [real])
        self.assertEqual(hits[real], {2, 3, 4, 5})

    def test_run_shell_tests_of_a_missing_file_is_an_error(self):
        err = io.StringIO()
        with tracing_preserved():
            with contextlib.redirect_stderr(err):
                self.assertIsNone(coverage_report.run_shell_tests(
                    self.root, ["gone.sh"], []))
        self.assertIn("error: shell test not found: gone.sh", err.getvalue())

    def test_run_shell_tests_writes_the_trace_where_the_caller_asks(self):
        # --sh-trace hands the runner a file a driver already opened; the runner
        # has to create the parent directory and reuse the path instead of
        # inventing a temporary one the driver cannot reach.
        self.make_project()
        trace = os.path.join(self.root, "cov", "deeper", "driver.trace")
        with self.in_root(), tracing_preserved():
            hits = coverage_report.run_shell_tests(
                self.root, ["cov_test_all.sh"],
                [os.path.join(self.root, "script.sh")], trace_path=trace)
        real = os.path.realpath(os.path.join(self.root, "script.sh"))
        self.assertEqual(hits[real], {2, 3, 4, 5})
        self.assertTrue(os.path.isfile(trace), "the trace was not left at " + trace)
        with open(trace, encoding="utf-8") as handle:
            body = handle.read()
        self.assertIn("+|script.sh|4|", body)

    def test_run_shell_tests_of_a_failing_script_is_an_error(self):
        self.write("cov_test_broken.sh", FAILING_SH_TEST)
        err = io.StringIO()
        with tracing_preserved():
            with contextlib.redirect_stderr(err):
                self.assertIsNone(coverage_report.run_shell_tests(
                    self.root, ["cov_test_broken.sh"], []))
        self.assertIn("cov_test_broken.sh exited 3", err.getvalue())

    # -- measure ------------------------------------------------------------

    def measure_one(self, modules, hits, exclusions, kind="py"):
        return coverage_report.measure(self.root, modules, hits, exclusions, kind)

    def test_measure_reports_the_missing_lines(self):
        module = self.make_project()
        real = os.path.realpath(os.path.join(self.root, module + ".py"))
        rows = self.measure_one([(module + ".py", "the module")],
                                {real: {6, 7}}, [], "py")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["path"], module + ".py")
        self.assertEqual(row["reason"], "the module")
        self.assertEqual(row["covered"], 2)
        self.assertEqual(row["missing"], [1, 3, 10, 11, 12, 13])
        self.assertEqual(row["excluded"], [])
        self.assertAlmostEqual(row["percent"], 100.0 * 2 / 8)

    def test_measure_honours_a_line_exclusion(self):
        module = self.make_project()
        real = os.path.realpath(os.path.join(self.root, module + ".py"))
        rows = self.measure_one([(module + ".py", "the module")], {real: {6, 7}},
                                [(module + ".py:1", "docstring"),
                                 (module + ".py:3", "constant"),
                                 (module + ".py:10", "unused"),
                                 (module + ".py:11", "unused"),
                                 (module + ".py:12", "unused"),
                                 (module + ".py:13", "unused")], "py")
        self.assertEqual(rows[0]["missing"], [])
        self.assertEqual(rows[0]["excluded"], [1, 3, 10, 11, 12, 13])
        self.assertEqual(rows[0]["percent"], 100.0)

    def test_measure_treats_a_star_exclusion_as_the_whole_file(self):
        module = self.make_project()
        rows = self.measure_one([(module + ".py", "vendored")], {},
                                [(module + ".py:*", "vendored code")], "py")
        self.assertEqual(rows[0]["excluded"], "all")
        self.assertEqual(rows[0]["percent"], 100.0)
        self.assertEqual(rows[0]["missing"], [])

    def test_measure_of_a_module_with_nothing_to_cover_is_full(self):
        self.write("empty.py", "# nothing executable\n")
        rows = self.measure_one([("empty.py", "no statements")], {}, [], "py")
        self.assertEqual(rows[0]["total"], 0)
        self.assertEqual(rows[0]["percent"], 100.0)

    def test_measure_of_a_broken_python_module_is_none(self):
        self.write("broken.py", "def (\n")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertIsNone(
                self.measure_one([("broken.py", "broken")], {}, [], "py"))
        self.assertIn("invalid syntax", err.getvalue())

    def test_measure_of_a_shell_module_counts_the_script_lines(self):
        self.make_project()
        real = os.path.realpath(os.path.join(self.root, "script.sh"))
        rows = self.measure_one([("script.sh", "the script")],
                                {real: {2, 3}}, [("script.sh:1", "shebang")], "sh")
        self.assertEqual(rows[0]["total"], 4)
        self.assertEqual(rows[0]["missing"], [4, 5])

    # -- main: the ledgers --------------------------------------------------

    def test_main_needs_a_scope_ledger(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = coverage_report.main(["--root", self.root])
        self.assertEqual(code, 2)
        self.assertIn("scope ledger tools/bazel/coverage-scope.txt is empty "
                      "or missing", err.getvalue())

    def test_main_rejects_an_entry_without_a_reason(self):
        self.make_project()
        self.ledger("py-scope.txt", (self.tiny + ".py", ""))
        code, _, err = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh")
        self.assertEqual(code, 1)
        self.assertIn("carries no reason", err)

    # -- main: the happy path ----------------------------------------------

    def test_main_reports_a_clean_run_at_the_floor(self):
        self.make_project()
        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh")
        self.assertEqual(code, 0, out)
        self.assertIn("summary: 3 modules | 7/7 lines | 100.00% | floor 100.00%",
                      out)
        self.assertIn("OK ", out)

    def test_main_json_reports_every_module_row(self):
        self.make_project()
        code, out, _ = self.run_main("--test", self.test_arg, "--json",
                                     "--sh-test", "cov_test_all.sh")
        self.assertEqual(code, 0, out)
        payload = json.loads(out)
        self.assertEqual(payload["total_lines"], 7)
        self.assertEqual(payload["covered_lines"], 7)
        self.assertEqual(payload["percent"], 100.0)
        self.assertEqual(payload["floor"], 100.0)
        self.assertEqual(payload["stale_scope"], [])
        self.assertEqual([row["path"] for row in payload["modules"]],
                         [self.tiny + ".py", "script.sh", "helper.sh"])
        self.assertEqual(payload["modules"][0]["missing"], [])

    def test_main_flags_a_module_below_the_floor(self):
        self.make_project()
        # A module the test file never imports: it is in scope with not one
        # line executed, so the run has to fail the floor instead of reporting
        # a clean 100%.
        self.write("never_imported.py", MOD_TEMPLATE)
        self.ledger("py-scope.txt", ("never_imported.py", "no test imports it"))
        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh")
        self.assertEqual(code, 1, out)
        self.assertIn("LOW", out)
        self.assertIn("is below the 100.00% floor", out)
        self.assertIn("add the missing tests or record a reasoned exclusion", out)

    def test_main_only_measures_paths_matching_the_filter(self):
        self.make_project()
        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh",
                                     "--only", "*helper.sh")
        self.assertEqual(code, 0, out)
        self.assertNotIn("script.sh", out)
        self.assertIn("helper.sh", out)
        self.assertIn("summary: 1 modules | 1/1 lines", out)

    def test_main_folds_a_supplied_shell_trace_into_the_measure(self):
        # The coverage wrapper cannot be its own shell test: it is the thing
        # running. It hands its own xtrace over with --sh-trace, and lines that
        # no unit test executed have to count from that file alone.
        self.make_project()
        self.write("later.sh", SCRIPT)
        self.ledger("sh-scope.txt", ("script.sh", "the script"),
                    ("helper.sh", "the helper"),
                    ("later.sh", "traced by the driver, not by a test"))
        self.ledger("exclusions.txt", ("script.sh:1", "shebang"),
                    ("helper.sh:1", "shebang"), ("later.sh:1", "shebang"))
        self.write("driver.trace",
                   "".join("+|later.sh|%d|\n" % n for n in (2, 3, 4, 5)))

        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh")
        self.assertEqual(code, 1, out)
        self.assertIn("LOW", out)

        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh",
                                     "--sh-trace", "driver.trace")
        self.assertEqual(code, 0, out)
        self.assertIn("OK  later.sh", out)
        self.assertIn("summary: 4 modules | 11/11 lines", out)

    def test_main_lists_stale_scope_entries_when_the_ledger_is_strict(self):
        self.make_project()
        self.ledger("py-scope.txt", (self.tiny + ".py", "measured"),
                    ("pkg/gone.py", "deleted module"))
        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh",
                                     "--strict-ledger")
        self.assertEqual(code, 1)
        self.assertIn("STALE  scope entry 'pkg/gone.py' matches no module", out)
        self.assertIn("summary: 3 modules", out)

    def test_main_json_lists_stale_scope_entries(self):
        self.make_project()
        self.ledger("sh-scope.txt", ("script.sh", "measured"),
                    ("other.sh", "gone again"))
        code, out, _ = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh",
                                     "--strict-ledger", "--json")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["stale_scope"], ["other.sh"])

    # -- main: environment errors ------------------------------------------

    def test_main_exits_two_when_a_test_file_is_missing(self):
        self.make_project()
        code, _, err = self.run_main("--test", "no_such_test.py")
        self.assertEqual(code, 2)
        self.assertIn("test file not found", err)

    def test_main_exits_two_when_a_shell_test_is_missing(self):
        self.make_project()
        code, _, err = self.run_main("--test", self.test_arg,
                                     "--sh-test", "no_such_test.sh")
        self.assertEqual(code, 2)
        self.assertIn("shell test not found", err)

    def test_main_exits_two_when_a_supplied_shell_trace_is_missing(self):
        # A driver that died before it wrote its trace must not leave the lane
        # measuring nothing and calling it complete.
        self.make_project()
        code, _, err = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_all.sh",
                                     "--sh-trace",
                                     os.path.join(self.root, "gone.trace"))
        self.assertEqual(code, 2)
        self.assertIn("shell trace not found", err)

    def test_main_exits_two_when_a_test_fails(self):
        self.make_project()
        self.write("cov_test_bad.py", FAILING_TEMPLATE)
        code, _, err = self.run_main("--test", "cov_test_bad.py")
        self.assertEqual(code, 2)
        self.assertIn("failed (", err)

    def test_main_exits_two_when_a_shell_test_fails(self):
        self.make_project()
        self.write("cov_test_broken.sh", FAILING_SH_TEST)
        code, _, err = self.run_main("--test", self.test_arg,
                                     "--sh-test", "cov_test_broken.sh")
        self.assertEqual(code, 2)
        self.assertIn("exited 3", err)

    def test_main_exits_two_when_a_measured_module_does_not_compile(self):
        self.make_project()
        self.ledger("py-scope.txt", (self.tiny + ".py", "measured"),
                    ("broken.py", "syntax trouble"))
        self.write("broken.py", "def (\n")
        out, err = io.StringIO(), io.StringIO()
        with tracing_preserved():
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = coverage_report.main(self.main_argv(
                    "--test", self.test_arg, "--sh-test", "cov_test_all.sh"))
        self.assertEqual(code, 2)
        self.assertIn("invalid syntax", err.getvalue())

    # -- module entry point -------------------------------------------------

    def test_module_main_exits_with_the_reporter_code(self):
        import runpy
        checker = os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))), "coverage_report.py")
        self.make_project()
        argv = ["coverage_report.py"] + self.main_argv(
            "--test", self.test_arg, "--sh-test", "cov_test_all.sh")
        with self.in_root(), tracing_preserved():
            with mock.patch.object(sys, "argv", argv):
                with contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as caught:
                        runpy.run_path(checker, run_name="__main__")
        self.assertEqual(caught.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
