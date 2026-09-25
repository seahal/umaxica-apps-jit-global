// One-time recovery passcode reveal page for the base/app surface.

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
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      {passcodes.length > 0 ? (
        <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
          <p className="text-sm text-fg-muted">{description}</p>
          <p className="text-sm font-semibold text-fg">{oneTimeNotice}</p>
          <p className="text-sm text-fg-muted">{inventoryNotice}</p>
          <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            {passcodes.map((passcode) => (
              <li
                key={passcode}
                className="rounded-md border border-line bg-surface-muted px-3 py-2"
              >
                <code className="font-mono text-sm text-fg">{passcode}</code>
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="text-sm text-fg-muted">{missingMessage}</p>
      )}

      <p>
        <a
          href={backLink.href}
          className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
        >
          {backLink.label}
        </a>
      </p>
    </section>
  );
}
