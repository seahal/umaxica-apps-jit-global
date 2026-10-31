# Preference sign-in application is one-directional per explicitly saved field

## Status

Accepted on 2026-10-31 by the owner. This decision replaces
[`preference-relogin-reconciliation-record-recency.md`](preference-relogin-reconciliation-record-recency.md)
and applies to WU-7's COM implementation and WU-9's APP/ORG implementation.

## Decision

On sign-in and authenticated preference save, explicitly saved account display fields may be applied
to the anonymous browser preference row. Each field is handled independently, and a field the
account has not explicitly saved is not written. The anonymous row never writes into the account
row. In particular, an anonymous browser's explicit marker cannot overwrite an account value or
classify an account row whose legacy `explicit_fields` value is `NULL`.

`region` is not applied by itself. Saving a region stores it with the four fixed display companions
(`language`, ISO date format, 24-hour time, and `JPY`). Those companions are applied only when their
own explicit state authorizes them.

Cookie consent and Web Push belong to the anonymous browser row. They are not read from or applied
from an account row, and they are not replaced on sign-in. On sign-out, when a new anonymous row is
created, the prior row's consent, Web Push option, and browser-binding record are copied to the new
row in one setting-database transaction. The binding cookie is not converted into database state.

## Consequences

- Sign-in and authenticated save are one-way from account to anonymous state. Anonymous display
  edits never update account state.
- Legacy account rows with `explicit_fields = NULL` remain historical, read-only data. The writer
  does not infer provenance from their child values or rewrite those rows. If such a row reaches the
  explicit-display projection before cutover, it fails closed without contributing values.
- Regression coverage includes account-explicit application, anonymous-only edits, legacy rows,
  fixed region companions, and sign-out consent/binding copy.
