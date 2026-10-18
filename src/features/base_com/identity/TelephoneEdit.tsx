import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import DestructiveButton from "@/features/base_com/identity/DestructiveButton";
import type { ConfirmedAction, PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/telephones/edit.html.erb`, which offers removal only.

export type TelephoneEditProps = {
  title: string;
  number: string;
  destroy: ConfirmedAction;
  cancel_link: PageLink;
};

export default function TelephoneEdit({
  title,
  number,
  destroy,
  cancel_link: cancelLink,
}: TelephoneEditProps) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      <p className="rounded-lg border border-line bg-surface p-4 text-base font-medium text-fg">
        {number}
      </p>

      <div className="flex flex-wrap items-center gap-3">
        <DestructiveButton action={destroy} />
        <TextLink
          href={cancelLink.href}
          inertia
          tone="muted"
        >
          {cancelLink.label}
        </TextLink>
      </div>
    </Page>
  );
}
