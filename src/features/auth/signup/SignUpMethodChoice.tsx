import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";

// The sign-up entry screen: pick a registration method.
//
// Which methods exist is a server decision, so each entry arrives with a finished label and a
// finished URL. `suspended_notice` means the `sign_up_suspended_<surface>` kill switch is on: the
// screen shows the notice instead of entry points that would start a registration the guard is
// about to reject anyway.
import SocialProviderButton, { type AppleSignInLogos } from "./SocialProviderButton";

export type SignUpMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type SignUpSocialProvider = {
  provider: string;
  label: string;
  url: string;
  apple_logos?: AppleSignInLogos | null;
};

export type SignUpMethodChoiceProps = {
  title: string;
  suspended_notice: string | null;
  methods: SignUpMethodLink[];
  social_providers: SignUpSocialProvider[];
  links: SignUpMethodLink[];
  cancel_label?: string;
};

export default function SignUpMethodChoice({
  title,
  suspended_notice: suspendedNotice,
  methods,
  social_providers: socialProviders,
  links,
  cancel_label: cancelLabel,
}: SignUpMethodChoiceProps) {
  if (suspendedNotice) {
    return (
      <Page
        title={title}
        width="narrow"
      >
        <div
          role="alert"
          data-test-id="sign-up-suspended"
          className="rounded-lg border border-danger bg-surface p-4 text-base text-error"
        >
          <p>{suspendedNotice}</p>
        </div>
      </Page>
    );
  }

  return (
    <Page
      title={title}
      width="narrow"
    >
      <ul className="flex flex-col gap-2">
        {methods.map((method) => (
          <li
            key={method.key}
            data-test-id="registration-method"
          >
            {/* Document visits: each method starts a ceremony behind its own guards. */}
            <ButtonLink
              href={method.href}
              variant="secondary"
              className="w-full"
            >
              {method.label}
            </ButtonLink>
          </li>
        ))}
      </ul>

      <ul className="social-provider-buttons">
        {socialProviders.map((provider) => (
          <li
            key={provider.provider}
            data-test-id="registration-method"
          >
            <SocialProviderButton
              provider={provider.provider}
              url={provider.url}
              label={provider.label}
              apple_logos={provider.apple_logos ?? null}
            />
          </li>
        ))}
      </ul>

      {links.map((link) => (
        <p
          key={link.key}
          className="text-base"
        >
          <a
            href={link.href}
            className="ui-text-link text-fg underline underline-offset-4 hover:underline"
          >
            {link.label}
          </a>
        </p>
      ))}
      {cancelLabel !== undefined && <p className="text-base text-fg-muted">{cancelLabel}</p>}
    </Page>
  );
}
