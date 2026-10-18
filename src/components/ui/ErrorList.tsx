// The validation messages the server produced, rendered as the ERB error blocks did.

export default function ErrorList({
  errors,
  header,
  announce = false,
}: {
  errors: string[];
  /** Announce a newly returned asynchronous submission failure; initial document errors are static. */
  announce?: boolean;
  // `| undefined` is explicit because callers forward an optional server prop straight through,
  // and under exactOptionalPropertyTypes a bare `header?: string` would refuse that.
  header?: string | undefined;
}) {
  if (errors.length === 0) {
    return null;
  }

  return (
    <div
      {...(announce ? { role: "alert" } : {})}
      className="flex flex-col gap-1 rounded-md border border-danger bg-surface p-3 text-base text-error"
    >
      {header ? <p className="font-semibold">{header}</p> : null}
      <ul
        role="list"
        className="list-disc pl-5"
      >
        {errors.map((message, index) => (
          <li key={`${index}-${message}`}>{message}</li>
        ))}
      </ul>
    </div>
  );
}
