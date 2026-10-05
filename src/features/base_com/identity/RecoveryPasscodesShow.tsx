import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
// One-time recovery passcode reveal page for the base/com surface.
//
// The passcodes are the one-time reveal the server just consumed for this owner; the page shows
// them once and holds nothing else.

export type RecoveryPasscodesShowProps = {
  title: string;
  description: string;
  one_time_notice: string;
  inventory_notice: string;
  missing_message: string;
  passcodes: string[];
  back_link: { label: string; href: string };
};

export default function RecoveryPasscodesShow({
  title,
  description,
  one_time_notice: oneTimeNotice,
  inventory_notice: inventoryNotice,
  missing_message: missingMessage,
  passcodes,
  back_link: backLink,
}: RecoveryPasscodesShowProps) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      {passcodes.length > 0 ? (
        <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
          <p className="text-base text-fg-muted">{description}</p>
          <p className="text-base font-semibold text-fg">{oneTimeNotice}</p>
          <p className="text-base text-fg-muted">{inventoryNotice}</p>
          <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            {passcodes.map((passcode) => (
              <li
                key={passcode}
                className="rounded-md border border-line bg-surface-muted px-3 py-2"
              >
                <code className="wrap-anywhere font-mono text-base text-fg">{passcode}</code>
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="text-base text-fg-muted">{missingMessage}</p>
      )}

      {/* Cross-host destination, so a document visit rather than an Inertia visit. */}
      <p>
        <TextLink
          href={backLink.href}
          tone="muted"
        >
          {backLink.label}
        </TextLink>
      </p>
    </Page>
  );
}
