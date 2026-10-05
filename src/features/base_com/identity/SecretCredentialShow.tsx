import ButtonLink from "@/components/ui/ButtonLink";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/secret_credentials/show.html.erb`. The timestamps arrive
// already localised.

export type SecretCredentialShowProps = {
  title: string;
  name: string;
  created_term: string;
  created_at: string;
  last_used_term: string;
  last_used_at: string;
  back_link: PageLink;
  edit_link: PageLink;
};

export default function SecretCredentialShow({
  title,
  name,
  created_term: createdTerm,
  created_at: createdAt,
  last_used_term: lastUsedTerm,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: SecretCredentialShowProps) {
  return (
    <Page
      title={title}
      description={name}
      up={backLink}
      upVisit="inertia"
      actions={
        <ButtonLink
          href={editLink.href}
          inertia
        >
          {editLink.label}
        </ButtonLink>
      }
    >
      <DescriptionList
        items={[
          { term: createdTerm, description: createdAt },
          { term: lastUsedTerm, description: lastUsedAt },
        ]}
      />
    </Page>
  );
}
