# WU-P0: Preference ADR and architecture revision proposals

- Status: **owner approved 2026-10-31; ADR revisions applied.** `docs/architecture/preference.md`,
  schema, migrations, models, controllers, and runtime behavior remain to be updated by their owning
  WUs.
- Design input: `two.md` (version 0.25) §2.1, §4, §12.7, and WU-P0 in §1.1/§3.1.
- Requirement input: `one.md` version 4.2 decisions D-50, D-54, D-55, D-56, D-57. `one.md` is not
  edited here.
- Code basis: `b6e7871073bdc43a55fc5f05e8476de8ee71252f` for the facts below; re-checked on HEAD
  `336811e5072a93c0523e484f905082635b28f48f`, which differs from the basis only in translation,
  Switch search, ADR, and compose changes plus the uncommitted WU-1 normalization change.
- No application, database, migration, or external system was run for this document.

## 1. Method

1. Read the four ADRs named in `two.md` §2.1 and the current normative replacement
   (`adr/invalid-browser-credential-recovery.md`).
2. Read `docs/architecture/preference.md` in full.
3. Confirmed each behavioral claim against the implementing code before proposing replacement text.
   Documentation is not evidence of current behavior.
4. Wrote clause-level replacement text only where the code and the D-decisions disagree; the owner
   resolved the recorded review questions on 2026-10-31.

## 2. Verified current state

| # | Fact | Source |
| --- | --- | --- |
| F-1 | The preference JWT is an RFC 9068 access token whose payload carries `public_id`, `preference_type`, `host`, `client_id`, `scope`, `nbf`, and `jti` in addition to the display `preferences` object. | `app/values/security_jwt_preference_token_codec.rb:12-35,126-149` |
| F-2 | The issuer and client id come from required configuration (`ENV.fetch("PREFERENCE_JWT_ISSUER")`, `ENV.fetch("PREFERENCE_JWT_CLIENT_ID")`); audiences derive from boot hosts. | `app/controllers/concerns/preference_jwt_configuration.rb:19-40` |
| F-3 | Credentials are host-only `__Host-` cookies: `preference_access`, `preference_refresh`, `preference_dbsc`. Display projections are per-field cookies (`ct`, `language`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, `ps`, `preference_consented`). | `app/controllers/concerns/preference_io_keys.rb:5-30` |
| F-4 | Sign-in reconciliation is already per-key with `explicit_fields` as the authority, not whole-record recency; a browser-explicit value can currently win over a principal value. | `app/controllers/concerns/preference_adoption.rb:100-197` |
| F-5 | Sign-out rotation copies only display types (`theme`…`page_size`); consent and `adult_content_gate` are deliberately excluded. | `app/controllers/concerns/preference_sign_out_rotation.rb:44-51,124` |
| F-6 | Anonymous parents carry `jti`, `used_at`, `token_digest`, `replaced_by_id`, `discard_at`/`purge_eligible_at` with `Infinity` defaults, `binding_method_id`, `dbsc_*`, and `explicit_fields`. | schema annotation in `app/models/app_preference.rb:6-43` |
| F-7 | `PreferenceClassRegistry::CHILD_RECORD_TYPES` includes `adult_content_gate` as a normal child type. | `app/controllers/concerns/preference_class_registry.rb:6-18` |
| F-8 | Actor-local tables are `client_preferences`, `operator_preferences`, and (until WU-4/5) `visitor_preferences`; the DB name in the model annotation is `app_principal`/`org_principal` while the generated structure files are `app_zenith_structure.sql`/`org_zenith_structure.sql`. | `app/models/client_preference.rb:4-6`; `db/*_structure.sql` |

## 3. Discrepancies found

Reported, not silently resolved. Each needs an owner decision or a specific WU.

