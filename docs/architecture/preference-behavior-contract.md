# Preference Behavior Contract

This document records the expected behavior of Umaxica preference state across anonymous, signed-in,
signed-out, and surface-switching requests. Preferences are UX state only. They must not be used as
evidence for authentication, authorization, user presence, step-up, operator status, account
selection, organization selection, avatar selection, or access to those records.

## Inventory

| Area                         | Current implementation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Surface preference roots     | `AppPreference`, `ComPreference`, `OrgPreference`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Local actor preference roots | `ClientPreference`, `OperatorPreference`, `VisitorPreference`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Runtime read value           | `Actor::Preference`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Shared read/write concerns   | `PreferenceBase`, `PreferenceGlobal`, `PreferenceCore`, `PreferenceResourceSync`, `PreferenceAdoption`, `PreferenceWebCookieActions`, `PreferenceWebThemeActions`                                                                                                                                                                                                                                                                                                                                                                                         |
| Cookie/token helpers         | `PreferenceCookieName`, `PreferenceCookieWriter`, `PreferenceToken`, preference access/refresh token transports                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Web JSON endpoints           | Core `/api/v0/preferences/cookie` and `/api/v0/preferences/theme`; legacy `/web/v0/cookie` and `/web/v0/theme` remain on non-Core surfaces                                                                                                                                                                                                                                                                                                                                                                                                                |
| HTML preference endpoints    | Base app/com/org `/preference/*` controllers                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Tests covering this contract | `test/controllers/base/preference_authority_slice_1f_test.rb`, `test/controllers/*/*/web/v0/cookie_controller_test.rb`, `test/integration/routes/core_route_contract_test.rb`, preference concern tests, `test/integration/preference_corrupt_cookie_test.rb`, `test/integration/preference_signin_conflict_test.rb`, `test/integration/preference_logout_downgrade_test.rb`, `test/integration/preference_concurrent_sync_test.rb`, `test/integration/preference_read_symmetry_test.rb`, `test/integration/preference_get_edit_current_behavior_test.rb` |

## Authority Order

Signed-in preference writes are database-canonical. A valid database-backed preference record wins
over request parameters, request-local overlays, JavaScript-readable cookies, and client
self-reporting.

Authority order for effective UX reads:

1. Signed-in database preference for the current actor and surface.
2. Valid preference access token for the current surface.
3. Guest-safe request overlay for the current request only.
4. Guest-safe JavaScript-readable display cookie.
5. Built-in defaults.

Request overlays and JavaScript-readable cookies may affect the current rendered request, but they
must not overwrite signed-in canonical database preference records. Broken, stale, cross-surface, or
missing cookies fall back to guest-safe defaults or the signed-in database state.

## Merge Contract (per-key, not parent-record recency)

> **Supersedes**: any earlier statement in this document or an accepted memo that a signed-in
> database preference's whole-row `updated_at` (or the anonymous token row's whole-row `updated_at`)
> decides which side wins. As of the 2026-07-21 Preference lifecycle hardening pass (see
> `memos/2026-07-21-preference-lifecycle-hardening-implementation.md`), reconciliation is per-key
> (`PreferenceAdoption#reconcile_preference_key!`,
> `app/controllers/concerns/preference_adoption.rb`), driven by the `explicit_fields` marker on each
> side, not by comparing whole-record timestamps. A change to one field on one side never silently
> drags unrelated fields along with it.

Each of `PreferenceClassRegistry::CHILD_RECORD_TYPES` (language, timezone, region, theme, currency,
date_format, time_format, motion, density, page_size, adult_content_gate) is resolved independently:

| Browser state               | Principal state                                   | Winner                                                                                             |
| --------------------------- | ------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| explicit                    | known, non-explicit                               | Browser                                                                                            |
| non-explicit (default/seed) | explicit                                          | Principal                                                                                          |
| explicit                    | explicit                                          | The more recently touched _child record_ wins (see "Best-effort timestamp" below); tie → principal |
| non-explicit                | non-explicit                                      | Principal (unchanged default; no divergent browser edit to prefer)                                 |
| any                         | **legacy** (`explicit_fields` column is SQL NULL) | Principal always wins -- see "Legacy compatibility" below                                          |

