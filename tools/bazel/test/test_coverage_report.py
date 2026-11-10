#!/usr/bin/env python3
"""Unit tests for tools/bazel/coverage_report.py.

The runner is pointed at scratch trees it builds itself: a small Python module
plus the unittest that covers it, and a small shell script plus the script that
runs it under xtrace. Nothing here touches the repository.

    python3 tools/bazel/test/test_coverage_report.py
"""

import contextlib
import io
import json
import os
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
                          "#!/usr/bin/env bash\n"   # 1 shebang counts
                          "# a comment\n"           # 2 skipped
                          "\n"                      # 3 blank
                          "run() {\n"               # 4
                          "  local x=1\n"           # 5 local is skipped
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
        self.assertEqual(coverage_report.shell_executable_lines(path),
                         {1, 4, 6, 8, 9, 11, 12, 14})

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
        self.ledger("py-scope.txt", (self.module + ".py", "partly tested"))
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
