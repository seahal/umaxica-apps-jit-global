import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

type Props = { title: string; action: string; authenticity_token: string; submit: string; operation_id: string };

export default function SecretNew({ title, action, authenticity_token: csrf, submit, operation_id }: Props) {
  return (
    <Page
      title={title}
      width="narrow"
    >
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
        <input type="hidden" name="operation_id" value={operation_id} />
        <Button type="submit">{submit}</Button>
      </form>
    </Page>
  );
}
