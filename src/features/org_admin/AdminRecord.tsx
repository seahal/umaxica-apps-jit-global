// One administration record: its current state, and the operations the operator may start on it.
import ButtonLink from "@/components/ui/ButtonLink";
import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";

import AdminContextPanel, { AdminNotices } from "./AdminContextPanel";
import type { AdminBaseProps, AdminField, AdminLink } from "./types";

export type AdminRecordSection = {
  heading: string;
  fields?: AdminField[];
  links?: AdminLink[];
  empty_message?: string;
};

export type AdminRecordProps = AdminBaseProps & {
  fields: AdminField[];
  actions: AdminLink[];
  sections: AdminRecordSection[];
};

export default function AdminRecord({
  title,
  description,
  up_link: upLink = null,
  context,
  notices = [],
  fields,
  actions,
  sections,
}: AdminRecordProps) {
  return (
    <Page
      title={title}
      {...(description ? { description } : {})}
      up={upLink}
      upVisit="document"
    >
      <AdminContextPanel context={context} />
      <AdminNotices notices={notices} />

      <Card>
        <DescriptionList items={fields} />
      </Card>

      {actions.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          {actions.map((action) => (
            <ButtonLink
              key={action.href}
              href={action.href}
              variant="secondary"
            >
              {action.label}
            </ButtonLink>
          ))}
        </div>
      ) : null}

      {sections.map((section) => (
        <Card
          key={section.heading}
          heading={section.heading}
        >
          {section.fields && section.fields.length > 0 ? (
            <DescriptionList items={section.fields} />
          ) : null}
          {section.links && section.links.length > 0 ? (
            <ul className="flex flex-col gap-1 text-sm">
              {section.links.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="underline-offset-4 hover:underline"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          ) : null}
          {(section.fields?.length ?? 0) === 0 &&
          (section.links?.length ?? 0) === 0 &&
          section.empty_message ? (
            <p className="text-sm text-fg-muted">{section.empty_message}</p>
          ) : null}
        </Card>
      ))}
    </Page>
  );
}
