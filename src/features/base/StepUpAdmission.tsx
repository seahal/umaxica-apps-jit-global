import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

export type StepUpAdmissionProps = {
  title: string;
  description: string;
  form: {
    action: string;
    scope: string;
    pt: string;
    submit_label: string;
  };
  cancel: { href: string; label: string };
};

export default function StepUpAdmission({
  title,
  description,
  form,
  cancel,
}: StepUpAdmissionProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <form
        action={form.action}
        method="post"
        data-turbo="false"
        className="flex flex-col gap-4"
        onSubmit={(event) => {
          const field = event.currentTarget.elements.namedItem("authenticity_token");
          if (field instanceof HTMLInputElement) field.value = csrfToken();
        }}
      >
        <input
          type="hidden"
          name="authenticity_token"
          defaultValue=""
        />
        <input
          type="hidden"
          name="scope"
          value={form.scope}
          readOnly
        />
        <input
          type="hidden"
          name="pt"
          value={form.pt}
          readOnly
        />
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit">{form.submit_label}</Button>
          <ButtonLink
            href={cancel.href}
            variant="secondary"
          >
            {cancel.label}
          </ButtonLink>
        </div>
      </form>
    </Page>
  );
}
