// The entry screen of a sign-in or sign-up ceremony: pick a credential method.
//
// Which methods exist is a server decision, so the list arrives already filtered and each entry
// carries a finished label and a finished URL. Availability is handled server-side by the entry
// sentry; this screen renders only methods the server decided to offer.
import Page from "@/components/ui/Page";

import EntryExitForm, { type EntryExitFormProps } from "./EntryExitForm";

export type AuthMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type AuthMethodChoiceProps = {
  title: string;
  description: string | null;
  methods: AuthMethodLink[];
  /** A local entry's links; empty on an OIDC-bound page, which moves only by Switch. */
  links: AuthMethodLink[];
  cancel_form: EntryExitFormProps | null;
  switch_form: EntryExitFormProps | null;
};

export default function AuthMethodChoice({
  title,
  description,
  methods,
  links,
  cancel_form: cancelForm,
  switch_form: switchForm,
}: AuthMethodChoiceProps) {
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
                bg-surface px-4 py-3 text-base font-medium text-fg hover:bg-surface-muted"
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
          className="text-base text-fg-muted"
        >
          <a
            href={link.href}
            className="ui-text-link underline underline-offset-4 hover:text-fg hover:underline"
          >
            {link.label}
          </a>
        </p>
      ))}
      {switchForm !== null && (
        <EntryExitForm
          form={switchForm}
          testId="sign-entry-switch"
          tone="muted"
        />
      )}
      {cancelForm !== null && (
        <EntryExitForm
          form={cancelForm}
          testId="sign-entry-cancel"
          tone="muted"
        />
      )}
    </Page>
  );
}
