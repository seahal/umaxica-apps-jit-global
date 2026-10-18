import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
// Replaces `app/views/base/com/identity/privacy/erasure/statuses/show.html.erb`.

export type PrivacyErasureStatusShowProps = {
  title: string;
  empty_message: string;
  privacy_request: {
    status_term: string;
    status_label: string;
    received_term: string;
    received_at: string | null;
    response_due_term: string;
    response_due_at: string | null;
  } | null;
};

export default function PrivacyErasureStatusShow({
  title,
  empty_message: emptyMessage,
  privacy_request: privacyRequest,
}: PrivacyErasureStatusShowProps) {
  return (
    <Page title={title}>
      {privacyRequest ? (
        <DescriptionList
          items={[
            { term: privacyRequest.status_term, description: privacyRequest.status_label },
            { term: privacyRequest.received_term, description: privacyRequest.received_at },
            { term: privacyRequest.response_due_term, description: privacyRequest.response_due_at },
          ]}
        />
      ) : (
        <p className="text-base text-fg-muted">{emptyMessage}</p>
      )}
    </Page>
  );
}