| # | Discrepancy | Consequence |
| --- | --- | --- |
| D-1 | `adr/preference-relogin-reconciliation-record-recency.md` states whole-record `updated_at` recency as the accepted behavior; the code implements per-key `explicit_fields` resolution (F-4). | The ADR is already stale. Rewriting it to match the code is a correctness fix, not a design change. |
| D-2 | `docs/architecture/preference.md` says local preference lives in `app_principal`/`org_principal`/`com_principal`; the generated structure files are `app_zenith_structure.sql`/`org_zenith_structure.sql`/`com_zenith_structure.sql` (F-8). | The document must name the connection the models actually use, once, before §4.3 shapes are reviewed. |
| D-3 | `docs/architecture/preference.md` names `UserPreference`, `OperatorPreference`, `VisitorPreference` and `Preference::Adoption`; the code has `ClientPreference`, `OperatorPreference`, `VisitorPreference`, and `PreferenceAdoption` (`app/controllers/concerns/preference_adoption.rb`). | Readers will look for classes that do not exist. Local naming also contradicts `adr/app-actor-client-naming.md`. |
| D-4 | `two.md` §2.1 lists `adr/preference-credential-entry-recovery.md` as a revision candidate, but that file is already superseded by `adr/invalid-browser-credential-recovery.md`. | Revising the superseded file would recreate a second normative contract. The revisions belong in the current file. |
| D-5 | `adr/preference-browser-transport-family-capability.md` and `docs/architecture/preference.md` declare host-local, host-only preference transport; D-54/D-57 require one domain-scoped JWT plus display cookies per realm and a Base-only binding cookie. | This is a real contract reversal, not a cleanup. It needs an explicit superseding decision, not an edit of the rationale in place. |
| D-6 | `two.md` §4.5/§4.7 keep cookie consent and Web Push in the anonymous row and copy them on sign-out; the current rotation excludes consent (F-5). | WU-9 changes behavior. The "re-affirm after rotation" rationale must be explicitly retired rather than left as an undocumented reversal. |
| D-7 | `two.md` §4.4/§4.5 make account-to-anonymous application one-directional; the current code copies browser-explicit values into the principal (F-4). | WU-9 must remove a write path, so the ADR replacement has to state the direction and its rationale. |
| D-8 | The option set in `adr/preference-extended-option-reference-tables.md` includes `items_per_page: infinity`, while `two.md` §4.1 constrains cookie values to a closed allowlist and §4.2's example uses `20`. | Unresolved: whether `infinity` stays a legal wire value. Do not silently drop it, because it is a persisted user-visible value. |

## 4. ADR revision proposals

Each proposal is written as replacement text. "Apply in" is the WU allowed to change the file; this
document changes none of them.

### 4.1 `adr/preference-relogin-reconciliation-record-recency.md`

- Apply in: WU-9 (app/org), with WU-7 for the com-only variant.
- Action: supersede. Keep the file for history, mark it superseded by a new ADR, and add the new ADR
  to the `adr/README.md` index.
- Proposed new ADR: **Preference sign-in application is one-directional per explicitly saved field.**

Decision text:

> On sign-in and on an authenticated preference save, only the account's explicitly saved display
> fields are applied to the anonymous browser row. Each field is applied independently; a field the
> account never explicitly saved is not written. The anonymous row never writes to the account row,
> including when the browser holds an explicit marker and the account value is legacy or unmarked.
>
> `region` is not applied on its own. A region save stores the region together with its four fixed
> display companions (`language`, ISO date format, 24-hour time, `JPY`), and those companions are
> applied as their own explicit fields.
>
> Cookie consent and Web Push state belong to the browser row. They are neither applied from the
> account nor replaced on sign-in. On the sign-out that creates a new anonymous row, the previous
> row's consent, Web Push option, and browser binding record move to the new row inside one setting
> database transaction; the browser cookie is not converted into database state.

Consequences to record:

- Field-level provenance now exists (`explicit_fields`), so the original "no per-field metadata"
  premise no longer holds. The per-key resolution already in the code (F-4) is the base.
- The previous both-directions behavior is removed. A stale browser edit cannot overwrite an
  account value, and an account save cannot resurrect a value the browser deliberately retired.
- Regression tests must cover: account-explicit wins, anonymous-only edit not applied, legacy
  account row unchanged, region companion expansion, sign-out consent/binding copy.

Owner decision (2026-10-31): legacy account rows with `explicit_fields IS NULL` remain historical
and are read without inferred provenance; do not classify or rewrite them.

### 4.2 `adr/preference-extended-option-reference-tables.md`

- Apply in: WU-7 (com), WU-9 (app/org).
- Action: revise in place (the decision direction is unchanged) and bump the amendment date.
- Replacement clauses:

