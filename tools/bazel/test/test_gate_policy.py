#!/usr/bin/env python3
"""Unit tests for tools/bazel/gate_policy.py.

Every rule (A script paths, B dangling labels, C optional-binary guards) is
exercised in isolation against throwaway repositories, together with the three
escape hatches, the label mapper, and the printed and JSON report shapes.

    python3 tools/bazel/test/test_gate_policy.py
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

import gate_policy  # noqa: E402

REAL_RUN = subprocess.run
REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          os.pardir, os.pardir, os.pardir))
DOCTOR = os.path.join("tools", "bazel", "sh", "doctor.sh")


def make_repo(root, files):
    """Create a git repository whose index holds exactly `files`."""
    REAL_RUN(["git", "-c", "init.defaultBranch=main", "init", "-q", root],
             check=True, capture_output=True)
    for rel, content in files.items():
        path = os.path.join(root, rel)
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        mode = "wb" if isinstance(content, bytes) else "w"
        with open(path, mode, encoding=None if mode == "wb" else "utf-8") as handle:
            handle.write(content)
    REAL_RUN(["git", "-C", root, "add", "-A"], check=True, capture_output=True)
    return root


class _Match(object):
    """Stand-in for re.Match so invocation_token can be tested directly."""

    def __init__(self, path, whole):
        self._path = path
        self._whole = whole

    def group(self, key=0):
        if key == "path":
            return self._path
        return self._whole


class GatePolicyTestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._serial = 0
        self.calls = []
        self.addCleanup(gate_policy._LINES_CACHE.clear)
        gate_policy._LINES_CACHE.clear()
        self.addCleanup(setattr, gate_policy, "BAZEL_ARGS", [])
        gate_policy.BAZEL_ARGS = []

    def repo(self, files):
        self._serial += 1
        return make_repo(os.path.join(self._tmp.name, "repo%d" % self._serial), files)

    def patch_bazelisk(self, labels, returncode=0, stderr=""):
        def fake(cmd, *args, **kwargs):
            if cmd and cmd[0] == "bazelisk":
                self.calls.append(list(cmd))
                return subprocess.CompletedProcess(cmd, returncode,
                                                   "\n".join(labels) + "\n", stderr)
            return REAL_RUN(cmd, *args, **kwargs)
        return mock.patch.object(gate_policy.subprocess, "run", side_effect=fake)

    def run_main(self, root, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = gate_policy.main(["--root", root] + list(argv))
            except SystemExit as exc:                      # pragma: no cover
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    # -- tracked_files / read_lines ----------------------------------------

    def test_tracked_files_lists_the_index(self):
        root = self.repo({"a.md": "x\n", "b.sh": "y\n"})
        self.assertEqual(gate_policy.tracked_files(root), ["a.md", "b.sh"])

    def test_tracked_files_of_a_broken_git_is_an_environment_error(self):
        err = io.StringIO()
        with mock.patch.object(gate_policy.subprocess, "run",
                               return_value=subprocess.CompletedProcess(
                                   ["git"], 128, "", "not a git repo")):
            with contextlib.redirect_stderr(err):
                with self.assertRaises(SystemExit) as caught:
                    gate_policy.tracked_files(self._tmp.name)
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("not a git repo", err.getvalue())

    def test_read_lines_of_a_present_file(self):
        root = self.repo({"a.md": "one\ntwo\n"})
        self.assertEqual(gate_policy.read_lines(root, "a.md"), ["one", "two"])

    def test_read_lines_of_a_missing_file_is_empty(self):
        self.assertEqual(gate_policy.read_lines(self._tmp.name, "gone.md"), [])

    def test_read_lines_of_undecodable_bytes_is_empty(self):
        root = self.repo({"bad.md": b"\xff\xfe not utf-8 at all\n"})
        self.assertEqual(gate_policy.read_lines(root, "bad.md"), [])

    # -- policy_at ----------------------------------------------------------

    def test_policy_at_finds_a_hatch_on_the_line_or_two_above(self):
        lines = ["", "# gate-policy: allow-script-path because", "b", "c", "target"]
        self.assertTrue(gate_policy.policy_at(lines, 3, "allow-script-path"))
        self.assertTrue(gate_policy.policy_at(lines, 2, "allow-script-path"))
        self.assertTrue(gate_policy.policy_at(lines, 1, "allow-script-path"))

    def test_policy_at_looks_no_further_than_two_lines_above(self):
        lines = ["# gate-policy: allow-script-path because", "a", "b", "c", "target"]
        self.assertFalse(gate_policy.policy_at(lines, 4, "allow-script-path"))

    def test_policy_at_ignores_a_different_hatch(self):
        lines = ["# gate-policy: allow-bazel-binary reason", "target"]
        self.assertFalse(gate_policy.policy_at(lines, 1, "allow-script-path"))

    # -- invocation_token ---------------------------------------------------

    def test_invocation_token_of_a_bare_relative_path(self):
        match = gate_policy.INVOKE_RE.search("run ./scripts/tool.sh now")
        self.assertIsNotNone(match)
        self.assertEqual(gate_policy.invocation_token(match), "./scripts/tool.sh")

    def test_invocation_token_drops_the_interpreter_prefix(self):
        match = gate_policy.INVOKE_RE.search("bash scripts/tool.sh --flag")
        self.assertIsNotNone(match)
        self.assertEqual(gate_policy.invocation_token(match), "scripts/tool.sh")

    def test_invocation_token_strips_quotes_and_falls_back_to_the_whole_match(self):
        self.assertEqual(
            gate_policy.invocation_token(_Match("python3 `./x.py`", "run it")),
            "./x.py")
        self.assertEqual(
            gate_policy.invocation_token(_Match(None, "  run ./x.sh  ")),
            "run ./x.sh")

    # -- names_repo_script --------------------------------------------------

    def test_names_repo_script_accepts_anything_without_a_tracked_set(self):
        self.assertTrue(gate_policy.names_repo_script("./x.sh", "d.md", set()))

    def test_names_repo_script_accepts_a_tracked_file(self):
        tracked = {"scripts/tool.sh"}
        self.assertTrue(gate_policy.names_repo_script(
            "./scripts/tool.sh", "docs/page.md", tracked))
        self.assertTrue(gate_policy.names_repo_script(
            "scripts/tool.sh", "docs/page.md", tracked))

    def test_names_repo_script_resolves_a_sibling_dot_slash_path(self):
        tracked = {"scripts/tool.sh"}
        self.assertTrue(gate_policy.names_repo_script(
            "./tool.sh", "scripts/test_tools.sh", tracked))

    def test_names_repo_script_resolves_a_dot_dot_path(self):
        tracked = {"pkg/tool.sh"}
        self.assertTrue(gate_policy.names_repo_script(
            "../tool.sh", "pkg/test_tools.sh", tracked))

    def test_names_repo_script_rejects_an_untracked_path(self):
        self.assertFalse(gate_policy.names_repo_script(
            "./scripts/tool.sh", "docs/page.md", {"docs/page.md"}))

    def test_names_repo_script_rejects_a_host_absolute_path(self):
        tracked = {"setup.sh"}
        self.assertFalse(gate_policy.names_repo_script(
            "/workspaces/inkorporated/setup.sh", "docs/page.md", tracked))

    # -- rule A: script paths ----------------------------------------------

    def test_rule_a_flags_a_run_instruction_naming_a_repo_script(self):
        findings = gate_policy.check_script_paths(
            "docs/page.md", ["Run ./scripts/tool.sh to build."],
            {"scripts/tool.sh"})
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0], {"file": "docs/page.md", "line": 1,
                                       "rule": "A", "text": "./scripts/tool.sh"})

    def test_rule_a_flags_an_interpreter_prefixed_run(self):
        findings = gate_policy.check_script_paths(
            "docs/page.md", ["    python3 scripts/tool.py --out x"],
            {"scripts/tool.py"})
        self.assertEqual([f["text"] for f in findings], ["scripts/tool.py"])

    def test_rule_a_leaves_a_bare_file_reference_alone(self):
        findings = gate_policy.check_script_paths(
            "docs/page.md", ["docs/generate_cyborg_docs.py writes the catalog."],
            {"docs/generate_cyborg_docs.py"})
        self.assertEqual(findings, [])

    def test_rule_a_honours_the_allow_script_path_hatch(self):
        findings = gate_policy.check_script_paths(
            "docs/page.md",
            ["# gate-policy: allow-script-path the escape hatch documents itself",
             "Run ./scripts/tool.sh."],
            {"scripts/tool.sh"})
        self.assertEqual(findings, [])

    def test_rule_a_ignores_the_checker_itself(self):
        findings = gate_policy.check_script_paths(
            "tools/bazel/gate_policy.py", ["Run ./scripts/tool.sh."],
            {"scripts/tool.sh"})
        self.assertEqual(findings, [])

    def test_rule_a_ignores_a_path_that_is_not_a_tracked_script(self):
        findings = gate_policy.check_script_paths(
            "docs/page.md", ["Run ./build/dist/app.js."], {"docs/page.md"})
        self.assertEqual(findings, [])

    # -- rule A companion: the bazel binary --------------------------------

    def test_bazel_binary_findings_flags_the_unpinned_binary(self):
        findings = gate_policy.bazel_binary_findings(
            "docs/page.md", ["    bazel test //...   # fast"])
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["rule"], "A")
        self.assertEqual(findings[0]["text"], "bazel test")

    def test_bazel_binary_findings_accepts_bazelisk_and_prose(self):
        lines = ["bazelisk test //...", "the bazel-tests job", "bazelize it"]
        self.assertEqual(gate_policy.bazel_binary_findings("a.md", lines), [])

    def test_bazel_binary_findings_honours_the_hatch(self):
        lines = ["# gate-policy: allow-bazel-binary the host image ships bazel",
                 "bazel build //..."]
        self.assertEqual(gate_policy.bazel_binary_findings("a.md", lines), [])

    # -- rule B: labels -----------------------------------------------------

    def test_collect_labels_skips_wildcards_visibility_and_non_docs(self):
        root = self.repo({
            "docs/a.md": "see //pkg:target and //... and //visibility:public\n",
            "docs/b.md": "also //pkg:target\n",
            "scripts/a.sh": "# //pkg:from-a-shell-file\n",
        })
        cited = gate_policy.collect_labels(
            root, ["docs/a.md", "docs/b.md", "scripts/a.sh"])
        self.assertEqual(sorted(cited), ["//pkg:target"])
        self.assertEqual(len(cited["//pkg:target"]), 2)

    def test_resolvable_labels_keeps_only_workspace_labels(self):
        with self.patch_bazelisk(["//pkg:target", "  //pkg:other  ",
                                  "Loading: 0 packages loaded", "@@x//p:t"]):
            self.assertEqual(gate_policy.resolvable_labels("."),
                             {"//pkg:target", "//pkg:other"})

    def test_resolvable_labels_failure_is_an_environment_error(self):
        err = io.StringIO()
        with self.patch_bazelisk([], returncode=1, stderr="no such target"):
            with contextlib.redirect_stderr(err):
                with self.assertRaises(SystemExit) as caught:
                    gate_policy.resolvable_labels(".")
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("no such target", err.getvalue())

    def test_label_exists_uses_the_query_then_the_disk(self):
        root = self.repo({"pkg/file.txt": "x\n", "pkg/pkg": "y\n"})
        self.assertTrue(gate_policy.label_exists("//pkg:any", root, {"//pkg:any"}))
        self.assertTrue(gate_policy.label_exists("//pkg:file.txt", root, set()))
        self.assertTrue(gate_policy.label_exists("//pkg", root, set()))
        self.assertFalse(gate_policy.label_exists("//pkg:gone", root, set()))

    def test_check_labels_reports_a_dangling_label_with_its_census(self):
        root = self.repo({"docs/a.md": "use //pkg:gone\n",
                          "docs/b.md": "and //pkg:gone again\n",
                          "docs/c.md": "use //pkg:here\n"})
        findings = gate_policy.check_labels(root, ["docs/a.md", "docs/b.md",
                                                   "docs/c.md"], {"//pkg:here"})
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["rule"], "B")
        self.assertEqual(findings[0]["file"], "docs/a.md")
        self.assertIn("//pkg:gone cited by 2 place(s)", findings[0]["text"])

    # -- rule C: tool guards ------------------------------------------------

    def test_doctor_census_reads_both_arrays(self):
        census = gate_policy.doctor_census(REPO_ROOT)
        self.assertIn("git", census)
        self.assertIn("ansible-lint", census)
        self.assertIn("mkdocs", census)

    def test_doctor_census_of_a_missing_doctor_is_empty(self):
        self.assertEqual(gate_policy.doctor_census(self._tmp.name), set())

    def test_doctor_census_ignores_lines_it_cannot_parse(self):
        root = self.repo({DOCTOR: '#!/usr/bin/env bash\nREQUIRED_TOOLS=(\n'
                                  '  not-a-tool-entry\n'
                                  '  "helm:some gate"\n'
                                  ')\necho done\n'})
        self.assertEqual(gate_policy.doctor_census(root), {"helm"})

    def guards_root(self, body, doctor=""):
        files = {"scripts/gate.sh": body}
        if doctor:
            files[DOCTOR] = doctor
        return self.repo(files)

    def test_rule_c_accepts_a_guard_that_honours_the_strict_switch(self):
        root = self.guards_root(
            "if ! command -v shellcheck >/dev/null; then\n"
            '  if [[ -n "${REQUIRE_LINT_TOOLS:-}" ]]; then exit 1; fi\n'
            "fi\n")
        self.assertEqual(
            gate_policy.check_tool_guards(root, ["scripts/gate.sh"], {"shellcheck"}),
            [])

    def test_rule_c_accepts_a_guard_with_a_real_fallback_branch(self):
        root = self.guards_root(
            "if ! command -v yamllint >/dev/null; then\n"
            "  fallback_lint\n"
            "else\n"
            "  yamllint .\n"
            "fi\n")
        self.assertEqual(
            gate_policy.check_tool_guards(root, ["scripts/gate.sh"], {"yamllint"}),
            [])

    def test_rule_c_flags_a_guard_that_skips_silently(self):
        root = self.guards_root(
            "if command -v terraform >/dev/null 2>&1; then\n"
            "  terraform fmt\n"
            "else\n"
            "  echo 'skipping'\n"
            "  exit 0\n"
            "fi\n")
        findings = gate_policy.check_tool_guards(root, ["scripts/gate.sh"], set())
        self.assertEqual([f["text"] for f in findings],
                         ["probes terraform without honoring REQUIRE_LINT_TOOLS/CI",
                          "terraform is not listed in %s" % DOCTOR])
        self.assertEqual({f["rule"] for f in findings}, {"C"})
        self.assertEqual(findings[0]["line"], 1)

    def test_rule_c_flags_a_missing_census_entry_on_its_own(self):
        root = self.guards_root(
            "if ! command -v helm >/dev/null; then\n"
            '  if [[ -n "${CI:-}" ]]; then exit 1; fi\n'
            "fi\n")
        findings = gate_policy.check_tool_guards(root, ["scripts/gate.sh"], set())
        self.assertEqual([f["text"] for f in findings],
                         ["helm is not listed in %s" % DOCTOR])

    def test_rule_c_honours_the_tool_guard_exempt_hatch(self):
        root = self.guards_root(
            "# gate-policy: tool-guard exempt the vendored binary is optional here\n"
            "if command -v kubectl >/dev/null; then\n"
            "  kubectl apply -f x.yaml\n"
            "else\n"
            "  exit 0\n"
            "fi\n")
        self.assertEqual(
            gate_policy.check_tool_guards(root, ["scripts/gate.sh"], set()), [])

    def test_rule_c_matches_elif_and_while_guards(self):
        root = self.guards_root(
            "if false; then\n"
            "  :\n"
            "elif command -v one >/dev/null; then\n"
            "  :\n"
            "fi\n"
            "while ! command -v 'two' >/dev/null; do\n"
            "  sleep 1\n"
            "done\n")
        findings = gate_policy.check_tool_guards(root, ["scripts/gate.sh"], set())
        self.assertIn("probes one without honoring", findings[0]["text"])
        self.assertIn("probes two without honoring", findings[2]["text"])

    def test_rule_c_skips_files_that_are_not_shell(self):
        root = self.repo({"scripts/gate.py": "if command -v git >/dev/null; then\n"})
        self.assertEqual(
            gate_policy.check_tool_guards(root, ["scripts/gate.py"], set()), [])

    # -- lines_of cache -----------------------------------------------------

    def test_lines_of_caches_by_relative_path(self):
        root = self.repo({"a.md": "one\n"})
        self.assertEqual(gate_policy.lines_of(root, "a.md"), ["one"])
        self.assertEqual(gate_policy.lines_of(root, "a.md"), ["one"])
        self.assertEqual(len(gate_policy._LINES_CACHE), 1)

    # -- main ---------------------------------------------------------------

    def test_main_needs_a_git_repository(self):
        code, _, err = self.run_main(self._tmp.name)
        self.assertEqual(code, 2)
        self.assertIn("is not a git repository", err)

    def test_main_is_clean_on_a_quiet_repository(self):
        root = self.repo({"README.md": "run bazelisk test //...\n"})
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("1 human-facing files checked, 0 violations", out)
        self.assertIn("rules skipped: none", out)

    def test_main_reports_a_violation_and_its_rule(self):
        root = self.repo({"docs/a.md": "run ./scripts/tool.sh\n",
                          "scripts/tool.sh": "echo hi\n"})
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root, "--skip-rule", "C")
        self.assertEqual(code, 1)
        self.assertIn("POLICY A docs/a.md:1  [A] ./scripts/tool.sh", out)

    def test_main_json_reports_violations(self):
        root = self.repo({"docs/a.md": "run bazel test //...\n"})
        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root, "--json", "--skip-rule", "C")
        self.assertEqual(code, 1)
        payload = json.loads(out)
        self.assertEqual(payload["checked"], 1)
        self.assertEqual(payload["violations"][0]["rule"], "A")
        self.assertEqual(payload["violations"][0]["text"], "bazel test")

    def test_main_can_skip_each_rule(self):
        root = self.repo({
            "docs/a.md": "run ./scripts/tool.sh and cite //pkg:gone\n",
            "scripts/tool.sh": "if command -v nope >/dev/null; then exit 0; fi\n",
            DOCTOR: "OPTIONAL_TOOLS=(\n  \"nope:a gate\"\n)\n",
        })
        with self.patch_bazelisk(["//pkg:gone"]):
            code, out, _ = self.run_main(root, "--skip-rule", "A",
                                         "--skip-rule", "B", "--skip-rule", "C")
        self.assertEqual(code, 0)
        self.assertIn("rules skipped: A, B, C", out)

        with self.patch_bazelisk(["//pkg:gone"]):
            code, out, _ = self.run_main(root, "--skip-rule", "A",
                                         "--skip-rule", "B")
        self.assertEqual(code, 1)
        self.assertIn("probes nope without honoring", out)

        with self.patch_bazelisk([]):
            code, out, _ = self.run_main(root, "--skip-rule", "A",
                                         "--skip-rule", "C")
        self.assertEqual(code, 1)
        self.assertIn("POLICY B docs/a.md:1  [B] //pkg:gone cited by 1 place(s)",
                      out)

    def test_main_passes_the_bazel_args_to_the_query(self):
        root = self.repo({"docs/a.md": "cite //pkg:target\n"})
        with self.patch_bazelisk(["//pkg:target"]):
            code, _, _ = self.run_main(root, "--bazel-args",
                                       "--output_base=/tmp/b --lockfile_mode=off")
        self.assertEqual(code, 0)
        self.assertEqual(gate_policy.BAZEL_ARGS,
                         ["--output_base=/tmp/b", "--lockfile_mode=off"])
        self.assertEqual(self.calls[0][:4],
                         ["bazelisk", "--output_base=/tmp/b",
                          "--lockfile_mode=off", "query"])

    def test_main_without_bazel_args_queries_directly(self):
        root = self.repo({"docs/a.md": "cite //pkg:target\n"})
        with self.patch_bazelisk(["//pkg:target"]):
            code, _, _ = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertEqual(gate_policy.BAZEL_ARGS, [])
        self.assertEqual(self.calls[0][:2], ["bazelisk", "query"])

    def test_main_of_a_broken_git_is_an_environment_error(self):
        root = self.repo({"README.md": "x\n"})
        err = io.StringIO()
        with mock.patch.object(gate_policy.subprocess, "run",
                               return_value=subprocess.CompletedProcess(
                                   ["git"], 128, "", "fatal: not a git repository")):
            with contextlib.redirect_stderr(err):
                with self.assertRaises(SystemExit) as caught:
                    gate_policy.main(["--root", root])
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("fatal: not a git repository", err.getvalue())

    # -- module entry point -------------------------------------------------

    def test_module_main_exits_with_the_checker_code(self):
        import runpy
        checker = os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))), "gate_policy.py")
        root = self.repo({"docs/a.md": "run ./scripts/tool.sh\n",
                          "scripts/tool.sh": "echo hi\n"})
        with self.patch_bazelisk([]):
            with mock.patch.object(sys, "argv", ["gate_policy.py", "--root", root,
                                                 "--skip-rule", "B",
                                                 "--skip-rule", "C"]):
                with contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as caught:
                        runpy.run_path(checker, run_name="__main__")
        self.assertEqual(caught.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
