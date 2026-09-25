// A labelled text input with its error attached to it.
//
// This closes a real gap: before this component no field in the application was programmatically
// bound to its message. Errors rendered as a sibling `role="alert"` block, so a screen reader
// moving through the form announced the input with no indication that it was the one rejected, and
// `aria-invalid` appeared nowhere in `src/`.
//
// React Aria's `TextField` owns that wiring. Giving it `isInvalid` and a `FieldError` is enough for
// it to generate the ids, set `aria-invalid` on the input and point `aria-describedby` at the
// description and the message. None of that is written by hand below.
//
// The server remains authoritative. A form may also perform a narrow client-side preflight for
// faster feedback; callers pass either rejection as already-translated text.
import {
  TextField as AriaTextField,
  type TextFieldProps as AriaTextFieldProps,
  FieldError,
  Input,
  Label,
  Text,
  TextArea,
} from "react-aria-components";

export type TextFieldProps = Omit<AriaTextFieldProps, "isInvalid" | "children"> & {
  /** The field's visible label. Required: an unlabelled input is not acceptable here. */
  label: string;
  /** Helper text rendered under the control and referenced by `aria-describedby`. */
  description?: string;
  /** An already-translated rejection message. Its presence marks the field invalid. */
  errorMessage?: string;
  /** Renders a `<textarea>` instead of an `<input>`. */
  multiline?: boolean;
  placeholder?: string;
  /**
   * Forwarded to the control. React Aria's own prop set stops at the attributes it needs to build
   * the field, and this one is a keyboard hint the operator identifier field genuinely wants:
   * `characters` puts a phone keyboard in caps for a field whose value is uppercase.
   */
  autoCapitalize?: string;
};

const CONTROL =
  "w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg " +
  "placeholder:text-fg-muted disabled:cursor-not-allowed disabled:opacity-50";

export default function TextField({
  label,
  description,
  errorMessage,
  multiline = false,
  placeholder,
  autoCapitalize,
  className,
  ...props
}: TextFieldProps) {
  // Omitted rather than passed as undefined, for the same reason as `placeholder` below.
  const controlAttributes = {
    ...(placeholder === undefined ? {} : { placeholder }),
    ...(autoCapitalize === undefined ? {} : { autoCapitalize }),
  };
  return (
    <AriaTextField
      {...props}
      // The server's message is the only source of invalidity, so its presence is the flag.
      isInvalid={Boolean(errorMessage)}
      className={["flex flex-col gap-1", typeof className === "function" ? undefined : className]
        .filter(Boolean)
        .join(" ")}
    >
      <Label className="text-sm font-medium text-fg">{label}</Label>

      {/*
        `placeholder` is omitted rather than set to undefined when the caller gave none: React
        Aria declares it optional, and an explicit undefined is a different value from absent.
      */}
      {multiline ? (
        <TextArea
          {...controlAttributes}
          className={`${CONTROL} min-h-24 invalid:border-danger`}
        />
      ) : (
        <Input
          {...controlAttributes}
          className={`${CONTROL} invalid:border-danger`}
        />
      )}

      {description ? (
        <Text
          slot="description"
          className="text-xs text-fg-muted"
        >
          {description}
        </Text>
      ) : null}

      {/* Rendered only while `isInvalid`, and already referenced by the input's aria-describedby. */}
      <FieldError className="text-sm text-danger">{errorMessage}</FieldError>
    </AriaTextField>
  );
}
