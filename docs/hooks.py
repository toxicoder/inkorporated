"""MkDocs build/serve hooks for Inkorporated docs.

Injects a tiny inline <script> at the start of <head> that patches
window.fetch and XMLHttpRequest for GitHub API calls to this repo so private
or rate-limited stats fetches do not spam the console.

When ``MIKE_DOCS_VERSION`` or ``INK_DOCS_VERSION`` is ``development``, also
injects a banner so readers know they are on the development docs alias.

Branch-aware site artifacts (mike aliases ``latest`` / ``development``):

- ``on_config`` sets ``edit_uri`` to the long-lived git ref for the alias
  (``edit/main/docs/`` or ``edit/development/docs/``).
- ``on_page_markdown`` rewrites this-repo GitHub ``blob``/``tree`` links so
  source links match the same ref. Optional override: ``INK_DOCS_GIT_REF``.
"""

from __future__ import annotations

import os
import re
from typing import Any

_REPO = "toxicoder/inkorporated"

_GITHUB_API_PATCH = (
    "<script>"
    "(function(){"
    "try{var orig=window.fetch;"
    'if(typeof orig==="function"){window.fetch=function(i,init){'
    'var u=(typeof i==="string")?i:(i&&typeof i.url==="string"?i.url:"");'
    f'if(u.indexOf("api.github.com/repos/{_REPO}")!==-1){{'
    'return Promise.resolve(new Response("{}", {status:200,headers:{"Content-Type":"application/json"}}));}'
    "return orig.apply(this,arguments);"
    "};}}catch(e){}"
    "try{var XHR=window.XMLHttpRequest;"
    "if(XHR&&XHR.prototype){var p=XHR.prototype,open=p.open;"
    "p.open=function(m,u){"
    f'if(typeof u==="string"&&u.indexOf("api.github.com/repos/{_REPO}")!==-1){{'
    "var self=this;"
    'Object.defineProperty(self,"responseText",{get:function(){return"{}"},configurable:!0});'
    'Object.defineProperty(self,"status",{get:function(){return 200},configurable:!0});'
    'Object.defineProperty(self,"readyState",{get:function(){return 4},configurable:!0});'
    "self.send=function(){setTimeout(function(){"
    'try{if(typeof self.onreadystatechange==="function")self.onreadystatechange.call(self);}catch(_){}'
    'try{if(typeof self.onload==="function")self.onload.call(self);}catch(_){}'
    "},0);};"
    "return;"
    "}"
    "return open.apply(this,arguments);"
    "};}}catch(e){}"
    "})();"
    "</script>"
)

_DEV_BANNER = (
    '<div class="ink-docs-dev-banner" role="status">'
    "<strong>Development docs</strong> — this site version tracks the "
    "<code>development</code> branch and may change without a release tag. "
    'Prefer <a href="../latest/">latest</a> for production-ready guidance.'
    "</div>"
)

_REPO_GITHUB_REF_RE = re.compile(
    rf"(https://github\.com/{re.escape(_REPO)}/"
    r"(?:blob|tree)/)"
    r"(main|master|development)"
    r"(/)",
)


def docs_version() -> str:
    """Return the active docs version alias from the environment.

    Prefers ``MIKE_DOCS_VERSION``, then ``INK_DOCS_VERSION``.

    Returns:
        Docs version alias (e.g. ``development``, ``latest``) or ``""``.
    """
    return (
        os.environ.get("MIKE_DOCS_VERSION") or os.environ.get("INK_DOCS_VERSION") or ""
    ).strip().lower()


def docs_git_ref() -> str:
    """Return the long-lived git ref for Edit links and source URLs.

    Returns:
        ``main`` or ``development`` (or an explicit override value).
    """
    override = (os.environ.get("INK_DOCS_GIT_REF") or "").strip()
    if override:
        return override
    if docs_version() == "development":
        return "development"
    return "main"


def on_config(config: dict[str, Any], **kwargs: Any) -> dict[str, Any]:
    """Stamp ``edit_uri`` for the active docs git ref.

    Args:
        config: MkDocs config dict.
        **kwargs: Unused hook kwargs.

    Returns:
        Updated config.
    """
    del kwargs
    ref = docs_git_ref()
    config["edit_uri"] = f"edit/{ref}/docs/"
    return config


def stamp_git_ref(text: str, ref: str | None = None) -> str:
    """Rewrite repo GitHub blob/tree branch segments and __DOCS_GIT_REF__ tokens.

    Sources should author GitHub URLs with branch ``main`` (canonical). At build
    time this stamps ``main`` / ``development`` to match the mike docs version.

    Args:
        text: Markdown or HTML content.
        ref: Optional explicit git ref; defaults to ``docs_git_ref()``.

    Returns:
        Content with branch-aware GitHub links.
    """
    ref = ref or docs_git_ref()
    text = text.replace("__DOCS_GIT_REF__", ref)
    return _REPO_GITHUB_REF_RE.sub(rf"\g<1>{ref}\g<3>", text)


def on_page_markdown(
    markdown: str, page: Any, config: dict[str, Any], files: Any, **kwargs: Any
) -> str:
    """Rewrite this-repo GitHub blob/tree links to the active long-lived ref.

    Args:
        markdown: Page markdown body.
        page: MkDocs page object (unused).
        config: MkDocs config (unused).
        files: Files collection (unused).
        **kwargs: Unused hook kwargs.

    Returns:
        Possibly rewritten markdown.
    """
    del page, config, files, kwargs
    return stamp_git_ref(markdown)


def on_post_page(output: str, page: Any, config: dict[str, Any], **kwargs: Any) -> str:
    """Inject GitHub API patch, stamp git refs in HTML, optional dev banner.

    Args:
        output: Rendered HTML.
        page: MkDocs page (unused).
        config: MkDocs config (unused).
        **kwargs: Unused hook kwargs.

    Returns:
        HTML with injections applied.
    """
    del page, config, kwargs
    # Belt-and-suspenders: stamp branch in final HTML (covers any missed cases).
    output = stamp_git_ref(output)
    if "<head>" in output and _GITHUB_API_PATCH not in output:
        output = output.replace("<head>", f"<head>{_GITHUB_API_PATCH}", 1)
    if docs_version() == "development" and "ink-docs-dev-banner" not in output:
        # Insert banner after opening body tag when present.
        if "<body" in output:
            output = re.sub(
                r"(<body[^>]*>)",
                rf"\1{_DEV_BANNER}",
                output,
                count=1,
            )
    return output
