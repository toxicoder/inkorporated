#!/usr/bin/env python3
"""Unit tests for tools/bazel/glob_budget.py.

Runs the checker against throwaway git repositories built in a temporary
directory, so the file walking exercises `git ls-files` for real, and asserts
on the exit code and the captured output.

    bazelisk test //tools/bazel/sh:coverage --test_arg=--only=test_glob_budget
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

import glob_budget  # noqa: E402

POLICY = "# glob-policy: payload directory grows by design"


def make_repo(root, files):
    """Create a git repository whose index holds exactly `files`."""
    subprocess.run(["git", "-c", "init.defaultBranch=main", "init", "-q", root],
                   check=True, capture_output=True)
    for rel, content in files.items():
        path = os.path.join(root, rel)
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)
    subprocess.run(["git", "-C", root, "add", "-A"], check=True,
                   capture_output=True)
    return root


def script(*lines):
    return "\n".join(lines) + "\n"


def run_main(argv):
    """Invoke glob_budget.main() with argv patched, capturing both streams."""
    out, err = io.StringIO(), io.StringIO()
    with mock.patch.object(sys, "argv", ["glob_budget.py"] + argv):
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = glob_budget.main()
    return code, out.getvalue(), err.getvalue()


class GlobBudgetTestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = self._tmp.name
        self._serial = 0

    def repo(self, files):
        """Materialise a throwaway repository under this test's temp dir."""
        self._serial += 1
        return make_repo(os.path.join(self._tmp.name, "repo%d" % self._serial), files)

    # -- tracked_build_files ------------------------------------------------

    def test_tracked_build_files_keeps_only_bazel_surfaces(self):
        root = self.repo({
            "BUILD": "x = 1\n",
            "pkg/BUILD.bazel": "y = 2\n",
            "build/defs.bzl": "z = 3\n",
            ".bazelrc": "build --x=1\n",
            "README.md": "not bazel\n",
            "pkg/BUILD.bazel.txt": "not bazel either\n",
        })
        self.assertEqual(
            sorted(glob_budget.tracked_build_files(root)),
            [".bazelrc", "BUILD", "build/defs.bzl", "pkg/BUILD.bazel"])

    def test_tracked_build_files_in_a_non_repo_yields_nothing(self):
        # git ls-files fails here and the checker has no return-code check, so
        # the walk simply yields no file.
        self.assertEqual(glob_budget.tracked_build_files(self.root), [])

    # -- rule: annotated vs unannotated ------------------------------------

    def test_annotated_glob_is_clean(self):
        root = self.repo({"BUILD": script(
            "filegroup(",
            '    name = "srcs",',
            POLICY,
            '    srcs = glob(["*.txt"]),',
            ")",
        )})
        code, out, _ = run_main(["--root", root])
        self.assertEqual(code, 0)
        self.assertIn("1 glob() in 1 BUILD files", out)
        self.assertIn("budget any", out)
        self.assertIn("0 unannotated", out)

    def test_unannotated_glob_is_a_violation(self):
        root = self.repo({"BUILD": script(
            "filegroup(",
            '    name = "srcs",',
            '    srcs = glob(["*.txt"]),',
            ")",
        )})
        code, out, _ = run_main(["--root", root])
        self.assertEqual(code, 1)
        self.assertIn("UNANNOTATED BUILD:3", out)
        self.assertIn('glob(["*.txt"])', out)
        self.assertIn("1 unannotated", out)

    def test_policy_comment_may_sit_within_the_context_window(self):
        root = self.repo({"BUILD": script(
            "",                # line 1
            POLICY,            # line 2 -- exactly three lines above the glob
            "",                # line 3
            "x = 1",           # line 4
            'glob(["*.txt"]),',  # line 5
        )})
        code, out, _ = run_main(["--root", root, "--context", "3"])
        self.assertEqual(code, 0, out)

    def test_policy_comment_outside_the_context_window_is_not_enough(self):
        root = self.repo({"BUILD": script(
            POLICY,            # line 1 -- four lines above the glob
            "a = 1", "b = 2", "c = 3", "d = 4",
            'glob(["*.txt"]),',  # line 6
        )})
        code, out, _ = run_main(["--root", root, "--context", "3"])
        self.assertEqual(code, 1)
        self.assertIn("UNANNOTATED BUILD:6", out)

    def test_inline_policy_comment_on_the_glob_line_counts(self):
        root = self.repo({"BUILD": script(
            'srcs = glob(["*.txt"]),  # GLOB-POLICY: grows by design',
        )})
        code, out, _ = run_main(["--root", root])
        self.assertEqual(code, 0, out)

    def test_a_glob_shaped_word_is_not_a_glob_call(self):
        root = self.repo({"pkg/defs.bzl": script(
            "ctx.glob(",          # attribute access, not a call to glob()
            "myglob(",            # identifier ends in glob
            "globus(",            # not a call at all
            'real = glob(["*.txt"]),  ' + POLICY,
        )})
        code, out, _ = run_main(["--root", root])
        self.assertEqual(code, 0, out)
        self.assertIn("1 glob() in 1 BUILD files", out)

    # -- budget -------------------------------------------------------------

    def test_budget_exceeded_fails_even_when_every_glob_is_annotated(self):
        root = self.repo({
            "BUILD": script("a = glob([\"*.txt\"])  " + POLICY,
                            "b = glob([\"*.md\"])  " + POLICY),
            "pkg/BUILD": script("c = glob([\"*.yml\"])  " + POLICY),
        })
        code, out, _ = run_main(["--root", root, "--max", "2"])
        self.assertEqual(code, 1)
        self.assertIn("3 glob() exceeds the budget of 2", out)
        self.assertIn("lower --max", out)

    def test_budget_met_is_clean_and_files_sort_by_count(self):
        root = self.repo({
            "aaa/BUILD": script("a = glob([\"1\"])  " + POLICY),
            "zzz/BUILD": script("a = glob([\"1\"])  " + POLICY,
                                "b = glob([\"2\"])  " + POLICY),
        })
        code, out, _ = run_main(["--root", root, "--max", "3"])
        self.assertEqual(code, 0, out)
        self.assertIn("3 glob() in 2 BUILD files, budget 3", out)
        lines = [ln for ln in out.splitlines() if ln.startswith("  ")]
        self.assertTrue(lines[0].endswith("zzz/BUILD"), lines)
        self.assertTrue(lines[1].endswith("aaa/BUILD"), lines)

    # -- output shapes ------------------------------------------------------

    def test_json_output_reports_every_field(self):
        root = self.repo({
            "BUILD": script("a = glob([\"*.txt\"])  " + POLICY),
            "pkg/BUILD": script("b = glob([\"*.md\"])"),
        })
        code, out, _ = run_main(["--root", root, "--max", "0", "--json"])
        self.assertEqual(code, 1)
        payload = json.loads(out)
        self.assertEqual(payload["total"], 2)
        self.assertEqual(payload["max"], 0)
        self.assertTrue(payload["budget_hit"])
        self.assertEqual(payload["per_file"], {"BUILD": 1, "pkg/BUILD": 1})
        self.assertEqual(payload["unannotated"],
                         [{"file": "pkg/BUILD", "line": 1,
                           "text": "b = glob([\"*.md\"])"}])

    def test_json_output_when_clean(self):
        root = self.repo({"BUILD": script("a = glob([\"*.txt\"])  " + POLICY)})
        code, out, _ = run_main(["--root", root, "--json"])
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertEqual(payload["budget_hit"], False)
        self.assertEqual(payload["max"], -1)
        self.assertEqual(payload["unannotated"], [])

    def test_long_offending_line_is_truncated(self):
        root = self.repo({"BUILD": "x = glob([" + "\"" + "a" * 120 + "\"])\n"})
        code, out, _ = run_main(["--root", root])
        self.assertEqual(code, 1)
        offender = [ln for ln in out.splitlines() if ln.startswith("UNANNOTATED")][0]
        self.assertLessEqual(len(offender.split("  ", 2)[-1]), 90)

    # -- environment errors -------------------------------------------------

    def test_unreadable_build_file_is_an_environment_error(self):
        root = self.repo({"BUILD": "a = glob([\"*.txt\"])\n"})
        os.makedirs(os.path.join(root, "pkg"))
        os.symlink(os.path.join(root, "gone"), os.path.join(root, "pkg", "BUILD"))
        subprocess.run(["git", "-C", root, "add", "-A"], check=True,
                       capture_output=True)
        code, _, err = run_main(["--root", root])
        self.assertEqual(code, 2)
        self.assertIn("error: cannot read pkg/BUILD:", err)

    # -- module entry point -------------------------------------------------

    def test_module_main_exits_with_the_checker_code(self):
        root = self.repo({"BUILD": "a = glob([\"*.txt\"])\n"})
        import runpy
        with mock.patch.object(sys, "argv", ["glob_budget.py", "--root", root]):
            with contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as caught:
                    runpy.run_path(os.path.join(os.path.dirname(
                        os.path.dirname(os.path.abspath(__file__))),
                        "glob_budget.py"), run_name="__main__")
        self.assertEqual(caught.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
