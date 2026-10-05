// The Palm browser logout confirmation. Rails decides the wording and whether a validated state
// value exists; this page only renders what it is given.
export type PalmSignOutShowProps = {
  title: string;
  heading: string;
  description: string;
  state: string | null;
};

export default function PalmSignOutShow({ heading, description, state }: PalmSignOutShowProps) {
  const headingId = "palm-sign-out-title";

  return (
    <section
      aria-labelledby={headingId}
      className="flex flex-col gap-4 py-8 sm:py-16"
    >
      <h1
        id={headingId}
        className="text-4xl font-semibold tracking-tight text-balance text-fg sm:text-5xl"
      >
        {heading}
      </h1>
      <p className="max-w-prose text-lg text-pretty text-fg-muted">{description}</p>
      {state ? (
        <p className="text-base text-fg-muted">
          State{" "}
          <code className="rounded bg-surface-muted px-1.5 py-0.5 font-mono text-fg">{state}</code>{" "}
          was validated.
        </p>
      ) : null}
    </section>
  );
}
