// The React replacement for `app/views/base/shared/self_service/_shell.html.erb`.
//
// The ERB partial was the highest-fanout view in the base family: most self-service pages were a
// two-line wrapper around it. It stays one shared component here, and each surface page re-exports
// or renders it, because a surface Inertia resolver may only glob its own directory.

import Page, { type PageUpLink } from "@/components/ui/Page";

export type SelfServiceShellProps = {
  title: string;
  body: string;
  up_link?: PageUpLink | null;
};

export default function SelfServiceShell({
  title,
  body,
  up_link: upLink = null,
}: SelfServiceShellProps) {
  // The surface Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <Page
      title={title}
      description={body}
      up={upLink}
      upVisit="inertia"
    >
      <p className="text-sm text-fg-muted">Signed in</p>
    </Page>
  );
}
