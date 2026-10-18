// A single secret credential's metadata. Timestamps arrive already localised.
import { Link } from "@inertiajs/react";

import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import type { LabelledLink } from "@/features/identity/types";

export type SecretCredentialShowProps = {
  title: string;
  description: string;
  name: string;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string;
  last_used_at: string;
  back_link: LabelledLink;
  edit_link: LabelledLink;
};

const LINK = "text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline";

export default function SecretCredentialShow({
  title,
  description,
  name,
  created_at_label: createdAtLabel,
  created_at: createdAt,
  last_used_at_label: lastUsedAtLabel,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: SecretCredentialShowProps) {
  return (
    <Page
      title={title}
      description={description}
      width="wide"
    >
      <Card>
        <h2 className="text-lg font-semibold text-fg">{name}</h2>
        <dl className="flex flex-col gap-2 text-base">
          <div className="flex items-center justify-between gap-4">
            <dt className="text-fg-muted">{createdAtLabel}</dt>
            <dd className="text-fg">{createdAt}</dd>
          </div>
          <div className="flex items-center justify-between gap-4">
            <dt className="text-fg-muted">{lastUsedAtLabel}</dt>
            <dd className="text-fg">{lastUsedAt}</dd>
          </div>
        </dl>
      </Card>

      <div className="flex items-center gap-4">
        <Link
          href={backLink.href}
          className={LINK}
        >
          {backLink.label}
        </Link>
        <Link
          href={editLink.href}
          className={LINK}
        >
          {editLink.label}
        </Link>
      </div>
    </Page>
  );
}
