// The single-telephone screen, whose only action is deletion.
import { Link } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import type { ConfirmedAction, LabelledLink } from "@/features/identity/types";
import { csrfToken } from "@/lib/csrf";

export type TelephoneEditProps = {
  title: string;
  number: string;
  delete: ConfirmedAction;
  cancel_link: LabelledLink;
};

const LINK = "text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline";

export default function TelephoneEdit({
  title,
  number,
  delete: destroy,
  cancel_link: cancelLink,
}: TelephoneEditProps) {
  const { confirm, dialog } = useConfirm();

  // The submission is held back until the actor accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => form.submit(),
    );
  };

  return (
    <Page
      title={title}
      description={number}
      width="wide"
    >
      <form
        action={destroy.href}
        method="post"
        data-turbo="false"
        onSubmit={submit}
        className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4"
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
        <div>
          <Button
            type="submit"
            variant="danger"
          >
            {destroy.label}
          </Button>
        </div>
      </form>

      <div>
        <Link
          href={cancelLink.href}
          className={LINK}
        >
          {cancelLink.label}
        </Link>
      </div>
      {dialog}
    </Page>
  );
}
