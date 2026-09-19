// A labelled select.
//
// React Aria's `Select` owns the listbox keyboard model — type-ahead, Home/End, arrow navigation,
// Escape to dismiss, and returning focus to the trigger — plus the popover positioning that keeps
// the list on screen. The application previously used a native `<select>`, which is also correct;
// this exists so a select participates in the same label, description and error wiring as
// `TextField`, which a native control cannot do without hand-written `aria-describedby`.
import {
  Select as AriaSelect,
  type SelectProps as AriaSelectProps,
  Button,
  FieldError,
  Label,
  ListBox,
  ListBoxItem,
  Popover,
  SelectValue,
  Text,
} from "react-aria-components";

export type SelectOption = {
  value: string;
  label: string;
  isDisabled?: boolean;
};

export type SelectProps = Omit<AriaSelectProps<SelectOption>, "isInvalid" | "children"> & {
  label: string;
  options: SelectOption[];
  description?: string;
  errorMessage?: string;
};

export default function Select({
  label,
  options,
  description,
  errorMessage,
  ...props
}: SelectProps) {
  const disabledKeys = options
    .filter((option) => option.isDisabled === true)
    .map((option) => option.value);

  return (
    <AriaSelect
      {...props}
      disabledKeys={props.disabledKeys ?? disabledKeys}
      isInvalid={Boolean(errorMessage)}
      className="flex flex-col gap-1"
    >
      <Label className="text-sm font-medium text-fg">{label}</Label>

      <Button
        className="flex items-center justify-between gap-2 rounded-md border border-line
          bg-surface px-3 py-2 text-left text-sm text-fg hovered:bg-surface-muted
          disabled:cursor-not-allowed disabled:opacity-50 invalid:border-danger"
      >
        <SelectValue className="placeholder:text-fg-muted" />
        {/* Decorative: the button already has an accessible name from its label. */}
        <span aria-hidden="true">▾</span>
      </Button>

      {description ? (
        <Text
          slot="description"
          className="text-xs text-fg-muted"
        >
          {description}
        </Text>
      ) : null}

      <FieldError className="text-sm text-danger">{errorMessage}</FieldError>

      <Popover className="w-(--trigger-width) overflow-auto rounded-md border border-line bg-surface shadow-lg">
        <ListBox
          items={options}
          className="p-1 outline-hidden"
        >
          {(option) => (
            <ListBoxItem
              id={option.value}
              textValue={option.label}
              // An option that does not say is enabled, which is what React Aria means by absent.
              isDisabled={option.isDisabled ?? false}
              className="cursor-default rounded-sm px-3 py-1.5 text-sm text-fg outline-hidden
                focused:bg-accent focused:text-accent-fg selected:font-semibold
                disabled:opacity-50"
            >
              {option.label}
            </ListBoxItem>
          )}
        </ListBox>
      </Popover>
    </AriaSelect>
  );
}
