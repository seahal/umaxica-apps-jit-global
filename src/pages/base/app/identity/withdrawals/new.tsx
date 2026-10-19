import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import type { IdentityLink } from "@/types/identity";

type ScheduleSection = {
  title: string;
  ack_label: string;
  submit_label: string;
  acknowledged: boolean;
  action: string;
  errors: string[];
};

type DeactivateSection = {
  title: string;
  ack_label: string;
  submit_label: string;
  confirm: string;
  action: string;
  errors: string[];
};

type Props = {
  title: string;
  already_deactivated: boolean;
  already_deactivated_message: string;
  recovery_link: IdentityLink;
  schedule: ScheduleSection;
  deactivate: DeactivateSection | null;
};

export default function WithdrawalNew({
  title,
  already_deactivated: alreadyDeactivated,
  already_deactivated_message: alreadyDeactivatedMessage,
  recovery_link: recoveryLink,
  schedule,
  deactivate,
}: Props) {
  const [ackSchedule, setAckSchedule] = useState(schedule.acknowledged);
  const [ackDeactivate, setAckDeactivate] = useState(false);
  const { confirm, dialog } = useConfirm();

  if (alreadyDeactivated) {
    return (
      <Page
        title={title}
        description={alreadyDeactivatedMessage}
        width="narrow"
      >
        <p>
          <ButtonLink
            href={recoveryLink.href}
            variant="secondary"
            inertia
          >
            {recoveryLink.label}
          </ButtonLink>
        </p>
      </Page>
    );
  }

  return (
    <Page
      title={title}
      width="narrow"
    >
      <Card heading={schedule.title}>
        <ErrorList errors={schedule.errors} />

        <form
          onSubmit={(event) => {
            event.preventDefault();
            router.get(schedule.action, { ack_schedule_purge: ackSchedule ? "1" : "0" });
          }}
          className="flex flex-col gap-4"
        >
          <Checkbox
            id="ack_schedule_purge"
            isSelected={ackSchedule}
            onChange={setAckSchedule}
          >
            {schedule.ack_label}
          </Checkbox>
          <Button type="submit">{schedule.submit_label}</Button>
        </form>
      </Card>

      {deactivate ? (
        <Card heading={deactivate.title}>
          <ErrorList errors={deactivate.errors} />

          <form
            onSubmit={(event) => {
              event.preventDefault();
              confirm(
                { message: deactivate.confirm, confirmLabel: deactivate.submit_label },
                () => {
                  router.patch(deactivate.action, {
                    ack_deactivate_today: ackDeactivate ? "1" : "0",
                  });
                },
              );
            }}
            className="flex flex-col gap-4"
          >
            <Checkbox
              id="ack_deactivate_today"
              isSelected={ackDeactivate}
              onChange={setAckDeactivate}
            >
              {deactivate.ack_label}
            </Checkbox>
            <Button
              type="submit"
              variant="danger"
            >
              {deactivate.submit_label}
            </Button>
          </form>
        </Card>
      ) : null}
      {dialog}
    </Page>
  );
}
