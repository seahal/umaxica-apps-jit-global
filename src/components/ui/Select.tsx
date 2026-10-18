// Ordinary single-choice fields use the OS picker. The form owner retains validation and payloads.
import { useId, type ComponentPropsWithoutRef } from "react";

export type SelectOption = {
  value: string;
  label: string;
  isDisabled?: boolean;
};

export type SelectProps = Omit<
  ComponentPropsWithoutRef<"select">,
  "children" | "onChange" | "value" | "defaultValue" | "disabled" | "required" | "multiple"
> & {
  label: string;
  options: SelectOption[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  isDisabled?: boolean;
  isRequired?: boolean;
  description?: string;
  errorMessage?: string;
};

export default function Select({
  label,
  options,
  description,
  errorMessage,
  id,
  onChange,
  isDisabled,
  isRequired,
  "aria-describedby": describedBy,
  className,
  ...props
}: SelectProps) {
  const generatedId = useId();
  const controlId = id ?? generatedId;
  const descriptionId = `${controlId}-description`;
  const errorId = `${controlId}-error`;
  const descriptions =
    [describedBy, description ? descriptionId : null, errorMessage ? errorId : null]
      .filter(Boolean)
      .join(" ") || undefined;

  return (
    <div className="flex flex-col gap-2">
      <label
        htmlFor={controlId}
        className="text-base font-medium text-fg"
      >
        {label}
      </label>
      {description ? (
        <p
          id={descriptionId}
          className="text-base text-fg-muted"
        >
          {description}
        </p>
      ) : null}
      <select
        {...props}
        id={controlId}
        disabled={isDisabled}
        required={isRequired}
        aria-describedby={descriptions}
        aria-invalid={Boolean(errorMessage)}
        {...(onChange ? { onChange: (event) => onChange(event.currentTarget.value) } : {})}
        className={[
          "min-h-12 w-full rounded-md border border-control bg-surface px-3 py-2 text-base text-fg disabled:cursor-not-allowed disabled:opacity-50",
          errorMessage ? "border-danger" : null,
          className,
        ]
          .filter(Boolean)
          .join(" ")}
      >
        {options.map((option) => (
          <option
            key={option.value}
            value={option.value}
            disabled={option.isDisabled}
          >
            {option.label}
          </option>
        ))}
      </select>
      {errorMessage ? (
        <p
          id={errorId}
          className="text-base text-error"
        >
          {errorMessage}
        </p>
      ) : null}
    </div>
  );
}