The losing side is written to match the winner's value _and_ its explicit flag, so both records
converge to the same value and the same explicit state; a side is never marked explicit for a value
it did not itself choose.

### Explicit semantics

"Explicit" means the user (or an equivalent server action acting on their behalf, e.g. signup
default seeding is the opposite) performed an action that specifically set this key. It is tracked
per preference row in the `explicit_fields` jsonb column
(`app/models/concerns/preference_explicit_fields.rb`), present on both the token-scoped
(`AppPreference`/`ComPreference`/`OrgPreference`) and principal-scoped
(`ClientPreference`/`OperatorPreference`/`VisitorPreference`) models.

- Automatic default generation (new row, or `create_resource_preference_options!` at signup) →
  non-explicit.
- `PreferenceSignOutRotation`'s safe-copy seed at sign-out → non-explicit (browser continuity, not
  user intent).
- User selects a non-default value → explicit.
- User explicitly re-selects the default value → still explicit. Explicitness is never inferred from
  "does this value differ from the default."
- A full preference reset clears `explicit_fields` back to `[]`.
- `explicit_fields` is server-controlled only: it is written exclusively by
  `mark_field_explicit!`/`clear_explicit_fields!`/`sync_explicit_state!` from within these concerns,
  never accepted from client-submitted params (see the Strong Params allowlist in
  `preference_core.rb`, which does not include `explicit_fields` or any internal timestamp).

### Legacy compatibility (`explicit_fields` IS NULL)

