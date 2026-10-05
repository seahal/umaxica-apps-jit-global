// A read-only identity screen: a heading, some finished paragraphs and a way back.
import Page from "@/components/ui/Page";

export type InfoPageProps = {
  title: string;
  paragraphs: string[];
  back_link: { label: string; href: string };
};

export default function InfoPage({ title, paragraphs, back_link: backLink }: InfoPageProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
      width="narrow"
    >
      <div className="ui-prose">
        {paragraphs.map((paragraph) => (
          <p
            key={paragraph}
            className="text-base text-pretty text-fg-muted"
          >
            {paragraph}
          </p>
        ))}
      </div>
    </Page>
  );
}
