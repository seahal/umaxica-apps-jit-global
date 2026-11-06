# Visa Preference writes follow committed authentication transitions

## Status

Accepted for WU-9 on 2026-10-31 from the owner-directed implementation contract in `two.md` §3.12
and the approved Preference decisions recorded in
`evidence/2026-10-31-wu9-p0-owner-decisions-V6J3.md`.

Amended for the Experience redesign on 2026-11-04 by `five.md` C3-C4. The original WU-9 write/copy
behavior below is historical where it conflicts with this amendment.

## Amendment 2026-11-04: separate Experience ownership

Base and Visa do not copy Account Experience into Browser Experience or vice versa during
authentication transitions. Guest writes target Browser Experience; User writes target Account
Experience. Sign-in and sign-out may issue a Display Snapshot from their applicable source, but they
do not change either Experience record. A failed Experience read or cookie issuance does not undo a
committed sign-in or sign-out; the surface uses the approved fallback and Base may rebuild the
display cookies on a later request under `five.md` C4-3/C4-9/C4-10. These rules do not define the
unresolved cookie shape, expiry or recovery procedure in C5.

## Decision

Base and Visa use `PreferenceWriteBoundary` as the single Preference writer. Base owns `save` and
`reset`; Visa App and Org own `sign_in` and `sign_out`. Visa calls the writer only after the
authentication transition has committed.

On Visa sign-in, the actor comes from the authenticated, persisted Visa authorization transaction
and its realm-specific actor reference. Request parameters and Preference cookie claims never select
the actor. The writer reads the actor's explicit display snapshot and applies only those fields to
the matching anonymous Preference row. It does not write anonymous values back to the account. A
legacy actor row with unknown explicit provenance fails closed. `region` itself is not applied; a
region save marks its four fixed display companions explicit.

On Visa sign-out, the authentication logout commits first. The writer then retires the old anonymous
row and creates its replacement in one matching setting-database transaction, copying the old row's
display, consent receipt, Web Push option and browser-binding record. It reads this state from the
database; browser cookies are not converted into persisted state.

A Preference write failure is logged and does not change a committed sign-in or sign-out result.
Preference issuance cookies are emitted only after the Preference transaction succeeds.

The Base RP identity resolver remains the actor source for Base APP/ORG requests running in an RP
role. Visa is a separate IdP authorization surface and resolves its actor from the finalized Visa
transaction. `BaseZenithIdentityResolver` has no `preference_write_actor` API; Base application
controllers expose that method and call the resolver when the Base RP role requires it.

## Retired paths

`PreferenceAdoption`, Preference refresh credentials, Preference DBSC/assurance, per-item Preference
cookies and actor consent mirrors are not part of this contract. Authentication-token refresh and
DBSC remain independent authentication mechanisms. The dormant `adult_content_gate` model and its
option/child tables remain stored, but have no controller, service, policy or registry behavior.

## Consequences

- Visa authentication remains authoritative when a Preference persistence operation fails.
- APP, ORG and COM Preference state stays realm-local.
- Account-to-anonymous reflection is one-way and field-explicit.
- Local destructive schema cutover is a separate gated operation; this ADR does not authorize
  applying its migrations.

## Current continuation boundary

Visa result, cancellation and switch GETs validate their browser-bound references and render a
same-origin POST form. They do not finalize authentication, cancel a transaction, switch a ceremony,
or write Preference state. The POST goes to the realm's
`Visa::{App,Org}::Oauth::AuthorizationsController#create`, verifies the purpose-bound continuation,
and revalidates the transaction and browser binding. Rails CSRF and Origin/Fetch Metadata checks
remain required. Result continuations expire at the earlier of the parent transaction deadline or 60
seconds after issuance.

After successful Visa sign-in finalization, that POST calls the shared writer with the actor loaded
from the persisted realm-specific authorization transaction. A Preference failure leaves the root
authentication committed but returns a temporary failure without issuing an authorization code.
Silent SSO uses a separate signed continuation bound to the current session and normalized
authorization request, and applies the same writer before issuing its code. The static writer map
names the authorization POST as the sign-in caller; logout confirmation POST remains the sign-out
caller.
