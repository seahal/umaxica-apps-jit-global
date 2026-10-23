import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget, { type TurnstileWidgetProps } from "@/features/turnstile/TurnstileWidget";

type AddressForm = {
  action: string;
  label: string;
  address: string;
  submit_label: string;
  turnstile?: TurnstileWidgetProps | null;
};

type PassCodeForm = {
  action: string;
  label: string;
  submit_label: string;
};

type Props = {
  title: string;
  description: string;
  address_form: AddressForm;
  errors?: string[];
  pass_code_form: PassCodeForm | null;
};

export default function RecoverySessionNew({
  title,
  description,
  address_form: addressForm,
  errors = [],
  pass_code_form: passCodeForm,
}: Props) {
  const [address, setAddress] = useState(addressForm.address);
  const [turnstileToken, setTurnstileToken] = useState("");
  const [passCode, setPassCode] = useState("");

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      {errors.length > 0 ? (
        <ul
          role="alert"
          className="flex flex-col gap-1 text-base text-error"
        >
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      ) : null}

      <Card>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            router.post(addressForm.action, {
              recovery_reentry: { address },
              "cf-turnstile-response": turnstileToken,
            });
          }}
          className="flex flex-col gap-4"
        >
          <TextField
            id="recovery_reentry_address"
            label={addressForm.label}
            type="email"
            autoComplete="email"
            value={address}
            onChange={setAddress}
          />
          {addressForm.turnstile ? (
            <TurnstileWidget
              key={addressForm.turnstile.challenge_id ?? "recovery"}
              {...addressForm.turnstile}
              onToken={setTurnstileToken}
            />
          ) : null}
          <Button type="submit">{addressForm.submit_label}</Button>
        </form>
      </Card>

      {passCodeForm ? (
        <Card>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              router.post(passCodeForm.action, { pass_code: passCode });
            }}
            className="flex flex-col gap-4"
          >
            <TextField
              id="recovery_pass_code"
              label={passCodeForm.label}
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={passCode}
              onChange={setPassCode}
            />
            <Button type="submit">{passCodeForm.submit_label}</Button>
          </form>
        </Card>
      ) : null}
    </Page>
  );
}
