import Button from "@/components/ui/Button";
// The thin public landing every surface answers with at its root.
//
// It used to be a self-contained ERB document with its own inline stylesheet, one copy per surface.
// The surfaces differ only in their heading and their sign-up destination, so both arrive as props
// and the markup is shared.
import ButtonLink from "@/components/ui/ButtonLink";

export type RootLandingLink = {
  label: string;
  href: string;
};

export type RootLandingAction = {
  label: string;
  action: string;
  method?: "post";
  intent?: string;
  authenticity_token?: string;
};

type RootLandingDestination = RootLandingLink | RootLandingAction;

function renderAuthAction(link: RootLandingDestination) {
  if ("action" in link) {
    return (
      <form
        method={link.method ?? "post"}
        action={link.action}
      >
        {link.intent ? (
          <input
            type="hidden"
            name="intent"
            value={link.intent}
          />
        ) : null}
        {link.authenticity_token ? (
          <input
            type="hidden"
            name="authenticity_token"
            value={link.authenticity_token}
          />
        ) : null}
        <Button type="submit">{link.label}</Button>
      </form>
    );
  }

  return <ButtonLink href={link.href}>{link.label}</ButtonLink>;
}

export type RootLandingProps = {
  // A root document renders the brand alone, so a surface whose landing carries no page title of
  // its own sends null and the layout falls back to that contract.
  title: string | null;
  heading: string;
  description: string;
  sign_in?: RootLandingDestination | null;
  sign_up: RootLandingDestination | null;
  // Surfaces that offer more than one destination (Warp settings, Palm per-platform sign-up) send
  // them here; the server has already decided which ones the visitor may see.
  links?: RootLandingLink[] | null;
};

export default function RootLanding({
  heading,
  description,
  sign_in: signIn,
  sign_up: signUp,
  links,
}: RootLandingProps) {
  const headingId = "root-landing-title";

  return (
    <section
      aria-labelledby={headingId}
      className="mx-auto flex w-full max-w-2xl flex-col gap-8"
    >
      <div className="flex w-full flex-col gap-6">
        <header className="flex flex-col gap-4">
          <h1
            id={headingId}
            className="min-w-0 wrap-anywhere text-3xl leading-snug font-semibold text-balance text-fg sm:text-4xl"
          >
            {heading}
          </h1>
          <p className="max-w-prose text-lg text-pretty text-fg-muted">{description}</p>
        </header>

        {signIn || signUp || links?.length ? (
          <nav aria-label="Authentication">
            <ul className="flex flex-wrap items-center gap-4">
              {signIn ? <li>{renderAuthAction(signIn)}</li> : null}
              {signUp ? <li>{renderAuthAction(signUp)}</li> : null}
              {links?.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}
      </div>
    </section>
  );
}
