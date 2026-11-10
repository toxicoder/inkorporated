#!/usr/bin/env python3
"""Unit tests for tools/bazel/owned_files_check.py.

Repositories are real throwaway `git init` trees so `git ls-files` is
exercised for real; only the `bazelisk query` shelling out is faked, because a
nested Bazel invocation would make the unit test depend on a warm output base.

    python3 tools/bazel/test/test_owned_files_check.py
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

import owned_files_check  # noqa: E402

REAL_RUN = subprocess.run


def make_repo(root, files):
    """Create a git repository whose index holds exactly `files`."""
    REAL_RUN(["git", "-c", "init.defaultBranch=main", "init", "-q", root],
             check=True, capture_output=True)
    for rel, content in files.items():
        path = os.path.join(root, rel)
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)
    REAL_RUN(["git", "-C", root, "add", "-A"], check=True, capture_output=True)
    return root


def label_for(rel):
    pkg, _, name = rel.rpartition("/")
    return "//%s:%s" % (pkg, name)


def stubbed_bazelisk(labels, calls):
    """Answer `bazelisk query` with `labels`; let every other command run."""
    def fake(cmd, *args, **kwargs):
        if cmd and cmd[0] == "bazelisk":
            calls.append(list(cmd))
            return subprocess.CompletedProcess(cmd, 0, "\n".join(labels) + "\n", "")
        return REAL_RUN(cmd, *args, **kwargs)
    return fake


class OwnedFilesCheckTestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._serial = 0
        self.calls = []
        # The checker keeps the nested-query arguments in a module global.
        self.addCleanup(setattr, owned_files_check, "BAZEL_ARGS", [])
        owned_files_check.BAZEL_ARGS = []

    def repo(self, files):
        self._serial += 1
        return make_repo(os.path.join(self._tmp.name, "repo%d" % self._serial), files)

    def patch_bazelisk(self, labels):
        return mock.patch.object(owned_files_check.subprocess, "run",
                                 side_effect=stubbed_bazelisk(labels, self.calls))

    def run_main(self, root, *argv):
        out, err = io.StringIO(), io.StringIO()
        argv = ["owned_files_check.py", "--root", root] + list(argv)
        with mock.patch.object(sys, "argv", argv):
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = owned_files_check.main()
        return code, out.getvalue(), err.getvalue()

    # -- label_to_path ------------------------------------------------------

    def test_label_to_path_maps_a_regular_label(self):
        self.assertEqual(owned_files_check.label_to_path("//pkg:file"), "pkg/file")

    def test_label_to_path_maps_a_root_package_label(self):
        # The bug the docstring warns about: `//:foo` must not become `/foo`.
        self.assertEqual(owned_files_check.label_to_path("//:foo"), "foo")

    def test_label_to_path_strips_a_canonical_repo_prefix(self):
        self.assertEqual(owned_files_check.label_to_path("@@//pkg:file"), "pkg/file")

    def test_label_to_path_strips_a_repo_prefix(self):
        # The docstring promises `@@repo//pkg:file -> pkg/file`; the two `@`
        # strips only ever produce a `//` label when no repo *name* is given,
        # so a repo-qualified label maps to nothing and is dropped instead.
        self.assertIsNone(owned_files_check.label_to_path("@rules_x//pkg:file"))
        self.assertIsNone(owned_files_check.label_to_path("@@rules_x//pkg:file"))

    def test_label_to_path_rejects_a_label_without_a_target(self):
        self.assertIsNone(owned_files_check.label_to_path("//pkg"))
        self.assertIsNone(owned_files_check.label_to_path("pkg:file"))
        self.assertIsNone(owned_files_check.label_to_path(""))

    # -- is_control_plane ---------------------------------------------------

    def test_is_control_plane_recognises_the_workspace_files(self):
        for path in (".bazelrc", ".bazelversion", "MODULE.bazel",
                     "MODULE.bazel.lock", "WORKSPACE.bazel", "REPO.bazel",
                     "sub/MODULE.bazel", "sub/WORKSPACE", "IDE.bazelproject",
                     "BUILD", "pkg/BUILD.bazel"):
            self.assertTrue(owned_files_check.is_control_plane(path), path)

    def test_is_control_plane_rejects_an_ordinary_file(self):
        for path in ("pkg/data.json", "BUILD.md", "MODULES.txt", "README"):
            self.assertFalse(owned_files_check.is_control_plane(path), path)

    # -- read_ledger --------------------------------------------------------

    def test_read_ledger_parses_the_supported_shapes(self):
        path = os.path.join(self._tmp.name, "ledger.txt")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("# a comment line\n")
            handle.write("\n")
            handle.write("   \n")
            handle.write("docs/generated/*\tgenerated by the docs job\n")
            handle.write("infra/*.tf   terraform is validated elsewhere\n")
            handle.write("secrets/manifests.yaml\n")
        entries = owned_files_check.read_ledger(path)
        self.assertEqual([(pattern, reason) for _, pattern, reason in entries],
                         [("docs/generated/*", "generated by the docs job"),
                          ("infra/*.tf", "terraform is validated elsewhere"),
                          ("secrets/manifests.yaml", "")])
        self.assertTrue(entries[0][0].match("docs/generated/a.md"))
        self.assertIsNone(entries[0][0].match("docs/a.txt"))

    def test_read_ledger_of_a_missing_file_is_empty(self):
        self.assertEqual(
            owned_files_check.read_ledger(os.path.join(self._tmp.name, "nope")),
            [])

    def test_ledger_pattern_matches_with_glob_wildcards(self):
        path = os.path.join(self._tmp.name, "ledger.txt")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("docs/?.md\tshort name\n")
            handle.write("docs/*.md\tgenerated\n")
        entries = owned_files_check.read_ledger(path)
        regexes = [(pattern, regex) for regex, pattern, _ in entries]
        self.assertTrue(regexes[0][1].match("docs/a.md"))
        self.assertIsNone(regexes[0][1].match("docs/ab.md"))
        self.assertTrue(regexes[1][1].match("docs/anything/deep.md"))
        self.assertIsNone(regexes[1][1].match("docs/anything/deep.txt"))

    # -- bazel_ignored_dirs -------------------------------------------------

    def test_bazel_ignored_dirs_reads_and_normalises_the_file(self):
        root = self.repo({".bazelignore": "/vendor/\n\n# comment\nnode_modules # trailing\n"})
        self.assertEqual(owned_files_check.bazel_ignored_dirs(root),
                         {"vendor", "node_modules"})

    def test_bazel_ignored_dirs_without_the_file_is_empty(self):
        root = self.repo({"a.txt": "a\n"})
        self.assertEqual(owned_files_check.bazel_ignored_dirs(root), set())

    # -- run / owned_paths --------------------------------------------------

    def test_run_returns_stdout_when_the_command_succeeds(self):
        with mock.patch.object(owned_files_check.subprocess, "run",
                               return_value=subprocess.CompletedProcess(
                                   ["true"], 0, "out\n", "")):
            self.assertEqual(owned_files_check.run(["true"], "."), "out\n")

    def test_run_exits_two_and_echoes_the_stderr_on_failure(self):
        err = io.StringIO()
        with mock.patch.object(owned_files_check.subprocess, "run",
                               return_value=subprocess.CompletedProcess(
                                   ["false"], 1, "", "boom")):
            with contextlib.redirect_stderr(err):
                with self.assertRaises(SystemExit) as caught:
                    owned_files_check.run(["false"], ".")
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("boom", err.getvalue())

    def test_owned_paths_keeps_only_mappable_labels(self):
        query_out = "\n".join([
            "//pkg:file.txt",
            "@@//pkg:other.txt",
            "@repo//pkg:third.txt",          # repo-qualified: dropped
            "//:root.txt",
            "  //pkg:stripped.txt  ",
            "Loading: 0 packages loaded",
            "//no-target-separator",
            "",
        ]) + "\n"
        with mock.patch.object(owned_files_check.subprocess, "run",
                               return_value=subprocess.CompletedProcess(
                                   ["bazelisk"], 0, query_out, "")):
            self.assertEqual(
                owned_files_check.owned_paths("."),
                {"pkg/file.txt", "pkg/other.txt", "root.txt",
                 "pkg/stripped.txt"})

    def test_owned_paths_passes_the_bazel_args_through(self):
        owned_files_check.BAZEL_ARGS = ["--output_base=/tmp/b", "--noworkspace_rc"]
        with self.patch_bazelisk([]):
            owned_files_check.owned_paths(".")
        self.assertEqual(self.calls[0][:4],
                         ["bazelisk", "--output_base=/tmp/b", "--noworkspace_rc",
                          "query"])

    # -- main: the buckets --------------------------------------------------

    def test_every_file_owned_by_a_target_is_clean(self):
        root = self.repo({"pkg/a.txt": "a\n", "pkg/b.txt": "b\n"})
        with self.patch_bazelisk(["//pkg:a.txt", "//pkg:b.txt"]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("2 tracked | 2 target-owned | 0 control-plane | "
                      "0 ledger-excluded (reasoned) | 0 unowned | "
                      "0 stale ledger entries", out)

    def test_a_file_no_target_owns_is_reported(self):
        root = self.repo({"pkg/a.txt": "a\n", "pkg/loose.txt": "b\n"})
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("UNOWNED pkg/loose.txt", out)
        self.assertIn("no target owns it and no ledger entry covers it", out)
        self.assertIn("2 tracked | 1 target-owned", out)

    def test_control_plane_files_are_never_asked_for(self):
        root = self.repo({
            ".bazelrc": "build --x=1\n", ".bazelversion": "1\n",
            "MODULE.bazel": "module()\n", "MODULE.bazel.lock": "{}\n",
            "IDE.bazelproject": "//...\n", "BUILD.bazel": "x = 1\n",
            "pkg/BUILD": "y = 2\n", "WORKSPACE.bazel": "z = 3\n",
        })
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("8 tracked | 0 target-owned | 8 control-plane", out)

    def test_bazelignore_dirs_are_exempt_without_a_ledger_entry(self):
        root = self.repo({
            ".bazelignore": "vendor\n",
            "vendor/lib.py": "x = 1\n",
            "vendored/lib.py": "y = 1\n",
            "pkg/a.txt": "a\n",
        })
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("UNOWNED vendored/lib.py", out)
        self.assertNotIn("UNOWNED vendor/lib.py", out)
        self.assertIn("2 control-plane", out)

    # -- main: the ledger ---------------------------------------------------

    def write_ledger(self, root, name, text):
        path = os.path.join(root, name)
        parent = os.path.dirname(path)
        if parent != root:
            os.makedirs(parent, exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        return path

    def test_a_reasoned_ledger_entry_excludes_the_file(self):
        root = self.repo({"docs/generated/index.md": "x\n"})
        self.write_ledger(root, "bazel-unowned.txt",
                          "docs/generated/*\twritten by the generator\n")
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("1 tracked | 0 target-owned | 0 control-plane | "
                      "1 ledger-excluded (reasoned) | 0 unowned", out)

    def test_a_ledger_entry_without_a_reason_is_still_unowned(self):
        root = self.repo({"docs/generated/index.md": "x\n"})
        self.write_ledger(root, "bazel-unowned.txt", "docs/generated/*\n")
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("UNOWNED docs/generated/index.md", out)
        self.assertIn("ledger entry carries no reason", out)

    def test_the_ledger_path_may_be_absolute(self):
        root = self.repo({"docs/x.md": "x\n"})
        ledger = self.write_ledger(self._tmp.name, "elsewhere/ledger.txt",
                                   "docs/x.md\tsites live outside the graph\n")
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root, "--ledger", ledger)
        self.assertEqual(code, 0, out)
        self.assertIn("1 ledger-excluded", out)

    def test_a_stale_entry_is_a_warning_until_the_ledger_is_strict(self):
        root = self.repo({"pkg/a.txt": "a\n"})
        self.write_ledger(root, "bazel-unowned.txt", "docs/gone.md\tstale claim\n")
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("1 stale ledger entries", out)

        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root, "--strict-ledger")
        self.assertEqual(code, 1)
        self.assertIn("UNOWNED docs/gone.md  (ledger entry matches nothing "
                      "(stale))", out)

    # -- main: environment errors and output shapes -------------------------

    def test_an_empty_index_is_an_environment_error(self):
        root = self.repo({})
        code, _, err = self.run_main(root)
        self.assertEqual(code, 2)
        self.assertIn("error: git ls-files returned nothing", err)

    def test_json_output_reports_the_buckets(self):
        root = self.repo({
            "pkg/a.txt": "a\n", "pkg/loose.txt": "b\n",
            "docs/x.md": "c\n", "MODULE.bazel": "m\n",
        })
        self.write_ledger(root, "bazel-unowned.txt", "docs/x.md\tdocs are prose\n")
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root, "--json")
        self.assertEqual(code, 1)
        payload = json.loads(out)
        self.assertEqual(payload["tracked"], 4)
        self.assertEqual(payload["control_plane"], 1)
        self.assertEqual(payload["excluded"], 1)
        self.assertEqual(payload["target_owned"], 1)
        self.assertEqual(payload["owned_labels"], 1)
        self.assertEqual(payload["stale_ledger"], [])
        self.assertEqual(payload["unowned"],
                         [{"path": "pkg/loose.txt",
                           "why": "no target owns it and no ledger entry "
                                  "covers it"}])

    def test_json_output_is_clean_when_everything_is_owned(self):
        root = self.repo({"pkg/a.txt": "a\n"})
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, out, _ = self.run_main(root, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["target_owned"], 1)

    # -- main: --bazel-args -------------------------------------------------

    def test_bazel_args_are_split_into_the_module_global(self):
        root = self.repo({"pkg/a.txt": "a\n"})
        with self.patch_bazelisk(["//pkg:a.txt"]):
            code, _, _ = self.run_main(root, "--bazel-args",
                                       "--output_base=/tmp/b --lockfile_mode=off")
        self.assertEqual(code, 0)
        self.assertEqual(owned_files_check.BAZEL_ARGS,
                         ["--output_base=/tmp/b", "--lockfile_mode=off"])
        self.assertEqual(self.calls[0][1:3],
                         ["--output_base=/tmp/b", "--lockfile_mode=off"])

    def test_bazel_args_default_to_nothing(self):
        root = self.repo({"pkg/a.txt": "a\n"})
        with self.patch_bazelisk(["//pkg:a.txt"]):
            self.run_main(root)
        self.assertEqual(owned_files_check.BAZEL_ARGS, [])
        self.assertEqual(self.calls[0][0:2], ["bazelisk", "query"])

    # -- module entry point -------------------------------------------------

    def test_module_main_exits_with_the_checker_code(self):
        import runpy
        checker = os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))), "owned_files_check.py")
        root = self.repo({"pkg/loose.txt": "b\n"})
        with self.patch_bazelisk([]):
            with mock.patch.object(sys, "argv", ["owned_files_check.py",
                                                 "--root", root]):
                with contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as caught:
                        runpy.run_path(checker, run_name="__main__")
        self.assertEqual(caught.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
