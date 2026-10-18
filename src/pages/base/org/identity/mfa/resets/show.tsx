import Page from "@/components/ui/Page";
import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  reset_unavailable: string;
  back_link: IdentityLink;
};

export default function MfaResetShow({
  title,
  reset_unavailable: resetUnavailable,
  back_link: backLink,
}: Props) {
  return (
    <Page
      title={title}
      description={resetUnavailable}
      up={backLink}
      width="narrow"
    />
  );
}
