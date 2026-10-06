import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

type Props = {
  title: string;
  state: string;
  presentation: string;
  confirmation: string;
  authenticity_token: string;
  present_label: string;
  confirm_label: string;
  cancel_label: string;
  notice: string | null;
  continue_href: string;
  continue_label: string;
  completion_action?: string;
  checkpoint_version?: number;
  reattempt_action?: string | null;
  reattempt_of?: string | null;
  reattempt_label?: string;
};

export default function Issuance({
  title,
  state,
  presentation,
  confirmation,
  authenticity_token: csrf,
  present_label: present,
  confirm_label: confirm,
  cancel_label: cancel,
  notice,
  continue_href,
  continue_label,
  completion_action,
  checkpoint_version,
  reattempt_action,
  reattempt_of,
  reattempt_label,
}: Props) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      {notice && <output className="block">{notice}</output>}
      {reattempt_action && reattempt_of && (
        <form method="post" action={reattempt_action} className="flex flex-col items-start gap-4">
          <input type="hidden" name="authenticity_token" value={csrf} />
          <input type="hidden" name="reattempt_of" value={reattempt_of} />
          {checkpoint_version !== undefined && (
            <input
              type="hidden"
              name="checkpoint_version"
              value={checkpoint_version}
            />
          )}
          <Button type="submit">{reattempt_label}</Button>
        </form>
      )}
      {(state === "omitted" || state === "confirmed") && !completion_action && (
        <TextLink href={continue_href}>{continue_label}</TextLink>
      )}
      {(state === "omitted" || state === "confirmed") && completion_action && (
        <form
          method="post"
          className="flex flex-col items-start gap-4"
          action={completion_action}
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrf}
          />
          <input
            type="hidden"
            name="_method"
            value="patch"
          />
          <input
            type="hidden"
            name="checkpoint_version"
            value={checkpoint_version}
          />
          <Button type="submit">{continue_label}</Button>
        </form>
      )}
      {state === "pending_presentation" && (
        <form
          method="post"
          className="flex flex-col items-start gap-4"
          action={presentation}
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrf}
          />
          <Button type="submit">{present}</Button>
        </form>
      )}
      {state === "pending_confirmation" && (
        <form
          method="post"
          className="flex flex-col items-start gap-4"
          action={confirmation}
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrf}
          />
          <input
            type="hidden"
            name="_method"
            value="patch"
          />
          {checkpoint_version !== undefined && (
            <input
              type="hidden"
              name="checkpoint_version"
              value={checkpoint_version}
            />
          )}
          <label className="flex min-h-11 items-center gap-3">
            <input
              type="checkbox"
              name="stored"
              value="1"
              required
            />
            {confirm}
          </label>
          <Button type="submit">{confirm}</Button>
        </form>
      )}
      {(state === "pending_presentation" || state === "pending_confirmation") && (
        <form
          method="post"
          className="flex flex-col items-start gap-4"
          action={confirmation}
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrf}
          />
          <input
            type="hidden"
            name="_method"
            value="delete"
          />
          <Button
            type="submit"
            variant="secondary"
          >
            {cancel}
          </Button>
        </form>
      )}
    </Page>
  );
}
