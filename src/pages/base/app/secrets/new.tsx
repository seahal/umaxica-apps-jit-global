import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

type Props = { title: string; action: string; authenticity_token: string; submit: string };

export default function SecretNew({ title, action, authenticity_token: csrf, submit }: Props) {
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
        <Button type="submit">{submit}</Button>
      </form>
    </Page>
  );
}
