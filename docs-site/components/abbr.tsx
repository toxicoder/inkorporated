/**
 * Tooltip wrapper for an abbreviation from `docs/includes/abbreviations.md`.
 *
 * `lib/remark-abbreviations.ts` rewrites the first occurrence of each authored
 * abbreviation into this element. A native `abbr` with a `title` is the whole
 * feature: it is what the retired MkDocs `abbr` extension produced, so the reader
 * sees the same tooltip without a client-side dialog.
 */

export interface AbbrProps {
  /** Tooltip text, the expansion authored in the abbreviations file. */
  title?: string;
  /** The short form as authored, used only as a test and styling hook. */
  abbreviation?: string;
  children?: React.ReactNode;
  className?: string;
}

/** Render an abbreviation with its expansion as a native tooltip. */
export function Abbr({ title, abbreviation, children, className }: AbbrProps) {
  return (
    <abbr
      title={title}
      data-abbreviation={abbreviation}
      className={`ez-abbr${className ? ` ${className}` : ""}`}
    >
      {children}
    </abbr>
  );
}
