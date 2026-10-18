import { router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type RecoverySection = {
  available_message: string | null;
  submit_label: string | null;
  confirm: string | null;
  action: string | null;
  unavailable_message: string | null;
};

type TerminationSection = {
  submit_label: string | null;
  confirm: string | null;
  action: string | null;
  available_at_message: string | null;
};

type Props = {
  title: string;
  terminated: boolean;
  unavailable_message: string;
  deadline_message: string | null;
  recovery: RecoverySection | null;
  termination: TerminationSection | null;
  erasure_link: IdentityLink;
  sign_out: { label: string; url: string };
};

export default function WithdrawalEdit({
  title,
  terminated,
  unavailable_message: unavailableMessage,
  deadline_message: deadlineMessage,
  recovery,
  termination,
  erasure_link: erasureLink,
  sign_out: signOut,
}: Props) {
  const { confirm, dialog } = useConfirm();
  const signOutNow = () => router.delete(signOut.url);

  // Each action's URL, copy and label are read once so the click handlers work on values the
  // compiler has already narrowed rather than on properties that may be absent.
  const recoveryAction = recovery?.action ?? null;
  const recoveryLabel = recovery?.submit_label ?? null;
  const recoveryConfirm = recovery?.confirm ?? null;
  const terminationAction = termination?.action ?? null;
  const terminationLabel = termination?.submit_label ?? null;
  const terminationConfirm = termination?.confirm ?? null;

  // A section the server sent no confirmation copy for was never gated by one.
  const gate = (message: string | null, label: string, send: () => void) => {
    if (message) {
      confirm({ message, confirmLabel: label }, send);
      return;
    }
    send();
  };

  if (terminated) {
    return (
      <Page
        title={title}
        description={unavailableMessage}
        width="narrow"
      >
        <Button
          type="button"
          variant="secondary"
          onPress={signOutNow}
        >
          {signOut.label}
        </Button>
      </Page>
    );
  }

  return (
    <Page
      title={title}
      {...(deadlineMessage === null ? {} : { description: deadlineMessage })}
      width="narrow"
    >
      {recovery ? (
        <Card>
          {recovery.available_message ? (
            <p className="text-base text-fg">{recovery.available_message}</p>
          ) : null}
          {recovery.unavailable_message ? (
            <p className="text-base text-fg-muted">{recovery.unavailable_message}</p>
          ) : null}
          {recoveryAction && recoveryLabel ? (
            <Button
              type="button"
              onPress={() =>
                gate(recoveryConfirm, recoveryLabel, () => router.post(recoveryAction))
              }
            >
              {recoveryLabel}
            </Button>
          ) : null}
        </Card>
      ) : null}

      {termination ? (
        <Card>
          {termination.available_at_message ? (
            <p className="text-base text-fg-muted">{termination.available_at_message}</p>
          ) : null}
          {terminationAction && terminationLabel ? (
            <Button
              type="button"
              variant="danger"
              onPress={() =>
                gate(terminationConfirm, terminationLabel, () => router.delete(terminationAction))
              }
            >
              {terminationLabel}
            </Button>
          ) : null}
        </Card>
      ) : null}

      <p className="text-base">
        <TextLink
          href={erasureLink.href}
          inertia
        >
          {erasureLink.label}
        </TextLink>
      </p>

      <p>
        <Button
          type="button"
          variant="secondary"
          onPress={signOutNow}
        >
          {signOut.label}
        </Button>
      </p>

      {dialog}
    </Page>
  );
}
