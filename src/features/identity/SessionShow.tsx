import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";

type SessionSummary = {
  device: string;
  last_activity: string;
  created: string;
  expires_at: string;
  status: string;
  mode?: string;
};

type Props = {
  title: string;
  back_link: { label: string; href: string };
  expires_at_description: string;
  columns: {
    device: string;
    last_activity: string;
    created: string;
    expires_at: string;
    status: string;
    mode?: string;
  };
  session: SessionSummary;
};

export default function SessionShow({
  title,
  back_link: backLink,
  expires_at_description: expiresAtDescription,
  columns,
  session,
}: Props) {
  const items = [
    { term: columns.device, description: session.device },
    ...(columns.mode ? [{ term: columns.mode, description: session.mode ?? "" }] : []),
    { term: columns.last_activity, description: session.last_activity },
    { term: columns.created, description: session.created },
    { term: columns.expires_at, description: session.expires_at },
    { term: columns.status, description: session.status },
  ];

  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
    >
      <p className="mb-4 text-sm text-fg-muted">{expiresAtDescription}</p>
      <Card>
        <DescriptionList items={items} />
      </Card>
    </Page>
  );
}
