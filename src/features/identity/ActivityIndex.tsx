import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

export type ActivityRow = {
  occurred_at: string;
  activity: string;
  device: string;
  source: string;
  risk: string;
  risk_rank: number;
};

export type ActivityIndexProps = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  empty_message: string;
  columns: {
    occurred_at: string;
    activity: string;
    device: string;
    source: string;
    risk: string;
  };
  activities: ActivityRow[];
};

export default function ActivityIndex({
  title,
  description,
  back_link: backLink,
  empty_message: emptyMessage,
  columns,
  activities,
}: ActivityIndexProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
      width="wide"
    >
      {activities.length > 0 ? (
        <Table>
          <thead>
            <tr>
              <th scope="col">{columns.occurred_at}</th>
              <th scope="col">{columns.activity}</th>
              <th scope="col">{columns.device}</th>
              <th scope="col">{columns.source}</th>
              <th scope="col">{columns.risk}</th>
            </tr>
          </thead>
          <tbody>
            {activities.map((activity, index) => (
              <tr key={`${activity.occurred_at}-${index}`}>
                <td>{activity.occurred_at}</td>
                <td>{activity.activity}</td>
                <td>{activity.device}</td>
                <td>{activity.source}</td>
                <td>{activity.risk}</td>
              </tr>
            ))}
          </tbody>
        </Table>
      ) : (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      )}
    </Page>
  );
}
