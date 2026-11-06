import Page from "@/components/ui/Page";

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  identities: { provider: string; status: string }[];
};

export default function SocialIdentitiesIndex({
  title,
  description,
  back_link: backLink,
  identities,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
    >
      <dl className="flex flex-col gap-4">
        {identities.map((identity) => (
          <div key={identity.provider}>
            <dt>{identity.provider}</dt>
            <dd>{identity.status}</dd>
          </div>
        ))}
      </dl>
    </Page>
  );
}
