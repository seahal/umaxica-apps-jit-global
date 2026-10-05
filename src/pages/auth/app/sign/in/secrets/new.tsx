import { useRef } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import type { SignInTurnstile } from "@/features/auth/signin/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type Props = {
  title: string;
  label: string;
  submit: string;
  error: string | null;
  action: string;
  authenticity_token: string;
  turnstile: SignInTurnstile;
};

export default function SecretSignIn({
  title,
  label,
  submit,
  error,
  action,
  authenticity_token: csrf,
  turnstile,
}: Props) {
  const challenge = useRef<HTMLInputElement>(null);
  return (
    <Page
      title={title}
      width="narrow"
    >
      {error && (
        <p
          id="secret-sign-in-error"
          role="alert"
          className="text-base text-error"
        >
          {error}
        </p>
      )}
      <form
        action={action}
        aria-label={title}
        aria-describedby={error ? "secret-sign-in-error" : undefined}
        method="post"
        className="flex flex-col items-start gap-4"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrf}
        />
        <label htmlFor="sign-in-secret">{label}</label>
        <input
          id="sign-in-secret"
          className="min-h-12 w-full rounded-md border border-control bg-surface px-3 py-2 text-base text-fg"
          name="secret"
          type="password"
          autoComplete="current-password"
          minLength={32}
          maxLength={32}
          pattern="[1-9A-HJ-NP-Za-km-z]{32}"
          required
        />
        <input
          ref={challenge}
          type="hidden"
          name="cf-turnstile-response"
        />
        <TurnstileWidget
          {...turnstile}
          onToken={(token) => {
            if (challenge.current) {
              challenge.current.value = token;
            }
          }}
        />
        <Button type="submit">{submit}</Button>
      </form>
    </Page>
  );
}
