// The org sign-up entry screen.
//
// The org surface has no self-service registration: an operator is recruited and then invited, so
// the page is a prompt with a contact link rather than a list of registration methods. When the
// kill switch has suspended sign-up the server sends the notice alone.
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

type SignUpLink = {
  label: string;
  href: string;
};

export type OrgSignUpEntryProps = {
  title: string;
  description: string | null;
  suspended_notice: string | null;
  recruit: { prompt: string; label: string; href: string } | null;
  sign_in_link: SignUpLink | null;
  cancel_link: SignUpLink | null;
};

export default function OrgSignUpEntry({
  title,
  description,
  suspended_notice: suspendedNotice,
  recruit,
  sign_in_link: signInLink,
  cancel_link: cancelLink,
}: OrgSignUpEntryProps) {
  if (suspendedNotice) {
    return (
      <Page
        title={title}
        width="narrow"
      >
        <div
          role="alert"
          data-test-id="sign-up-suspended"
          className="rounded-lg border border-line bg-surface-muted px-4 py-3 text-base text-fg"
        >
          <p>{suspendedNotice}</p>
        </div>
      </Page>
    );
  }

  return (
    <Page
      title={title}
      {...(description === null ? {} : { description })}
      width="narrow"
    >
      {recruit ? (
        <Card>
          <p className="text-base text-fg-muted">{recruit.prompt}</p>
          <p className="text-base font-semibold">
            <TextLink href={recruit.href}>{recruit.label}</TextLink>
          </p>
        </Card>
      ) : null}

      {signInLink ? (
        <p className="text-base">
          <TextLink
            href={signInLink.href}
            tone="muted"
          >
            {signInLink.label}
          </TextLink>
        </p>
      ) : null}
      {cancelLink ? (
        <p className="text-base">
          <TextLink
            href={cancelLink.href}
            tone="muted"
          >
            {cancelLink.label}
          </TextLink>
        </p>
      ) : null}
    </Page>
  );
}
