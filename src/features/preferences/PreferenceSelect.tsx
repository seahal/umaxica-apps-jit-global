import { Link, router, usePage } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Select from "@/components/ui/Select";
import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";
import { applyTheme, fetchStoredTheme } from "@/lib/theme";

// Backs both `option` (region, timezone, language, theme) and `selectable` (currency, calendar,
// clock, motion, density, pagination). The two shared ERB templates they replace differed only in
// how the server built the choice labels, which is still where that difference lives.
//
// A theme write must not recolour the document until the server accepts it and GET /web/v0/theme
// reports the stored value — the same contract as the chrome ThemeControls on every Inertia surface.

type PreferenceChoice = {
  label: string;
  value: number;
  disabled?: boolean;
};

type PreferenceSelectForm = {
  action: string;
  method: string;
  /** Rails parameter wrapper, e.g. `preference_region`. */
  scope: string;
  /** Attribute inside the wrapper, e.g. `option_id`. */
  field: string;
  label: string;
  value: number;
  choices: PreferenceChoice[];
  submit_label: string;
  submitting_label: string;
};

type PreferenceLinkedScreen = PreferenceLink & {
  key: string;
};

export type PreferenceSelectProps = {
  screen: string;
  title: string;
  description: string;
  back_link: PreferenceLink;
  form: PreferenceSelectForm;
  region_link: PreferenceLink | null;
  linked_screens: PreferenceLinkedScreen[];
};

export default function PreferenceSelect({
  screen,
  title,
  description,
  back_link: backLink,
  form,
  region_link: regionLink,
  linked_screens: linkedScreens,
}: PreferenceSelectProps) {
  const [value, setValue] = useState(String(form.value));
  const [processing, setProcessing] = useState(false);
  const { errors } = usePage().props;
  const error = errors[form.field];

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { [form.scope]: { [form.field]: value } },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
        onSuccess: () => {
          // The theme screen writes through Inertia rather than the chrome control. Colour
          // follows the value the server stored, and only after that write is accepted.
          if (screen === "theme") {
            void applyThemeAfterPreferenceWrite();
          }
        },
      },
    );
  };

  return (
    <PreferenceScreenFrame
      title={title}
      description={description}
      back_link={backLink}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <Select
          label={form.label}
          name={`${form.scope}[${form.field}]`}
          value={value}
          onChange={(next) => {
            /* v8 ignore next -- React Aria reports null only when the selection is cleared */
            if (next !== null) {
              setValue(String(next));
            }
          }}
          {...(error === undefined ? {} : { errorMessage: error })}
          options={form.choices.map((choice) => ({
            value: String(choice.value),
            label: choice.label,
            isDisabled: choice.disabled === true,
          }))}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={processing}
          >
            {processing ? form.submitting_label : form.submit_label}
          </Button>
          {regionLink ? (
            <Link
              href={regionLink.href}
              className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
            >
              {regionLink.label}
            </Link>
          ) : null}
        </div>
      </form>

      {screen === "region" && linkedScreens.length > 0 ? (
        <ul className="flex flex-col gap-2">
          {linkedScreens.map((linked) => (
            <li key={linked.key}>
              <Link
                href={linked.href}
                className="block rounded-lg border border-line bg-surface px-4 py-3 text-sm
                  font-medium text-fg hover:bg-surface-muted"
              >
                {linked.label}
              </Link>
            </li>
          ))}
        </ul>
      ) : null}
    </PreferenceScreenFrame>
  );
}

async function applyThemeAfterPreferenceWrite(): Promise<void> {
  const stored = await fetchStoredTheme();
  if (stored) {
    applyTheme(stored);
  }
}
