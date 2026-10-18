import { useState } from "react";

// Ends the ceremony the page belongs to.
//
// Cancellation is a state transition on the server, never a link or a history step, so it is a
// document form: POST, with `_method` when the server's route is a DELETE. The server decides where
// the actor lands afterwards. The authenticity token is read when the form is submitted, so it is
// always the one the current document carries.
import Button from "@/components/ui/Button";
import { csrfToken } from "@/lib/csrf";

export type CeremonyCancellationProps = {
  label: string;
  action: string;
  method: "post" | "delete";
};

export default function CeremonyCancellation({ label, action, method }: CeremonyCancellationProps) {
  const [submitted, setSubmitted] = useState(false);
  const [authenticityToken, setAuthenticityToken] = useState("");

  return (
    <form
      action={action}
      method="post"
      data-turbo="false"
      onSubmit={() => {
        setAuthenticityToken(csrfToken());
        setSubmitted(true);
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
        value={authenticityToken}
        readOnly
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
