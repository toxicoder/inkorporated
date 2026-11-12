import type { Metadata } from "next";
import type { ReactNode } from "react";

import { Provider } from "@/components/provider";
import { searchIndexPath, SITE_DESCRIPTION, SITE_NAME } from "@/lib/site";

import "./global.css";
import "./styles/extra.css";
import "./styles/cyborgs.css";

export const metadata: Metadata = {
  title: {
    default: `${SITE_NAME} - Docs`,
    template: `%s | ${SITE_NAME}`
  },
  description: SITE_DESCRIPTION
};

/**
 * Root layout: applies the site theme and mounts the framework providers.
 *
 * `app/styles/` carries the two stylesheets the MkDocs theme loaded through
 * `extra_css`: `extra.css` for the small site-wide tweaks and `cyborgs.css` for
 * the generated roster grid. They are app-owned now, so a page never has to
 * reference a file under `docs/` to look right.
 *
 * `suppressHydrationWarning` is required by `next-themes`: its theme script rewrites the
 * `class` attribute on `<html>` before React hydrates, which otherwise trips the mismatch
 * check.
 */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="flex flex-col min-h-screen" suppressHydrationWarning>
        <Provider searchFrom={searchIndexPath()}>{children}</Provider>
      </body>
    </html>
  );
}
