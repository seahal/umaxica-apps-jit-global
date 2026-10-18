// The org sign-in entry screen.
//
// It is not `AuthMethodChoice`, because one of the three methods is not a link: Entra ID starts
// with a POST to the surface ceremony endpoint, which prepares the ceremony and hands the same POST
// to the OmniAuth request phase with a 307. The button wording and shape are constrained by
// docs/reference/third-party-sign-in-button-requirements.md.
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

type SignInMethod = {
  key: string;
  kind: "link" | "provider";
  label: string;
  href: string;
};

type SignInLink = {
  label: string;
  href: string;
};

export type OrgSignInEntryProps = {
  title: string;
  description: string;
  methods: SignInMethod[];
  registration_link: SignInLink | null;
  cancel_label?: string;
};

// Entra is a form submit and Emergency Access is a link, but both are sign-in methods of equal
// standing, so they share one row style: a bordered row with a trailing arrow.
const methodRowClassName = `flex w-full cursor-pointer items-center justify-between gap-3
  rounded-lg border border-line bg-surface px-4 py-3 text-left text-sm font-medium text-fg
  hover:bg-surface-muted`;

function MethodRowContent({ label }: { label: string }) {
  return (
    <>
      <span>{label}</span>
      <span
        aria-hidden="true"
        className="text-fg-muted"
      >
        &rarr;
      </span>
    </>
  );
}

export default function OrgSignInEntry({
  title,
  description,
  methods,
  registration_link: registrationLink,
  cancel_label: cancelLabel,
}: OrgSignInEntryProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      <ul className="flex flex-col gap-3">
        {methods.map((method) =>
          method.kind === "provider" ? (
            <li key={method.key}>
              {/* A document POST: the browser has to follow the 307 and then the cross-origin
                  redirect to the provider, which an Inertia visit cannot do. */}
              <form
                action={method.href}
                method="post"
                className="social-provider-form"
              >
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={csrfToken()}
                  readOnly
                />
                <button
                  type="submit"
                  className={`social-provider-button social-provider-button--${method.key}
                    ${methodRowClassName}`}
                >
                  <MethodRowContent label={method.label} />
                </button>
              </form>
            </li>
          ) : (
            <li key={method.key}>
              <a
                href={method.href}
                className={methodRowClassName}
              >
                <MethodRowContent label={method.label} />
              </a>
            </li>
          ),
        )}
      </ul>

      {/* Sign-up is a different ceremony, not another sign-in method: it sits below a divider as
          a centred secondary action so it cannot be mistaken for one of the rows above. */}
      {registrationLink ? (
        <div className="mt-6 border-t border-line pt-6">
          <a
            href={registrationLink.href}
            className="flex w-full items-center justify-center rounded-lg border border-dashed
              border-line px-4 py-2 text-base text-fg-muted hover:bg-surface-muted hover:text-fg"
          >
            {registrationLink.label}
          </a>
        </div>
      ) : null}
      {cancelLabel !== undefined && <p className="text-base text-fg-muted">{cancelLabel}</p>}
    </Page>
  );
}
