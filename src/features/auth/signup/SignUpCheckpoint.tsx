// The sign-up checkpoint: the requirements still standing between a verified contact and a
// finished registration.
//
// Which requirements are missing is a server decision made from the ticket, so a section is absent
// rather than hidden, and the cancellation endpoint is the one the server chose for the current
// step. The checkpoint version travels as a plain integer the server re-validates on submission.
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

import BirthdateFieldset, { type BirthdateFieldsetProps } from "./BirthdateFieldset";
import { csrfToken } from "./csrf";

export type SignUpCheckpointRequirementLink = {
  title: string;
  description: string;
  label: string;
  href: string;
};

export type SignUpCheckpointBirthdate = {
  title: string;
  description: string;
  label: string;
  action: string;
  submit_label: string;
  checkpoint_version: number;
  fields: Omit<BirthdateFieldsetProps, "labelledby">;
};

export type SignUpCheckpointProps = {
  notice?: string | null | undefined;
  title: string;
  birthdate: SignUpCheckpointBirthdate | null;
  passkey: SignUpCheckpointRequirementLink | null;
  complete_message: string | null;
  cancellation: { label: string; action: string } | null;
};

function RequirementLink({ title, description, label, href }: SignUpCheckpointRequirementLink) {
  return (
    <section className="flex flex-col gap-2 rounded-lg border border-line bg-surface p-4">
      <h2 className="text-lg font-semibold text-fg">{title}</h2>
      <p className="text-base text-fg-muted">{description}</p>
      <a
        href={href}
        className="ui-text-link text-base font-medium text-link underline underline-offset-4 hover:underline"
      >
        {label}
      </a>
    </section>
  );
}

export default function SignUpCheckpoint({
  title,
  notice,
  birthdate,
  passkey,
  complete_message: completeMessage,
  cancellation,
}: SignUpCheckpointProps) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      {notice ? (
        <output className="rounded-md border border-line bg-surface-muted p-3 text-base text-fg">
          {notice}
        </output>
      ) : null}

      {birthdate ? (
        <section className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4">
          <h2 className="text-lg font-semibold text-fg">{birthdate.title}</h2>
          <p className="text-base text-fg-muted">{birthdate.description}</p>

          <form
            action={birthdate.action}
            method="post"
            data-turbo="false"
            className="flex flex-col gap-4"
          >
            <input
              type="hidden"
              name="_method"
              value="patch"
            />
            <input
              type="hidden"
              name="authenticity_token"
              value={csrfToken()}
            />
            <input
              type="hidden"
              name="requirement"
              value="birthdate"
            />
            <input
              type="hidden"
              name="checkpoint_version"
              value={birthdate.checkpoint_version}
            />

            <div className="flex flex-col gap-2">
              <p
                id="birthdate_label"
                className="text-base font-medium text-fg"
              >
                {birthdate.label}
              </p>
              <BirthdateFieldset
                {...birthdate.fields}
                labelledby="birthdate_label"
              />
            </div>

            <Button type="submit">{birthdate.submit_label}</Button>
          </form>
        </section>
      ) : null}

      {passkey ? <RequirementLink {...passkey} /> : null}

      {completeMessage ? (
        <p className="rounded-md border border-line bg-surface-muted p-3 text-base text-fg">
          {completeMessage}
        </p>
      ) : null}

      {cancellation ? (
        <form
          action={cancellation.action}
          method="post"
          data-turbo="false"
        >
          <input
            type="hidden"
            name="_method"
            value="delete"
          />
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
          />
          <Button
            type="submit"
            variant="ghost"
          >
            {cancellation.label}
          </Button>
        </form>
      ) : null}
    </Page>
  );
}
