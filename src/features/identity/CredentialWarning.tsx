// A prompt to add another sign-in method, replacing
// `app/views/base/shared/identities/_apple_only_credential_warning.html.erb`.
//
// Whether the warning applies at all is a server decision: the prop is absent when the actor
// already has more than one credential, so the client never re-derives credential state. The links
// leave the surface for the auth service, so they are document navigations rather than Inertia
// visits.
export type CredentialWarningItem = {
  label: string;
  href: string;
};

export type CredentialWarningProps = {
  heading: string;
  body: string;
  items: CredentialWarningItem[];
};

export default function CredentialWarning({ heading, body, items }: CredentialWarningProps) {
  return (
    <section
      aria-labelledby="apple-only-credential-warning"
      className="flex flex-col gap-2 rounded-lg border border-danger bg-surface p-4"
    >
      <h2
        id="apple-only-credential-warning"
        className="text-base font-semibold text-error"
      >
        {heading}
      </h2>
      <p className="text-base text-fg">{body}</p>
      <ul className="flex flex-col gap-1">
        {items.map((item) => (
          <li key={item.label}>
            <a
              href={item.href}
              className="ui-text-link text-base text-fg underline underline-offset-4 hover:underline"
            >
              {item.label}
            </a>
          </li>
        ))}
      </ul>
    </section>
  );
}
