"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

/**
 * Progressive enhancement for the generated cyborg roster.
 *
 * `docs/generate_cyborg_docs.py` emits the roster as static markup tagged with
 * `data-cyborg-roster`, `data-filter` and per-card `data-prefix` / `data-security` /
 * `data-ns` attributes. Under MkDocs a script in `docs/assets/javascripts` wired the
 * filter buttons after load; the Fumadocs export runs the same enhancement here, once
 * the page has hydrated and again on every client-side navigation.
 *
 * Cards and buttons come from the generated page, so this component reads the DOM the
 * same way the retired script did and hides nothing when the hooks are absent: a page
 * without a roster costs one query and renders exactly as authored.
 */
export function CyborgRoster() {
  const pathname = usePathname();

  useEffect(() => {
    function initRoster(root: HTMLElement) {
      const grid = root.querySelector<HTMLElement>(".cyborg-grid");
      const filters = root.querySelector<HTMLElement>(".cyborg-filters");
      if (!grid || !filters) return;

      const cards = Array.from(grid.querySelectorAll<HTMLElement>(".cyborg-card"));
      const buttons = Array.from(filters.querySelectorAll<HTMLElement>("button[data-filter]"));
      if (!cards.length || !buttons.length) return;

      const apply = (filter: string) => {
        const [kind, value = ""] = filter.split(":", 2);
        for (const card of cards) {
          let show = true;
          if (kind === "prefix") show = card.getAttribute("data-prefix") === value;
          else if (kind === "security") show = card.getAttribute("data-security") === value;
          else if (kind === "ns") show = (card.getAttribute("data-ns") || "").includes(value);
          card.classList.toggle("is-hidden", !show);
        }
        for (const button of buttons) {
          button.classList.toggle("is-active", button.getAttribute("data-filter") === filter);
        }
      };

      const onClick = (event: MouseEvent) => {
        const target = event.target as HTMLElement | null;
        const button = target?.closest?.("button[data-filter]") as HTMLElement | null;
        if (!button || !filters.contains(button)) return;
        apply(button.getAttribute("data-filter") || "all:");
      };

      filters.addEventListener("click", onClick);
      apply("all:");
      return () => filters.removeEventListener("click", onClick);
    }

    const cleanups = Array.from(document.querySelectorAll<HTMLElement>("[data-cyborg-roster]")).map(
      (root) => initRoster(root) ?? (() => undefined)
    );
    return () => {
      for (const cleanup of cleanups) cleanup();
    };
  }, [pathname]);

  return null;
}
