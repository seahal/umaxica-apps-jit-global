import Page from "@/components/ui/Page";

// The app-surface sign-in entry screen: pick a credential method, or hand off to a social provider.
//
// Which methods exist and where they lead are server decisions, so each entry arrives with a
// finished label and a finished URL. The provider buttons are separate native forms rather than
// links because the hand-off is a POST.
import SocialProviderButton, { type SocialProvider } from "./SocialProviderButton";

export type SignInMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type SignInMethodChoiceProps = {
  title: string;
  description: string;
  methods: SignInMethodLink[];
  social_providers: SocialProvider[];
  registration_link: SignInMethodLink;
  cancel_label?: string;
};

export default function SignInMethodChoice({
  title,
  description,
  methods,
  social_providers: socialProviders,
  registration_link: registrationLink,
  cancel_label: cancelLabel,
}: SignInMethodChoiceProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <ul className="flex flex-col gap-2">
        {methods.map((method) => (
          <li key={method.key}>
            {/* Document visits preserve each entrypoint’s authentication guards. */}
            <a
              href={method.href}
              className="flex items-center justify-center rounded-md border border-line bg-surface
                px-4 py-2 text-sm font-medium text-fg hover:bg-surface-muted"
            >
              {method.label}
            </a>
          </li>
        ))}
      </ul>

      <ul className="social-provider-buttons">
        {socialProviders.map((provider) => (
          <li key={provider.key}>
            <SocialProviderButton provider={provider} />
          </li>
        ))}
      </ul>

      {cancelLabel !== undefined && socialProviders.length > 0 && <hr className="border-line" />}

      <p className="text-sm">
        <a
          href={registrationLink.href}
          className="text-fg-muted underline-offset-4 hover:text-fg hover:underline"
        >
          {registrationLink.label}
        </a>
      </p>
      {cancelLabel !== undefined && <p className="text-sm text-fg-muted">{cancelLabel}</p>}
    </Page>
  );
}
