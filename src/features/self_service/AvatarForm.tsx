// The avatar create/update form. The server sends the action URL, the HTTP verb the route expects
// and every label already translated, so the component only binds fields and reports errors.
import { useForm } from "@inertiajs/react";
import { useState } from "react";
import type { SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import type { PageUpLink } from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";

export type AvatarFormProps = {
  title: string;
  up_link?: PageUpLink | null;
  heading: string;
  action: string;
  method: "post" | "patch";
  submit_label: string;
  moniker: {
    label: string;
    value: string;
    max_bytes: number;
    max_grapheme_clusters: number;
    client_validation: {
      blank: string;
      invalid: string;
      max_bytes: string;
      max_graphemes: string;
    };
  };
  // Present only on creation: the handle is immutable once the avatar exists.
  handle: { label: string; value: string; maxlength: number } | null;
};

function monikerValidationError(value: string, moniker: AvatarFormProps["moniker"]): string | null {
  const messages = moniker.client_validation;

  for (const character of value) {
    const codePoint = character.codePointAt(0);
    if (codePoint !== undefined && codePoint >= 0xd800 && codePoint <= 0xdfff) {
      return messages.invalid;
    }
  }

  const normalized = value.normalize("NFC");
  if (normalized.length === 0 || /^\p{White_Space}*$/u.test(normalized)) {
    return messages.blank;
  }
  if (/^\p{White_Space}|\p{White_Space}$/u.test(normalized)) {
    return messages.invalid;
  }
  if (new TextEncoder().encode(normalized).byteLength > moniker.max_bytes) {
    return messages.max_bytes;
  }

  for (const character of normalized) {
    const codePoint = character.codePointAt(0);
    if (
      codePoint !== undefined &&
      (codePoint <= 0x1f ||
        (codePoint >= 0x7f && codePoint <= 0x9f) ||
        (codePoint >= 0x2028 && codePoint <= 0x2029) ||
        codePoint === 0x200b ||
        codePoint === 0xfeff ||
        codePoint === 0x061c ||
        (codePoint >= 0x200e && codePoint <= 0x200f) ||
        (codePoint >= 0x202a && codePoint <= 0x202e) ||
        (codePoint >= 0x2066 && codePoint <= 0x2069))
    ) {
      return messages.invalid;
    }
  }

  const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  let graphemeClusters = 0;
  for (const _segment of segmenter.segment(normalized)) {
    graphemeClusters += 1;
    if (graphemeClusters > moniker.max_grapheme_clusters) {
      return messages.max_graphemes;
    }
  }

  return null;
}

export default function AvatarForm({
  title,
  up_link: upLink = null,
  heading,
  action,
  method,
  submit_label: submitLabel,
  moniker,
  handle,
}: AvatarFormProps) {
  const form = useForm({
    avatar: { moniker: moniker.value, handle: handle ? handle.value : "" },
  });
  const { data, setData, errors, processing } = form;
  const [clientMonikerError, setClientMonikerError] = useState<string | null>(null);
  const monikerError = clientMonikerError ?? errors["avatar.moniker"];

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const validationError = monikerValidationError(data.avatar.moniker, moniker);
    if (validationError) {
      setClientMonikerError(validationError);
      return;
    }
    setClientMonikerError(null);

    if (method === "post") {
      form.post(action);
    } else {
      form.patch(action);
    }
  };

  return (
    <section
      aria-label={title}
      className="flex flex-col gap-6"
    >
      {upLink ? (
        <TextLink
          href={upLink.href}
          inertia
        >
          {upLink.label}
        </TextLink>
      ) : null}
      <h1 className="text-2xl font-bold text-fg">{heading}</h1>

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors.avatar === undefined ? [] : [errors.avatar]} />
        <TextField
          id="avatar_moniker"
          label={moniker.label}
          name="avatar[moniker]"
          isRequired
          value={data.avatar.moniker}
          onChange={(value) => {
            setClientMonikerError(null);
            setData("avatar", { ...data.avatar, moniker: value });
          }}
          {...(monikerError === undefined ? {} : { errorMessage: monikerError })}
        />

        {handle ? (
          <TextField
            id="avatar_handle"
            label={handle.label}
            name="avatar[handle]"
            maxLength={handle.maxlength}
            value={data.avatar.handle}
            onChange={(value) => setData("avatar", { ...data.avatar, handle: value })}
            {...(errors["avatar.handle"] === undefined
              ? {}
              : { errorMessage: errors["avatar.handle"] })}
          />
        ) : null}

        <div>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {submitLabel}
          </Button>
        </div>
      </form>
    </section>
  );
}
