// Ends the ceremony the page belongs to.
//
// Cancellation is a state transition on the server, never a link or a history step, so it is a
// document form: POST, with `_method` when the server's route is a DELETE. The server decides where
// the actor lands afterwards. The authenticity token is read when the form is submitted, so it is
// always the one the current document carries.
import Button from "@/components/ui/Button";
import { csrfToken } from "@/lib/csrf";
import { useState } from "react";

export type CeremonyCancellationProps = {
  label: string;
  action: string;
  method: "post" | "delete";
};

export default function CeremonyCancellation({ label, action, method }: CeremonyCancellationProps) {
  const [submitted, setSubmitted] = useState(false);

  return (
    <form
      action={action}
      method="post"
      data-turbo="false"
      onSubmit={(event) => {
        setSubmitted(true);
        const field = event.currentTarget.elements.namedItem("authenticity_token");
        if (field instanceof HTMLInputElement) field.value = csrfToken();
      }}
    >
      {method === "post" ? null : (
        <input
          type="hidden"
          name="_method"
          value={method}
          readOnly
        />
      )}
      <input
        type="hidden"
        name="authenticity_token"
        defaultValue=""
      />
      <Button
        type="submit"
        variant="secondary"
        isDisabled={submitted}
      >
        {label}
      </Button>
    </form>
  );
}