The mirror-side `explicit_fields` column was added by an _additive, non-backfilling_ migration
(`db/app_zenith_migrate/20260721090000_add_explicit_fields_to_client_preferences.rb` and its org/com
siblings): `add_column` with no default, so every row that existed before the migration keeps
`explicit_fields = NULL`; `change_column_default` only affects rows created afterward. This is
deliberate -- there is no way to know, after the fact, which of an existing account's already-
diverged field values were genuinely user-chosen, and backfilling either `[]` (claims "never
chosen," possibly false) or a populated list (claims "chosen," fabricated) would misrepresent
history either way. NULL is the only value that does not lie.

Three states, not two:

| `explicit_fields` value | Meaning                                                                       |
| ----------------------- | ----------------------------------------------------------------------------- |
| `NULL`                  | Legacy: provenance genuinely unknown (pre-migration row, never touched since) |
| `[]`                    | Known: nothing has been explicitly chosen on this row                         |
| `["language", ...]`     | Known: these specific fields were explicitly chosen                           |

`PreferenceExplicitFields#legacy_unknown_explicit_state?` exposes this. A legacy principal row
always wins reconciliation, regardless of the browser side's explicit state, so an unrelated
browser's explicit marker can never silently overwrite an established-but-provenance-unknown value.
The row stays legacy until a genuine user action on that account (a dual-write mark or an explicit
reset) transitions it to a concrete array.

### Best-effort timestamp, not strict causal order

When both sides are explicit for the same key, the tie-break compares each side's _child record's_
own `updated_at` (e.g. `AppPreferenceLanguage#updated_at` vs.
`ClientPreferenceLanguage#updated_at`), not the parent row's `updated_at`. These child timestamps
live in separate physical databases with no shared clock guarantee and no version/sequence counter.
**They provide deterministic best-effort recency for a single low-sensitivity display key, not a
strict causal order across physical databases or application nodes.** This is an accepted trade-off
for UX-only fields; it must not be relied on for anything security- or audit-relevant. A tie
(including any ambiguity) resolves to the principal.

## Anonymous-to-signed-in merge (legacy list, superseded by the per-key table above)

Anonymous state may be adopted into signed-in state only for guest-safe UX fields:

| Field                             | Anonymous to signed-in merge         | Reason                                    |
| --------------------------------- | ------------------------------------ | ----------------------------------------- |
| Language                          | Allowed                              | UX display preference                     |
| Timezone                          | Allowed                              | UX display preference                     |
| Theme                             | Allowed                              | UX display preference                     |
| Cookie banner display suppression | Allowed                              | Display helper only                       |
| Display region                    | Allowed only as a UX/display setting | Must not imply authorization or residency |

The following fields must never be overwritten from client-side anonymous state:

| Field class                                                                 | Merge rule |
| --------------------------------------------------------------------------- | ---------- |
| Account, organization, avatar, operator, member, admin, or staff context    | Forbidden  |
| Security preferences, step-up state, verification state, DBSC binding state | Forbidden  |
| Consent audit evidence or legal consent record                              | Forbidden  |
| Authorization, entitlement, user presence, or session state                 | Forbidden  |

## Surface Matrix

| Surface | Model authority                                           | Web cookie endpoint                                          | Theme endpoint                                             | HTML preference update   | Notes                             |
| ------- | --------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------- | ------------------------ | --------------------------------- |
| app     | `AppPreference` plus actor-local app preference records   | Core `/api/v0/preferences/cookie`; non-Core `/web/v0/cookie` | Core `/api/v0/preferences/theme`; non-Core `/web/v0/theme` | Base app `/preference/*` | End-user UX only                  |
| com     | `ComPreference` plus visitor/corporate preference records | Core `/api/v0/preferences/cookie`; non-Core `/web/v0/cookie` | Core `/api/v0/preferences/theme`; non-Core `/web/v0/theme` | Base com `/preference/*` | Public/corporate UX only          |
| org     | `OrgPreference` plus operator/staff preference records    | Core `/api/v0/preferences/cookie`; non-Core `/web/v0/cookie` | Core `/api/v0/preferences/theme`; non-Core `/web/v0/theme` | Base org `/preference/*` | Staff UX only; not operator proof |

`base` owns OP, Authorization Server protocol routes, identity authority, and the browser preference
HTML authority. `auth` owns credential ceremony and sign-related relying-party UI. `core` owns the
Rails browser API/BFF boundary. The cookie and theme JSON endpoints remain in `/web/v0` on each
surface.

Com-tier `ApplicationController` classes that include visitor authentication and can recreate a
`ComPreference` must also include `PreferenceAdoption`, matching the app/org tiers. Without that
include parity, preference refresh-cookie bootstrap can recreate the surface preference without
synchronizing the `VisitorPreference` mirror.

## State Transitions

| State                                       | Expected behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Anonymous without cookie                    | Use defaults. Core `/api/v0/preferences/cookie` (and the legacy non-Core `/web/v0/cookie`) returns `show_banner: true` or `false` as a boolean.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Anonymous with valid preference cookie      | Use only guest-safe values from the current-surface token/cookie.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Anonymous with invalid or stale cookie      | Ignore the broken value and fall back to guest-safe defaults; do not raise to the user.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Login with existing DB preference           | DB preference remains canonical; anonymous self-report cannot overwrite it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Login without DB preference                 | Create or load the surface preference through the existing preference adoption/sync path; only guest-safe fields may be adopted.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Login with conflicting anonymous preference | DB canonical fields win. Only allowed guest-safe fields may be merged by an explicit sync path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Signed-in update                            | Update allowlisted preference fields only, refresh the preference token, and keep authorization/CSRF protections.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Logout                                      | **Superseded 2026-07-21** (see `memos/2026-07-21-preference-lifecycle-hardening-implementation.md` and "Sign-out credential rotation" below): the 2026-07-02 "keep-values, never rebootstrap" decision is replaced. `AuthenticationLogoutable#logout_current_session!`/`logout_all_sessions_for!` now call `PreferenceSignOutRotation#rotate_preference_after_sign_out!`, which retires the token-side preference row server-side and issues a _new_ guest preference row seeded from a safe-copy allowlist. The net UX effect for the returning guest is the same as before (display values like language/theme carry forward), but the mechanism changed from "never touch the row" to "rotate to a fresh row, copy only safe values as a non-explicit seed." Auth/session state (session cookie, refresh/access token cookies) is deleted as before. Account/org/avatar/operator context is never stored in the preference cookie or token in the first place (see Merge Contract), so there is no such state to downgrade. |
| Logged-out revisit                          | Render from the guest-safe token-side preference (language/timezone/theme/cookie-banner state); no account/org/avatar/operator context is present to leak because it was never written there.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| app/com/org surface change                  | Surface-specific preference token and model must be used. Cross-surface cookies must not become canonical.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

## Cookie Consent

Core `GET /api/v0/preferences/cookie` and legacy non-Core `GET /web/v0/cookie` return a JSON object
containing only a boolean banner decision: `show_banner: true` or `show_banner: false`.

Core `PATCH /api/v0/preferences/cookie` and legacy non-Core `PATCH /web/v0/cookie` perform the
update side effect and return `204 No Content` on success. A JavaScript-visible
`preference_consented` cookie is a display helper for banner suppression. It is not legal consent
evidence, not authorization evidence, and not a security signal. Consent that needs audit or legal
retention must be stored in a durable database or event/audit record with an explicit owner and
retention policy.

`show_banner?` (`PreferenceWebCookieEndpoint`) derives the flag from the current
`cookie_consent_state`: it is `true` until a `consented` choice has been recorded, and `false` once
it has. It must not be hardcoded to a single value on either surface. The removed
`PreferenceBase#show_cookie_banner?` helper is not part of the banner contract; the web cookie
endpoint is the canonical banner decision path.

## Security Negative Cases

Regression coverage should include:

| Case                                      | Expected result                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CSRF on preference-changing requests      | Rejected by the normal Rails protections.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| GET mutation                              | No preference database state changes. `*_preferences_edit` actions (region/language/timezone/theme) never create a missing child row; they render an unpersisted default in-memory value instead (`load_or_build_preference_child`). Every `CHILD_RECORD_TYPES` child row is created once, at preference bootstrap (`create_new_preference_record!` → `create_preference_options`), which is a legitimate write point, not a read.                                                                                                                             |
| Request parameter tampering               | Invalid or unexpected values are ignored or rejected by allowlists.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Cookie tampering                          | Broken preference cookies do not overwrite DB state. A presented-but-invalid refresh token (garbage value, or a token from a different surface's preference table) fails closed with `401` and clears the stale cookie; it never resolves to, adopts, or mutates an unrelated existing preference row. A refresh cookie that was simply never presented still bootstraps a fresh guest preference normally.                                                                                                                                                    |
| Stale cookie replay                       | Stale anonymous state does not beat signed-in DB canonical state.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Cross-surface cookie confusion            | app/com/org preference tokens remain surface-specific.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Host confusion                            | Current host selects the current surface; cookies do not switch authority.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Logged-out previous-user leakage          | Previous user context is not visible after logout.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Anonymous cookie overriding DB preference | Forbidden and covered by regression tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Mass assignment                           | Unexpected keys and nested params are not accepted as preference writes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Invalid enum or option value              | Rejected or normalized through the option table/allowlist.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Race during login sync                    | Unique constraints and explicit sync paths prevent duplicate canonical preferences.                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Parallel PATCH updates                    | Last valid write may win, but writes must remain scoped and authorized.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Missing authorization on signed-in update | Rejected by the normal controller/policy pipeline.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Cache leakage                             | Effective preferences must not be cached across users or surfaces.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Cross-surface before_action parity        | The app/com/org `edge/v0/cookies` controllers must skip the same before_actions that are actually defined on their respective surface `ApplicationController` (e.g. `transparent_refresh_access_token`); a missing skip on one surface can trigger a token-refresh side effect on this otherwise side-effect-free JSON endpoint. Skips for callbacks that a surface's `ApplicationController` never defines (e.g. `enforce_withdrawal_gate!` on org, which has no staff withdrawal concept) are intentionally surface-specific and are not a parity violation. |

## Sign-out credential rotation

`app/controllers/concerns/preference_sign_out_rotation.rb`, included on all three surfaces via
`PreferenceGlobal`, and wired into both `AuthenticationLogoutable#logout_current_session!` and
`#logout_all_sessions_for!` (`app/controllers/concerns/authentication_logoutable.rb`).

Sequence (steps 1-3 run inside one DB transaction; step 4, cookie issuance, is a non-transactional
side effect that necessarily comes after):

1. Snapshot the current (about-to-be-abandoned) token-scoped preference's safe display values.
2. Create a new guest preference row (fresh `jti`, fresh refresh token, default consent/adult-gate
   state) via `PreferenceRefreshTokenTransport#persist_new_preference_record!`, without issuing
   response cookies or headers.
3. Seed only the safe-copy allowlist onto the new row, marked non-explicit (browser continuity seed,
   not the new guest's own choice), and retire the old row server-side (`used_at`/`discarded_at` set
   to now).
4. After the transaction commits, issue the new refresh cookie, any DBSC cookie and registration
   header, and the new access-token cookie.

### Safe-copy allowlist

`theme`, `language`, `timezone`, `region`, `currency`, `date_format`, `time_format`, `motion`,
`density`, `page_size`. Excluded: `adult_content_gate` (server/age-policy authority, never
client-copied) and cookie consent (not carried across an identity rotation; the new guest re-affirms
it, banner shows again).

### Token retirement guarantees

- Old row: `used_at` set (fails `SingleUseToken#replay?`'s "unused" check going forward) and
  `discarded_at` set to now (falls out of the `active` scope). Both the refresh path
  (`PreferenceBase#valid_refresh_preference?`, which every DBSC verification/refresh request also
  goes through via `load_preference_record_from_refresh_token!`) and the access-token path
  (`PreferenceAccessTokenTransport#load_access_token_preference_record!`, scoped to
  `preference_class.active.unconsumed`) reject a retired row.
- **DBSC**: traced end to end (registration and bound-cookie-refresh both resolve their record via
  `PreferenceDbscRegistrationEndpoint#current_preference_record` →
  `load_preference_record_from_refresh_token!` → `valid_refresh_preference?`); no separate DBSC
  lookup bypasses this gate, so a retired row's still-`ACTIVE` `dbsc_status_id`/`dbsc_session_id`
  cannot be used to authenticate a bound-cookie refresh. See
  `test/controllers/concerns/preference_dbsc_retirement_test.rb`.
- **Access JWT**: fixed 2026-07-21. `load_access_token_preference_record!` previously resolved a
  presented JWT's `public_id` with a bare `find_by`, ignoring `discarded_at`/`used_at`. Because
  `PREFERENCE_JWT_TTL` is 7 days (`app/values/security_token_lifetimes.rb`), a still-unexpired
  access JWT issued before sign-out kept resolving to the retired row for up to 7 days -- the
  DB-side retirement existed but was not enforced at the verification layer. Now scoped to
  `.active.unconsumed`. See `test/controllers/concerns/preference_access_token_transport_test.rb`.
- Failure handling: `preference.sign_out.retirement_failed` (`:error`, tagged with a `stage`:
  `new_identity_creation`/`safe_value_seed`/`old_credential_retirement`) for any failure inside the
  transaction -- the transaction rolls back completely, so the old credential is left exactly as
  valid as before the sign-out attempt, never in a partially-rotated state.
  `preference.sign_out.cookie_issuance_failed` (`:warn`) for a failure purely in cookie issuance,
  after the DB-side rotation already committed. Neither event logs a raw token, digest, cookie
  value, or PII -- only the preference row's own opaque `public_id`. Auth logout itself is never
  blocked by any failure in this path.

### All-session ("sign out everywhere") logout

`logout_all_sessions_for!` rotates the _current request's_ browser-scoped preference credential the
same way. It does not and cannot retire a _different_ browser's Preference credential: there is no
server-side mechanism to push a new cookie into a browser that isn't making the current request, and
Preference tokens are not enumerable per-account (they are looked up by opaque `public_id`/refresh
digest carried in a cookie, not by a resource foreign key). This is an accepted limitation, not a
gap: `AuthenticationLogoutAllSessions` revokes every _auth_ session for the resource, so a remote
device's next authenticated request fails auth regardless of its Preference cookie state, and
Preference is never an authentication/authorization authority (see the opening paragraph of this
document) -- an un-retired remote Preference credential can still resolve display preferences for
that device but cannot grant access to the account.

### Consent policy version (deferred)

`reconcile_cookie_consent!` currently uses a simple "more recent `consented_at` wins" rule and does
**not** compare a `consent_version` across sides. A stricter contract (copy the full
`{booleans, consented_at, consent_version}` tuple only when versions match; otherwise reset and
re-show the banner) was considered and deliberately **not implemented**: the repository has no
mechanism today that can identify an individual across the anonymous/global document-delivery
surface (`info`) to know which policy version they last saw, so there is no safe, non-fabricated
source of truth for "did the policy change since this consent was recorded" yet. This is
intentionally deferred until the global doc-delivery/versioning mechanism in `info` exists as its
own project. Revisit this section once that mechanism ships.

## Performance characteristics (measured, not estimated)

Measured with `ActiveSupport::Notifications.subscribe("sql.active_record")` against real DB rows
(see `test/controllers/concerns/preference_dual_write_query_count_test.rb`,
`test/controllers/concerns/preference/adoption_test.rb`-style contexts in
`memos/2026-07-21-preference-lifecycle-hardening-implementation.md` sections 9.5 and 10.1 for full
methodology). All flows are bounded by `PreferenceClassRegistry::CHILD_RECORD_TYPES` (11 fixed
types), not by user data volume -- none of these are classic unbounded N+1s, but per-key correctness
(reading both sides per key) costs more reads than the old whole-record-winner approach would have.

| Flow                                                                                    | Measured SQL statements | Surface(s) measured                                                                                                   |
| --------------------------------------------------------------------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Local sign-out rotation (`PreferenceSignOutRotation#rotate_preference_after_sign_out!`) | 25                      | app (same shared Concern on com/org, no surface branching)                                                            |
| Sign-up initialization (`adopt_preference_for!` against a brand-new principal row)      | 91                      | app (same shared Concern on com/org)                                                                                  |
| Sign-in reconciliation (`sync_preferences!` against an existing principal row)          | 3                       | app (same shared Concern on com/org)                                                                                  |
| Signed-in dual-write, single key (`update_preference_child_dual_write!`)                | 31 (24 reads, 7 writes) | app (same shared Concern on com/org; correctness re-verified per surface in `preference_dual_write_contract_test.rb`) |

Building the dual-write measurement harness surfaced and fixed a real bug:
`PreferenceResourceSync#resource_preference_association_prefix` returned an association name
(`"client_preference"`/`"operator_preference"`) that did not match any real `has_one` association on
`ClientPreference`/`OperatorPreference` (the real names are
`user_preference_*`/`staff_preference_*`). This silently no-opped the principal-side per-key child
option write on app/org (flat string columns still updated via a separate, unaffected code path; com
was unaffected because its real prefix happens to equal the guessed one). Fixed 2026-07-21; see the
file for the full comment.

No caching, async writes, an outbox, or other new infrastructure was added to reduce any of these
counts -- per repository direction, only measurement and a narrow correctness fix were in scope. A
few single-row primary-key lookups are fetched twice within the dual-write path (documented in the
memo, not fixed: the fix would need to thread a value across separate method boundaries, which was
judged riskier than the marginal cost of two extra PK SELECTs).

## Maintainability Rules

Preference read, write, merge, cookie update, and logout downgrade behavior must stay in shared
concerns/services or model-level contracts, not copied into surface controllers. Controller logic
should remain HTTP-oriented.

When a surface's `before_action`/`skip_before_action` set on a shared concern-including controller
(e.g. `edge/v0/cookies`) differs from its sibling surfaces, the difference must be explained by a
callback that genuinely does not exist on that surface's `ApplicationController` (verify before
assuming parity — `skip_before_action` on an undefined callback raises `ArgumentError` at boot).
Otherwise treat the divergence as a defect and bring the surfaces back in line.

When a new preference field is added, update:

1. The relevant model and option/reference table.
2. The read/write allowlist.
3. Anonymous-to-signed-in merge policy.
4. Logout downgrade policy.
5. Contract or regression tests for DB canonical versus cookie/request state.
6. This document when the field changes the behavior contract.

`persist_self_replacement` (the post-create self-referential `replaced_by_id` backfill on
`AppPreference`/`ComPreference`/`OrgPreference`) must stay implemented the same way across all three
models (`update_column`, skipping validation, since it only backfills a self-reference immediately
after a validated create). `app_preferences.status_id`'s column default must stay aligned with the
model's Ruby-level `attribute :status_id, default: AppPreferenceStatus::NOTHING` (both `0`); a
mismatch only matters for raw SQL inserts that bypass Active Record defaults, but is a real drift
that should not reappear.