> **Registered prefixes.** Shared rows are `AppPreference`, `OrgPreference`, and `ComPreference`.
> Local rows are `ClientPreference` and `OperatorPreference`; the `visitor_*` and `user_*`/`staff_*`
> prefixes are retired with their surfaces. The registry lists exactly these five prefixes and
> raises for any other instead of deriving a class from a controller namespace.
>
> **Option names are wire values.** The reference row's `name` is the value carried in the
> preference JWT and the display cookies. No alias table and no second spelling are added. Unknown
> names, unknown keys, and duplicate cookie names are refused rather than defaulted.
>
> **New child tables.** Cookie consent receipts, browser binding records, and Web Push options live
> in the realm setting database as their own tables with `NOT NULL` columns and a unique parent
> reference (binding: unique per preference; Web Push: one enabled/disabled option row per
> preference). A missing row means "not bound"/"disabled"; no `NULL` column encodes that state.
>
> **Dormant adult gate.** `adult_content_gate` stays as a model, option table, and child table, and
> is removed from the runtime display/save registry, the JWT payload, and every controller path. It
> is not reactivated by this ADR; `adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`
> owns the age boundary.
>
> **Retired transport references.** Binding-method and DBSC status reference tables, single-use
> token state, and refresh/DBSC child state are removed from the preference parents.

Consequences: one picker list per realm; new preference types require a reference row, a child
table, a registry entry, and a migration, in that order.

Owner decisions (2026-10-31): retain `items_per_page: infinity`; Web Push uses an option reference,
not a boolean. The existing `CHECK (id IN (0, 1))` constraint remains unchanged in WU-9; adding a
future state requires a later constraint migration.

### 4.3 `adr/preference-browser-transport-family-capability.md`

- Apply in: WU-7 (com first), then WU-9. The previous ADR becomes historical; a new ADR supersedes it.
- Action: supersede rather than edit, because "transport stays host-local" is the accepted premise
  and the new contract reverses it.
- Proposed new ADR: **Preference transport is one realm-scoped signed value plus host-scoped
  browser binding.**

Decision text:

> Each realm issues one signed preference JWT on `Domain=umaxica.<realm>` and two readable display
> cookies (`language`, `__Secure-experience`) from the same database snapshot. Only the realm's Base
> and Visa surfaces hold the signing key and write database state. Every other host verifies with a
> configured realm public key and never writes, never creates a row, and never issues or deletes the
> shared cookies.
>
> Consent and Web Push are gated by a Base host-only `__Host-preference_binding` cookie whose digest
> is stored with the row. A valid signed JWT without a matching binding record yields "no consent" and
> "Web Push disabled"; it never yields authority.
>
> Browser chrome may read display values from the JWT or the display cookies. Neither is
> authentication, authorization, presence, step-up, tenant selection, or session proof.

Consequences to record:

- The family-capability registry becomes a read/write capability split: Base and Visa write; Auth,
  Core, Warp, Palm, and Edit read or render nothing. The registry row still decides whether a page
  renders controls.
- Consent is no longer asserted by a DOM cookie (`preference_consented`); the binding digest is the
  proof. Buttons on non-Base hosts link to Base instead of claiming consent.
- Cross-host delivery now depends on the domain cookie, so the previous "no CORS, no cross-origin
  fetch" property is unchanged but the credential scope is not host-local. This is the accepted
  tradeoff and must be stated, with `SameSite=Lax`, `Secure`, `HttpOnly` (JWT) and `Path=/`.
- The 400-day lifetime starts at the database write time; GET/HEAD never extends it.

Owner decisions (2026-10-31): the old JWT shape has no external reader and needs no compatibility
reader. Existing-user data migration and old-state transition measures are unnecessary because the
service has not reached alpha. The replacement ADR records the realm-scoped JWT and host-only
binding contract; production key distribution remains outside this owner decision.

### 4.4 `adr/invalid-browser-credential-recovery.md` (not the superseded entry-recovery file)

- Apply in: WU-7 (com), WU-9 (app/org).
- Action: revise in place; the current file is the normative one (D-4).
- Replacement clauses:

