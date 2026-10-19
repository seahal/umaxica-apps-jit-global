import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";

type AddressForm = {
  action: string;
  label: string;
  address: string;
  submit_label: string;
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
  pass_code_form: PassCodeForm | null;
};

export default function WithdrawalSessionNew({
  title,
  description,
  address_form: addressForm,
  pass_code_form: passCodeForm,
}: Props) {
  const [address, setAddress] = useState(addressForm.address);
  const [passCode, setPassCode] = useState("");

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <Card>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            router.post(addressForm.action, { withdrawal_reentry: { address } });
          }}
          className="flex flex-col gap-4"
        >
          <TextField
            id="withdrawal_reentry_address"
            label={addressForm.label}
            type="email"
            autoComplete="email"
            value={address}
            onChange={setAddress}
          />
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
              id="withdrawal_pass_code"
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
