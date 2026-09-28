// Shared prop shapes for the org administration screens. Every value arrives resolved from the
// server: labels are translated, hrefs are authorized routes, and the acting operator and target
// realm are always explicit so a screen never relies on colour alone to say where an action lands.
import type { PageUpLink } from "@/components/ui/Page";

export type AdminContext = {
  /** The operator performing the operation, never the target. */
  operator_label: string;
  operator_public_id: string;
  /** "app", "com", or null for screens that act on no realm (IAM). */
  realm_label: string | null;
  realm: string | null;
};

export type AdminLink = { label: string; href: string };

export type AdminField = { term: string; description: string };

export type AdminNotice = {
  tone: "info" | "warning" | "danger";
  message: string;
};

export type AdminBaseProps = {
  title: string;
  description?: string;
  up_link?: PageUpLink | null;
  context: AdminContext;
  notices?: AdminNotice[];
};
