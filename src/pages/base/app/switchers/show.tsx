import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import ErrorList from "@/components/ui/ErrorList";
import Page, { type PageUpLink } from "@/components/ui/Page";

type SwitcherSelection = {
  account_public_id: string | null;
  organization_public_id: string | null;
  organization_unit_public_id: string | null;
  avatar_public_id: string | null;
};

type SwitcherCandidate = {
  account_public_id: string | null;
  organization_public_id: string | null;
  avatar_public_id: string | null;
};

type Props = {
  title: string;
  current: SwitcherSelection | null;
  candidates: SwitcherCandidate[];
  // Present only when a switch attempt was rejected.
  error: string | null;
  up_link?: PageUpLink | null;
};

export default function SwitcherShow({
  title,
  current,
  candidates,
  error,
  up_link: upLink = null,
}: Props) {
  return (
    <Page
      title={title}
      description="Signed in"
      up={upLink}
      upVisit="inertia"
    >
      <ErrorList errors={error === null ? [] : [error]} />

      <Card heading="Current context">
        {current ? (
          <DescriptionList
            items={[
              { term: "Account", description: current.account_public_id },
              { term: "Organization", description: current.organization_public_id },
              { term: "Organization unit", description: current.organization_unit_public_id },
              { term: "Avatar", description: current.avatar_public_id },
            ]}
          />
        ) : (
          <p className="text-sm text-fg-muted">No current context.</p>
        )}
      </Card>

      <Card heading="Available contexts">
        <ul className="flex flex-col gap-2 text-sm text-fg">
          {candidates.map((candidate) => (
            <li
              key={`${candidate.account_public_id}/${candidate.organization_public_id}/${candidate.avatar_public_id}`}
              className="font-mono break-all"
            >
              account={candidate.account_public_id} organization={candidate.organization_public_id}{" "}
              avatar={candidate.avatar_public_id}
            </li>
          ))}
        </ul>
      </Card>
    </Page>
  );
}
