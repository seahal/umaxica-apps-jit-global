// React port of `src/controllers/otp_resend_controller.js`.
//
// The ceremony is unchanged: the browser posts the opaque resend state to the same endpoint with the
// same CSRF header, and the server decides whether another code may be sent. A 429 starts the same
// client-side countdown, which is a courtesy - the server re-checks the cooldown on every request.
import { useCallback, useEffect, useRef, useState } from "react";

import Button from "@/components/ui/Button";
import { readBoolean, readNumber } from "@/lib/payload";

import { csrfToken } from "./csrf";

export type OtpResend = {
  endpoint: string;
  /** Opaque handle for the pending code; it authorizes nothing on its own. */
  state: string | null;
  button_label: string;
  sent_message: string;
  too_soon_message: string;
  failed_message: string;
};

export default function OtpResendButton({
  resend,
  onResent,
}: {
  resend: OtpResend;
  onResent: () => void;
}) {
  const [status, setStatus] = useState("");
  const [remaining, setRemaining] = useState(0);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopCountdown = useCallback(() => {
    if (timer.current) {
      clearInterval(timer.current);
      timer.current = null;
    }
  }, []);

  useEffect(() => stopCountdown, [stopCountdown]);

  const startCountdown = (seconds: number) => {
    stopCountdown();
    const initial = Math.max(Math.ceil(seconds), 0);
    setRemaining(initial);
    if (initial <= 0) {
      return;
    }
    timer.current = setInterval(() => {
      setRemaining((value) => {
        if (value <= 1) {
          stopCountdown();
          return 0;
        }
        return value - 1;
      });
    }, 1000);
  };

  const request = async () => {
    /* v8 ignore next -- the button is disabled while remaining is positive */
    if (remaining > 0) {
      return;
    }

    try {
      const response = await fetch(resend.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({ state: resend.state }),
      });

      const payload: unknown = await response.json();

      if (response.status === 200 && readBoolean(payload, "resendable") === true) {
        onResent();
        setStatus(resend.sent_message);
        stopCountdown();
        setRemaining(0);
        return;
      }

      if (response.status === 429) {
        setStatus(resend.too_soon_message);
        startCountdown(readNumber(payload, "retry_after") ?? 0);
        return;
      }

      setStatus(resend.failed_message);
    } catch {
      setStatus(resend.failed_message);
    }
  };

  return (
    <div className="flex flex-col items-start gap-2">
      <Button
        type="button"
        variant="secondary"
        size="sm"
        isDisabled={remaining > 0}
        onPress={() => void request()}
      >
        {remaining > 0 ? `${resend.too_soon_message} (${remaining}s)` : resend.button_label}
      </Button>
      <p className="text-base text-fg-muted">{status}</p>
    </div>
  );
}
