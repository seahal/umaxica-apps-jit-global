import Page, { type PageUpLink } from "@/components/ui/Page";

type Props = {
  title: string;
  description: string;
  up_link?: PageUpLink | null;
};

export default function BillingsIndex({ title, description, up_link: upLink = null }: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={upLink}
      upVisit="inertia"
    />
  );
}
