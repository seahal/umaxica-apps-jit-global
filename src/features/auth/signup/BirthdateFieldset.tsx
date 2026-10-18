// React port of the `sign_up_birthdate_fields` helper.
//
// The part order and the separator follow the visitor's date-format preference, which the server
// resolves and sends; the browser never re-derives it. Today's date is a typing convenience only —
// it is never eligible, and the server rejects it on both the checkpoint policy and the model.
export type BirthdatePart = {
  part: string;
  label: string;
  placeholder: string;
  value: string;
  min: number;
  max: number;
};

export type BirthdateFieldsetProps = {
  format: string;
  separator: string;
  labelledby: string;
  parts: BirthdatePart[];
};

export default function BirthdateFieldset({
  format,
  separator,
  labelledby,
  parts,
}: BirthdateFieldsetProps) {
  return (
    <fieldset
      aria-labelledby={labelledby}
      data-birthdate-format={format}
      className="flex min-w-0 flex-wrap items-end gap-2"
    >
      {parts.map((part, index) => (
        <span
          key={part.part}
          className="flex min-w-0 max-w-full items-end gap-2"
        >
          {index > 0 ? <span className="pb-2 text-fg-muted">{separator}</span> : null}
          <span className="flex min-w-0 flex-col gap-2">
            <label
              htmlFor={`birthdate_${part.part}`}
              className="text-base font-medium text-fg"
            >
              {part.label}
            </label>
            <span
              id={`birthdate_${part.part}_example`}
              className="text-base text-fg-muted"
            >
              {part.placeholder}
            </span>
            <input
              type="number"
              id={`birthdate_${part.part}`}
              name={`birthdate_${part.part}`}
              defaultValue={part.value}
              required
              autoComplete={`bday-${part.part}`}
              inputMode="numeric"
              min={part.min}
              max={part.max}
              placeholder={part.placeholder}
              aria-describedby={`birthdate_${part.part}_example`}
              data-birthdate-part={part.part}
              className={`${part.part === "year" ? "w-28" : "w-24"} min-h-12 max-w-full rounded-md border border-control bg-surface px-3 py-2 text-base text-fg placeholder:text-fg-muted`}
            />
          </span>
        </span>
      ))}
    </fieldset>
  );
}
