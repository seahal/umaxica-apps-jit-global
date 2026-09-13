// Base unauthenticated entry. Sign-in is the existing OIDC authorization start, not a
// ceremony reimplemented here. `notice` is the one-shot sign-out message consumed by GET /lobby.
import ButtonLink from "@/components/ui/ButtonLink";

export type LobbyNotice = {
  title: string;
  description: string | null;
};

export type LobbyLink = { label: string; href: string };

export type LobbyProps = {
  title: string | null;
  heading: string;
  description: string;
  sign_in: LobbyLink;
  notice: LobbyNotice | null;
};

export default function Lobby({ heading, description, sign_in: signIn, notice }: LobbyProps) {
  const headingId = "lobby-title";

  return (
    <section
      aria-labelledby={headingId}
      className="flex flex-col gap-10 py-8 sm:py-16"
    >
      {notice ? (
        <output className="max-w-prose text-fg">
          <span className="font-medium">{notice.title}</span>
          {notice.description ? <span className="text-fg-muted"> {notice.description}</span> : null}
        </output>
      ) : null}

      <div className="flex w-full flex-col gap-6">
        <header className="flex flex-col gap-4">
          <h1
            id={headingId}
            className="text-4xl font-semibold tracking-tight text-balance text-fg sm:text-5xl"
          >
            {heading}
          </h1>
          <p className="max-w-prose text-lg text-pretty text-fg-muted">{description}</p>
        </header>

        <nav aria-label={signIn.label}>
          <ButtonLink href={signIn.href}>{signIn.label}</ButtonLink>
        </nav>
      </div>
    </section>
  );
}
