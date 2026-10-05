import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";

// The email re-entry screen shared by the withdrawal ceremony and the enforcement recovery
// ceremony: one form asks for the address, and the code form appears only once the server says a
// code has been issued.

export type ReentryAddressForm = {
  url: string;
  scope: string;
  field: string;
  label: string;
  value: string;
  submit_label: string;
};

export type ReentryPassCodeForm = {
  url: string;
  field: string;
  label: string;
  submit_label: string;
};

export type OtpReentryNewProps = {
  title: string;
  description?: string;
  generic_message?: string;
  address_form: ReentryAddressForm;
  pass_code_form: ReentryPassCodeForm | null;
};

export default function OtpReentryNew({
  title,
  description,
  generic_message: genericMessage,
  address_form: addressForm,
  pass_code_form: passCodeForm,
}: OtpReentryNewProps) {
  const [address, setAddress] = useState(addressForm.value);
  const [passCode, setPassCode] = useState("");
  const [processing, setProcessing] = useState(false);

  const message = description ?? genericMessage;

  const submitAddress = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      addressForm.url,
      { [addressForm.scope]: { [addressForm.field]: address } },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  const submitPassCode = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    /* v8 ignore next -- the pass-code form is not rendered when the prop is absent */
    if (!passCodeForm) {
      return;
    }
    router.post(
      passCodeForm.url,
      { [passCodeForm.field]: passCode },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <Page
      title={title}
      {...(message ? { description: message } : {})}
      width="narrow"
    >
      <form
        onSubmit={submitAddress}
        className="flex flex-col gap-4"
      >
        <TextField
          id={`${addressForm.scope}_${addressForm.field}`}
          label={addressForm.label}
          name={`${addressForm.scope}[${addressForm.field}]`}
          type="email"
          autoComplete="email"
          value={address}
          onChange={setAddress}
        />
        <Button
          type="submit"
          isDisabled={processing}
          className="w-fit"
        >
          {addressForm.submit_label}
        </Button>
      </form>

      {passCodeForm ? (
        <form
          onSubmit={submitPassCode}
          className="flex flex-col gap-4 border-t border-line pt-6"
        >
          <TextField
            id={passCodeForm.field}
            label={passCodeForm.label}
            name={passCodeForm.field}
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={passCode}
            onChange={setPassCode}
          />
          <Button
            type="submit"
            isDisabled={processing}
            className="w-fit"
          >
            {passCodeForm.submit_label}
          </Button>
        </form>
      ) : null}
    </Page>
  );
}
