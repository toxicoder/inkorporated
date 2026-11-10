"""Macros that give every gate in this repository the same shell-test shape."""

load("@rules_shell//shell:sh_binary.bzl", _sh_binary = "sh_binary")
load("@rules_shell//shell:sh_test.bzl", _sh_test = "sh_test")

# Exported into any test declared with strict = True. A wrapper script that
# cannot find its tool must fail under these two variables instead of printing
# a warning and exiting 0, so a green gate always means the tool really ran.
_STRICT_ENV = {
    "CI": "1",
    "REQUIRE_LINT_TOOLS": "1",
}

def repo_sh_test(name, srcs, strict = False, env = {}, tags = [], **kwargs):
    """A shell test that never passes by skipping.

    Args:
      name: target name; use the script stem so docs can name it directly.
      srcs: the script itself, as an explicit single-element list.
      strict: when True, REQUIRE_LINT_TOOLS=1 and CI=1 are exported so a
        missing optional binary fails the test rather than skipping it.
      env: extra environment variables merged over the strict defaults.
      tags: Bazel tags; keep them descriptive (lint, slow, coverage).
      **kwargs: passed through to @rules_shell sh_test unchanged.
    """
    merged_env = dict(_STRICT_ENV) if strict else {}
    merged_env.update(env)
    _sh_test(
        name = name,
        srcs = srcs,
        env = merged_env,
        tags = tags,
        **kwargs
    )

def repo_sh_binary(name, srcs, **kwargs):
    """A human-driven shell entry point, named after its script stem.

    Documentation names targets with `bazelisk run //pkg:stem -- <args>`, so
    every script a person drives needs exactly one such target.
    """
    _sh_binary(
        name = name,
        srcs = srcs,
        **kwargs
    )

# Bazel 9 removed the native test_suite rule and left a stub that expands to
# nothing: a test request on //pkg:all_tests reports "Found 0 test targets". The
# successor module is not published to the Bazel Central Registry yet, so the
# umbrella is a real test that runs the suite in a nested invocation. A nested
# Bazel has to use its own output base, because this invocation still holds the
# default one.
def repo_umbrella(name, suites, tag_filters = [], runner = "run_suite.sh", lib = "gate_lib.sh", **kwargs):
    """One target that answers "did everything pass?".

    Declare this in the repository root so that `bazelisk test //:gate` is a
    real test target: an alias to a test is not itself a test, and Bazel answers
    "No test targets were found" to a test request on an alias.

    Args:
      name: the target everyone documents, typically `gate`.
      suites: label strings to run, usually ["//..."].
      tag_filters: --test_tag_filters values passed to the inner run.
      runner: the script that runs the suite, as a source label.
      lib: the library the runner sources, as a data label. It has to land next
        to the runner in runfiles, so both normally come from one package.
      **kwargs: passed through to @rules_shell sh_test unchanged.
    """
    _sh_test(
        name = name,
        srcs = [runner],
        data = [lib] + kwargs.pop("data", []),
        env = {
            "SUITE_TARGETS": " ".join(suites),
            "SUITE_TAG_FILTERS": ",".join(tag_filters),
        },
        tags = kwargs.pop("tags", []) + ["umbrella"],
        timeout = kwargs.pop("timeout", "long"),
        **kwargs
    )
