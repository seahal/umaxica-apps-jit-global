import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

type Props = {
  title: string;
  name: string;
  id: string;
  action: string;
  authenticity_token: string;
  rename: string;
  revoke: string;
};

export default function SecretShow({
  title,
  name,
  id,
  action,
  authenticity_token: csrf,
  rename,
  revoke,
}: Props) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      <p className="font-mono text-sm text-fg-muted wrap-anywhere">{id}</p>
      <form
        action={action}
        method="post"
        className="flex flex-col items-start gap-4"
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
        <label htmlFor="secret-name">{rename}</label>
        <input
          id="secret-name"
          className="min-h-12 w-full rounded-md border border-control bg-surface px-3 py-2 text-base text-fg"
          name="name"
          defaultValue={name}
          maxLength={255}
          required
        />
        <Button type="submit">{rename}</Button>
      </form>
      <form
        action={action}
        method="post"
        className="flex flex-col items-start gap-4"
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
          variant="danger"
        >
          {revoke}
        </Button>
      </form>
    </Page>
  );
}