> **Classification.** A preference credential is refused as `missing`, `malformed`, `wrong_realm`,
> `rejected_kid`, `expired`, `not_yet_valid`, `stale_generation`, `retired_row`, or
> `unknown_row`. Signature and realm validity are checked before any database read. A store failure
> is never reported as one of these; it propagates as a dependency failure (503 on writes, defaults
> plus an error on reads).
>
> **Read paths.** A GET or HEAD with a refused credential renders defaults from the database-free
> path and does not create, rotate, extend, or repair a row. Only Base and Visa may emit deletion of
> their own invalid shared cookies; other hosts emit no `Set-Cookie`.
>
> **Write paths.** A write with a refused credential never updates the row the credential names.
> It creates a new row from the submitted explicit values and issues a new generation, or answers
> 503 if it cannot. Refused display values are never used as seeds.
>
> **Stale generation.** A correctly signed but older `jti` is displayable until `exp` and is refused
> for writes, which then follow the new-row rule. Database `jti` comparison is required only on
> write, refresh, repair, and bounded verification paths.

Consequences: the entry-detach behavior (`detached_for_entry`) no longer exists as a distinct
outcome, because an unusable display credential never blocks an entry; what remains is the
read/defaults and write/new-row split. Existing JSON `401` behavior for preference endpoints is
preserved where the endpoint is a write.

Review question: the current contract forbids a GET from deleting cookies. The new one allows
Base/Visa to delete an invalid shared cookie on GET (`two.md` §4.6). Confirm that the deletion is
scoped to the writer host and is not reintroduced for readers.

## 5. `docs/architecture/preference.md` revision map

| Section | Change | WU |
| --- | --- | --- |
| Purpose | Replace `UserPreference`/`VisitorPreference` with `ClientPreference`; state that com disappears at WU-4/5. | 3/9 |
| JWT Projection Boundary | Replace `preference_access` host-only projection with the realm JWT plus two display cookies; state that only Base/Visa sign. | 7/9 |
| URL Role Boundary | Keep `/preference` as the anonymous boundary; state that Visa OIDC continuation is a POST, not a GET write. | 9 |
| Scope | Remove com; state the three shared and two local rows (F-8 naming fixed once). | 3/7/9 |
| Synchronization Rules | Replace whole-record recency and both-direction copy with §4.1's one-directional rule; replace "keep the action successful" recovery with the explicit partial-success/503 table in `two.md` §4.8. | 9 |
| Sync failure handling | Delete the "do not expose sync failure" instruction; it conflicts with `two.md` §4.8 and with `generic/fail-fast`. | 9 |
| Data Sharing Rules | Correct database names (D-2); keep surface isolation. | 9 |
| Shared Fields | Replace with the explicit-field list plus region companions; add consent/Web Push/binding as browser-row state. | 9 |
| Promotional Email Unsubscribe | Remove com/`VisitorEmail`; confirm the app/org path survives WU-3. | 3 |
| Preference Reset | State retire-then-create in one transaction, reissue three shared cookies, delete the host-only binding cookie, and never return to the single-use/DBSC path. | 9 |
| Runtime Read Contract | Replace the claim list with `two.md` §4.2; keep "no `jti` check on read" and add "`jti` required on write". | 7/9 |
| Implementation Notes | Replace `Preference::Adoption`/`Preference::Core` names and legacy cookie names; add the single write boundary. | 7/9 |
| Remaining Follow-ups | Drop the adoption-reconciliation follow-up (resolved by the new ADR); keep the placement follow-up. | 9 |
| Open Questions | Resolve the logout question with the sign-out copy rule; retire the "sync recovery by surface" question, since one-directional application replaces it. | 9 |

The document must also gain one short section, **Write boundary**, naming the single entry point
(`two.md` §4.4) and the four operations (`save`, `sign_in`, `sign_out`, `reset`). Without it, the
architecture document cannot explain why only Base/Visa write.

## 6. Applied scope and remaining work

- The approved replacements were applied to `adr/`; the proposal does not claim that runtime code
  or schema implements them.
- `docs/architecture/preference.md`, schema, migrations, models, controllers, diagrams, tests, and
  remaining `two.md` acceptance gates are handled by their owning WUs.
- Destructive migration execution still requires a separate §12.8 ticket and owner approval.

## 7. Owner decision record

The owner approved the ADR replacement direction and resolved all recorded questions on
2026-10-31. The accepted direction removes bidirectional preference adoption and copies browser
consent, Web Push option, and binding during sign-out. It does not approve destructive database
operations, production/Neon operations, or key distribution.
