// The terminal screen of a sign-up the age policy rejected.
//
// The message and the restart destination are both server decisions: the surface picks the copy and
// the ticket has already been failed by the time this renders.
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

export type SignUpAgeRestrictedProps = {
  title: string;
  message: string;
  retry_message: string;
  back: { label: string; href: string };
};

export default function SignUpAgeRestricted({
  title,
  message,
  retry_message: retryMessage,
  back,
}: SignUpAgeRestrictedProps) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      <p className="text-fg">{message}</p>
      <p className="text-base text-fg-muted">{retryMessage}</p>

      {/* The ERB rendered a GET `button_to`, which carries no CSRF token, so the control stays a
          form rather than a link and stays a GET. */}
      <form
        action={back.href}
        method="get"
        data-turbo="false"
      >
        <Button
          type="submit"
          variant="secondary"
        >
          {back.label}
        </Button>
      </form>
    </Page>
  );
}
