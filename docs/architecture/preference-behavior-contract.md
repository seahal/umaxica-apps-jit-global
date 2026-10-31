# Preference Behavior Contract

This document describes the current app, org, and com Preference contract. The WU-9 destructive
shape migrations have not been applied; local database cutover and final acceptance remain pending
the separately approved execution ticket.

## Ownership

| Surface | Writes | Reads |
| --- | --- | --- |
| Base app/org/com | Save and reset through `PreferenceWriteBoundary` | Realm-local anonymous preference and browser-bound consent/Web Push state |
| Visa app/org | Apply explicit actor display values after finalized sign-in; rebuild anonymous state after committed sign-out | Realm-local actor Preference and anonymous Preference row |
| Auth, Warp, Acme, Core, Edit, Tech | None | Verified anonymous Preference projection |

Interactive browser Preference controls are Base-owned. Auth, Core, and Warp can read verified
display state, but do not persist theme or consent changes. Their browser API mutation routes return
an authorization refusal and do not issue Preference cookies.

A writer receives its realm and operation through the closed surface map. Request parameters and
cookies cannot choose an account or a Preference row for persistence. A Preference JWT is a signed
read projection; it never creates database rows by itself. Browser cookies are never copied into
Preference tables.

## Anonymous JWT and browser state

The anonymous JWT carries one closed `preferences` object with theme, language, timezone, currency,
date format, time format, motion, density, and page size. It identifies its row using `sub` and its
realm using `aud`; it contains no account ID, consent, region, Web Push state, binding, or OIDC
session. The display projection uses the same database snapshot to issue the JWT, `language`, and
`__Secure-experience` cookies. The registered `infinity` page-size option is valid.

The host-only `__Host-preference_binding` cookie is issued only by Base saves that change consent or
Web Push. Its digest is stored on the matching anonymous row. Visa can copy the database binding
record during sign-out but cannot issue or alter the browser binding cookie. Consent decisions are
stored in `*_preference_cookies` with a versioned receipt child; Web Push uses an option reference,
not a boolean column.

GET and HEAD do not create or refresh Preference rows, rotate credentials, or extend cookie expiry.
An invalid or missing JWT may be followed by an explicit write that creates a new default row. An
invalid JWT does not authorize mutation of the row it names.

## Actor-local preference

`ClientPreference` and `OperatorPreference` own account-local preference state in their respective
principal databases. Display values are stored in option-backed child records. After the approved
shape cutover, `explicit_fields` is a NOT NULL list of fields that the person explicitly chose.
Unknown historical provenance is never inferred from child values; a row without a usable explicit
field list cannot contribute values to Visa sign-in.

A region save updates region plus its fixed language, date format, time format, and currency values
in the same actor write, then records those submitted fields as explicit. `adult_content_gate`
remains dormant in model/option/child tables and is absent from runtime registries and write paths.

## Visa sign-in

Visa calls `write_preference!(operation: :sign_in, ...)` only after the persisted authorization
transaction has finalized successfully. Its actor is the verified resource loaded from that
transaction. The writer reads only the matching realm's active actor Preference and applies only its
explicit display snapshot to the current anonymous row. It does not write the actor row, infer
missing actor fields, copy consent/Web Push/binding, or transfer region itself. Region's explicit
companion values may be applied independently.

If Preference persistence or token issuance fails, the completed authentication result remains
committed. The failure is logged, and the authorization code response continues without claiming
that a new Preference cookie was issued.

## Visa sign-out

After authentication logout has committed, Visa calls the same writer with
`operation: :sign_out`. In one setting-database transaction it creates a new anonymous generation,
copies the old row's display children, cookie-consent booleans, consent receipt, Web Push option, and
binding digest, and retires the old row. It reads these values from the database only. It then issues
the new shared display cookies after commit. A Preference failure does not undo the committed
authentication logout or claim successful Preference delivery.

A stale or invalid JWT does not let sign-out copy the row it names; the writer creates fresh defaults.
Retired rows cannot transition back to active. Reset also retires the current anonymous row and
creates defaults in one setting transaction, then issues the shared cookies and clears the old
host-only binding cookie.

## Failure and transaction boundaries

- Base actor saves authorize the authenticated actor and only persist submitted fields. The actor
  database write and anonymous setting write have separate database owners; a partial failure is
  reported as a failed Preference save, not as a complete save.
- Visa sign-in/out perform their Preference work after the authentication state transition. A
  Preference failure leaves the authentication result intact.
- Unknown fields, malformed JWTs, ambiguous duplicate JWT cookies, invalid option values, missing
  required child records, and cross-realm writer requests fail explicitly.
- App, org, and com use the same `PreferenceWriteBoundary` operations. Their rows, option IDs,
  binding digests, and Web Push records remain realm-local.

## Retired paths

`PreferenceAdoption`, Preference refresh tokens, Preference DBSC/assurance state, per-item cookies,
and actor consent mirrors are retired. Authentication-token refresh and DBSC remain separate
authentication mechanisms. They do not refresh or bind Preference rows.

## Acceptance state

Runtime implementation and reference documentation describe the WU-9 contract. The destructive
shape cutover and behavior acceptance are not complete until the approved local migrations run,
the app/org/com acceptance set passes against the target schema, and the single closing full-suite
comparison is recorded in `evidence/`.
