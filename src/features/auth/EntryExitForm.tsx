// First-page Cancel and Sign In/Up Switch (D06/D09).
//
// Both are protected mutations, so they are native POST forms carrying the authenticity token, not
// links; they keep the look of a text link and ask for no confirmation. The server sends a form
// only when the action is available on this page, and Auth then hands the request to Base.
export type EntryExitFormProps = {
  label: string;
  action: string;
  to: string | null;
  authenticity_token: string;
};

export default function EntryExitForm({
  form,
  testId,
  tone,
}: {
  form: EntryExitFormProps;
  testId: string;
  tone: "default" | "muted";
}) {
  return (
    <form
      action={form.action}
      method="post"
      data-turbo="false"
      data-test-id={testId}
    >
      <input
        type="hidden"
        name="authenticity_token"
        value={form.authenticity_token}
        readOnly
      />
      {form.to !== null && (
        <input
          type="hidden"
          name="to"
          value={form.to}
          readOnly
        />
      )}
      <button
        type="submit"
        className={`ui-text-link text-base underline underline-offset-4 hover:underline ${
          tone === "muted" ? "text-fg-muted hover:text-fg" : "text-fg"
        }`}
      >
        {form.label}
      </button>
    </form>
  );
}
