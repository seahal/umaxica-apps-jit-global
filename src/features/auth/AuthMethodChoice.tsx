// The entry screen of a sign-in or sign-up ceremony: pick a credential method.
//
// Which methods exist is a server decision, so the list arrives already filtered and each entry
// carries a finished label and a finished URL. When the surface kill switch has suspended the
// ceremony the server sends the notice instead of the methods, and the screen offers no entry point
// into a ceremony the guard would reject anyway.
import Page from "@/components/ui/Page";

export type AuthMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type AuthMethodChoiceProps = {
  title: string;
  description: string | null;
  suspended_notice: string | null;
  methods: AuthMethodLink[];
  links: AuthMethodLink[];
  cancel_label?: string;
};

export default function AuthMethodChoice({
  title,
  description,
  suspended_notice: suspendedNotice,
  methods,
  links,
  cancel_label: cancelLabel,
}: AuthMethodChoiceProps) {
  if (suspendedNotice) {
    return (
      <Page>
        <div
          role="alert"
          data-test-id="sign-up-suspended"
          className="rounded-lg border border-line bg-surface-muted p-4 text-sm text-fg"
        >
          <p>{suspendedNotice}</p>
        </div>
      </Page>
    );
  }

  return (
    <Page
      title={title}
      {...(description === null ? {} : { description })}
      width="narrow"
    >
      <ul className="flex flex-col gap-2">
        {methods.map((method) => (
          <li
            key={method.key}
            data-test-id="registration-method"
          >
            {/* Document visits: each method starts a ceremony behind its own guards. */}
            <a
              href={method.href}
              className="flex items-center justify-between gap-3 rounded-lg border border-line
                bg-surface px-4 py-3 text-sm font-medium text-fg hover:bg-surface-muted"
            >
              <span>{method.label}</span>
              <span
                aria-hidden="true"
                className="text-fg-muted"
              >
                &rarr;
              </span>
            </a>
          </li>
        ))}
      </ul>

      {links.map((link) => (
        <p
          key={link.key}
          className="text-sm text-fg-muted"
        >
          <a
            href={link.href}
            className="underline-offset-4 hover:text-fg hover:underline"
          >
            {link.label}
          </a>
        </p>
      ))}
      {cancelLabel !== undefined && <p className="text-sm text-fg-muted">{cancelLabel}</p>}
    </Page>
  );
}
