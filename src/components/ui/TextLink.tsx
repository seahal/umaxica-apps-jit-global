// The one inline link.
//
// Five different class strings were in use for what is the same link — the back link, the link out
// of a form, the link in a list row — differing only in which of `text-sm`, `text-fg` and
// `text-fg-muted` had been copied along. `tone` names the two that are actually distinct.
//
// Deliberately not extending `AnchorHTMLAttributes`: Inertia's `Link` accepts a different, narrower
// prop set, so a shared anchor-attribute surface would either fail to compile or quietly drop half
// of what a caller passed on the Inertia branch.
import { Link } from "@inertiajs/react";
import type { ReactNode } from "react";

export type TextLinkTone = "default" | "muted";

const TONES: Record<TextLinkTone, string> = {
  default: "text-link hover:underline",
  muted: "text-fg-muted hover:text-fg hover:underline",
};

export type TextLinkProps = {
  href: string;
  tone?: TextLinkTone;
  className?: string;
  children: ReactNode;
  /**
   * A client-side visit. Only for a destination on this surface: Inertia visits another origin over
   * XHR, which CORS rejects, and most of these destinations are cross-surface ceremonies.
   */
  inertia?: boolean;
};

export default function TextLink({
  href,
  tone = "default",
  className,
  children,
  inertia = false,
}: TextLinkProps) {
  const classes = ["ui-text-link", TONES[tone], className].filter(Boolean).join(" ");

  if (inertia) {
    return (
      <Link
        href={href}
        className={classes}
      >
        {children}
      </Link>
    );
  }

  return (
    <a
      href={href}
      className={classes}
    >
      {children}
    </a>
  );
}
