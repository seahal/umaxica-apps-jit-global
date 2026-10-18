import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";

type PrivacyRequest = {
  status_label: string;
  received_label: string;
  response_due_label: string;
};

type Props = {
  title: string;
  empty_message: string;
  privacy_request: PrivacyRequest | null;
};

export default function PrivacyErasureStatusShow({
  title,
  empty_message: emptyMessage,
  privacy_request: privacyRequest,
}: Props) {
  return (
    <Page title={title}>
      {privacyRequest ? (
        <Card>
          <ul className="flex flex-col gap-2 text-base text-fg">
            <li>{privacyRequest.status_label}</li>
            <li className="text-fg-muted">{privacyRequest.received_label}</li>
            <li className="text-fg-muted">{privacyRequest.response_due_label}</li>
          </ul>
        </Card>
      ) : (
        <p className="text-base text-fg-muted">{emptyMessage}</p>
      )}
    </Page>
  );
}
