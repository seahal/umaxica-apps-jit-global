// React port of `src/controllers/otp_resend_controller.js`.
//
// The endpoint, the request body and the three outcomes are unchanged: 200 with `resendable` clears
// the code field and reports that a new code was sent, 429 starts the cooldown the server dictated
// via `retry_after`, and anything else reports a failure. The resend state is an opaque server
// token; the browser only echoes it back.
import { useEffect, useRef, useState } from "react";

import Button from "@/components/ui/Button";
import { readBoolean, readNumber } from "@/lib/payload";

export type OtpResendMessages = {
  button_label: string;
  sent_message: string;
  too_soon_message: string;
  failed_message: string;
};

export type OtpResendButtonProps = {
  endpoint: string;
  state: string;
  messages: OtpResendMessages;
  /** Called after a successful resend so the form can clear the code the actor already typed. */
  onResent?: () => void;
};

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? "";
}

export default function OtpResendButton({
  endpoint,
  state,
  messages,
  onResent,
}: OtpResendButtonProps) {
  const [status, setStatus] = useState("");
  const [remaining, setRemaining] = useState(0);
  const remainingRef = useRef(0);

  // Kept in sync after commit rather than during render. resend reads it from a click handler, so
  // it never needs a value the current render has not committed yet.
  useEffect(() => {
    remainingRef.current = remaining;
  }, [remaining]);

  useEffect(() => {
    if (remaining <= 0) {
      return undefined;
    }

    const timer = window.setInterval(() => {
      setRemaining((seconds) => Math.max(seconds - 1, 0));
    }, 1000);

    return () => window.clearInterval(timer);
  }, [remaining]);

  const resend = async () => {
    /* v8 ignore next -- the button is disabled while remaining is positive */
    if (remainingRef.current > 0) {
      return;
    }

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({ state: state }),
      });

      const payload: unknown = await response.json();

      if (response.status === 200 && readBoolean(payload, "resendable") === true) {
        onResent?.();
        setStatus(messages.sent_message);
        setRemaining(0);
        return;
      }

      if (response.status === 429) {
        setStatus(messages.too_soon_message);
        setRemaining(Math.max(Math.ceil(readNumber(payload, "retry_after") ?? 0), 0));
        return;
      }

      setStatus(messages.failed_message);
    } catch {
      setStatus(messages.failed_message);
    }
  };

  return (
    <div className="flex flex-col items-start gap-2">
      <Button
        type="button"
        variant="secondary"
        size="sm"
        isDisabled={remaining > 0}
        onPress={() => void resend()}
      >
        {remaining > 0 ? `${messages.too_soon_message} (${remaining}s)` : messages.button_label}
      </Button>
      <p className="text-base text-fg-muted">{status}</p>
    </div>
  );
}
