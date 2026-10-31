import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

type Props = {
  title: string;
  notices: string[];
  form: { action: string; jurisdiction: string; submit_label: string };
};

export default function PrivacyErasureNew({ title, notices, form }: Props) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      <div className="flex flex-col gap-3 text-base text-fg-muted">
        {notices.map((notice) => (
          <p key={notice}>{notice}</p>
        ))}
      </div>

      <Button
        type="button"
        variant="danger"
        isDisabled
      >
        {form.submit_label}
      </Button>
    </Page>
  );
}
