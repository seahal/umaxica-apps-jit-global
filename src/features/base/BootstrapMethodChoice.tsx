// Choice of a first authenticator, shown by Base to an actor who has none.
//
// Each method is a submit button of one document form: choosing a method starts a transaction on
// the server, so it is a POST and never a link. The server decides which methods are offered and
// where the browser goes next. The authenticity token is read when the form is submitted.
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

export type BootstrapMethodChoiceProps = {
  title: string;
  description: string;
  methods: { key: string; label: string }[];
  form: { action: string; scope: string; pt: string };
  cancel: { href: string; label: string };
};

export default function BootstrapMethodChoice({
  title,
  description,
  methods,
  form,
  cancel,
}: BootstrapMethodChoiceProps) {
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
          if (field instanceof HTMLInputElement) {
            field.value = csrfToken();
          }
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
        <div className="flex flex-col gap-3">
          {methods.map((method) => (
            <Button
              key={method.key}
              type="submit"
              name="registration_method"
              value={method.key}
            >
              {method.label}
            </Button>
          ))}
        </div>
        <div>
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
