/**
 * Progressive enhancement for the cyborg roster page.
 * Filters cards by data-prefix / data-security without requiring a rebuild.
 */
(function () {
  function initRoster(root) {
    const grid = root.querySelector(".cyborg-grid");
    const filters = root.querySelector(".cyborg-filters");
    if (!grid || !filters) {
      return;
    }

    const cards = Array.from(grid.querySelectorAll(".cyborg-card"));
    const buttons = Array.from(filters.querySelectorAll("button[data-filter]"));
    if (!cards.length || !buttons.length) {
      return;
    }

    function apply(filter) {
      const [kind, value] = filter.split(":", 2);
      cards.forEach((card) => {
        let show = true;
        if (kind === "all") {
          show = true;
        } else if (kind === "prefix") {
          show = card.getAttribute("data-prefix") === value;
        } else if (kind === "security") {
          show = card.getAttribute("data-security") === value;
        } else if (kind === "ns") {
          show = (card.getAttribute("data-ns") || "").includes(value);
        }
        card.classList.toggle("is-hidden", !show);
      });
      buttons.forEach((btn) => {
        btn.classList.toggle("is-active", btn.getAttribute("data-filter") === filter);
      });
    }

    filters.addEventListener("click", (event) => {
      const btn = event.target.closest("button[data-filter]");
      if (!btn) {
        return;
      }
      apply(btn.getAttribute("data-filter") || "all:");
    });

    apply("all:");
  }

  function boot() {
    document.querySelectorAll("[data-cyborg-roster]").forEach(initRoster);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  // Material instant navigation
  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(boot);
  }
})();
