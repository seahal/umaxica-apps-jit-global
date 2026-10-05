// A labelled radio group.
//
// React Aria's `RadioGroup` implements the group's keyboard model: arrow keys move between options
// and the group holds a single tab stop, which is what the WAI-ARIA radio pattern requires and what
// a bare list of `<input type="radio">` in a `<fieldset>` only partly provides. It also exposes the
// group's label, description and error to the whole group rather than to one option.
import {
  RadioButton,
  RadioField,
  RadioGroup as AriaRadioGroup,
  type RadioGroupProps as AriaRadioGroupProps,
  FieldError,
  Label,
  Text,
} from "react-aria-components";

export type RadioOption<Value extends string = string> = {
  value: Value;
  label: string;
  description?: string;
  isDisabled?: boolean;
};

/*
 * Generic over the option values so a caller with a closed set — the three theme names, say — gets
 * that union back from `onChange` instead of a bare `string` it has to assert its way out of.
 */
export type RadioGroupProps<Value extends string = string> = Omit<
  AriaRadioGroupProps,
  "isInvalid" | "children" | "value" | "defaultValue" | "onChange"
> & {
  label: string;
  options: RadioOption<Value>[];
  value?: Value;
  defaultValue?: Value;
  onChange?: (value: Value) => void;
  description?: string;
  errorMessage?: string;
};

export default function RadioGroup<Value extends string = string>({
  label,
  options,
  description,
  errorMessage,
  onChange,
  ...props
}: RadioGroupProps<Value>) {
  /*
   * React Aria reports the value as a plain string. Recovering the option it belongs to gives the
   * caller its own union back without an assertion. A value that is not in `options` can only mean
   * the group rendered something it was not given, so it is raised rather than quietly dropped or
   * passed through unchecked.
   */
  const handleChange = onChange
    ? (value: string) => {
        const option = options.find((candidate) => candidate.value === value);

        /* v8 ignore next -- React Aria only reports values it rendered from `options` */
        if (!option) {
          throw new Error(`RadioGroup ${label} selected ${value}, which is not one of its options`);
        }

        onChange(option.value);
      }
    : undefined;

  return (
    <AriaRadioGroup
      {...props}
      // Omitted rather than passed as undefined: React Aria declares `onChange` optional, and an
      // explicit undefined is a different thing from an absent handler.
      {...(handleChange === undefined ? {} : { onChange: handleChange })}
      isInvalid={Boolean(errorMessage)}
      className="flex flex-col gap-2"
    >
      <Label className="text-base font-medium text-fg">{label}</Label>

      {description ? (
        <Text
          slot="description"
          className="text-base text-fg-muted"
        >
          {description}
        </Text>
      ) : null}

      <div className="flex flex-col gap-2">
        {options.map((option) => (
          // `RadioField` owns the option's state and `RadioButton` is the clickable area; the
          // bare `Radio` that combined the two is deprecated in react-aria-components 1.20.
          <RadioField
            key={option.value}
            value={option.value}
            // An option that does not say is enabled, which is what React Aria means by absent.
            isDisabled={option.isDisabled ?? false}
          >
            <RadioButton
              className="ui-choice-target group flex min-h-11 cursor-pointer items-start gap-2 py-2 text-base text-fg
                disabled:cursor-not-allowed disabled:opacity-50"
            >
              <span
                aria-hidden="true"
                className="mt-0.5 flex size-4 shrink-0 items-center justify-center rounded-full
                border border-control bg-surface transition-colors group-selected:border-accent"
              >
                <span className="size-2 rounded-full bg-accent opacity-0 group-selected:opacity-100" />
              </span>
              <span className="flex flex-col">
                <span>{option.label}</span>
                {option.description ? (
                  <span className="text-base text-fg-muted">{option.description}</span>
                ) : null}
              </span>
            </RadioButton>
          </RadioField>
        ))}
      </div>

      <FieldError className="text-base text-error">{errorMessage}</FieldError>
    </AriaRadioGroup>
  );
}
