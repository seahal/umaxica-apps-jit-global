# Unified Enforcement

## Status

Accepted (2026-07-27)

## Supersedes

This ADR supersedes `adr/authentication-method-lock.md`. That ADR is marked `Status: Superseded` and
left otherwise unedited so the 2026-07-26 decision trail stays legible. Nothing in that ADR's
audit-contract vocabulary (reused reason codes, operator attribution, sanitized metadata) is
rejected here; its storage design (per-`(principal, method)` lock as its own SSOT) is replaced by
the Enforcement Case model below.

`adr/administrative-access-lock.md` is not superseded. Its runtime contract for `admin_locked` is
unchanged; this ADR only adds a caller.

## Context

Two mechanisms were designed separately: Authentication Method Lock (accepted, unimplemented) and
Identity BAN / Identity Freeze (named as "a later phase," never specified). Building them
independently duplicates effective date, expiry, indefinite/permanent disposition, visible/hidden,
reason code, operator attribution, approval, release, break-glass, appeal, audit, `app`/`com`/`org`
separation, deletion protection, retention/erasure interaction, an operator console, and a test
harness.

This ADR replaces both with one substrate — **Unified Enforcement** — while keeping the three effect
kinds (account-wide access, one authentication method, one identifier value) as distinct,
independently-combinable rows rather than collapsing them into a single state or boolean.

A read-only audit preceded this decision (recorded as `plans/active/...` audit history and the
Decision Log below) and found that the superseded ADR contains three factual errors about the
repository: it claims a session-attribution column exists that does not, claims credential foreign
keys cascade on delete when none do, and miscounts the orphaned trigger functions. These are
corrected here and in `adr/database-trigger-usage-boundary.md`.

## Goals

- One Enforcement Case model expressing why, how long, how visible, and how releasable an action is,
  shared across all three effect kinds.
- Principal Effect, Authentication Method Effect, and Identifier Effect as separate, independently
  combinable rows — never one state or boolean.
- `app` / `com` / `org` realm isolation at storage, effect application, identifier matching, and
  authorization.
- No new Service, Command, Interactor, UseCase, Operation, Workflow, Manager, Handler, Query, or
  Form class. `ActiveSupport::Concern`, models, controllers, policies, jobs, migrations, DB
  constraints, and (narrowly) triggers only.
- Preserve `admin_locked` as the sole runtime access gate; Unified Enforcement is a caller of it,
  not a replacement for it.
- Preserve normal withdrawal, privacy erasure, and retention as separate mechanisms from
  enforcement.

## Non-goals

- AAL downgrade machinery.
- A minimum-one-AAL1-method guarantee for `Client` or `Visitor` (rejected per the decision below; it
  does apply to `Operator`).
- A dedicated enforcement database, or any cross-database projection/reconciliation layer for
  Enforcement Case storage (rejected; see Database placement).
- Google/Apple permanent method freeze in v1 (deferred to the common-storage cutover).
- Content moderation, profile content visibility beyond the existing `ClientVisibility` catalog, or
  Avatar-level suspension.
- A fixed appeal filing deadline.

## Terminology

- **Enforcement Case** — the policy record: kind, state, duration mode, visibility, release mode,
  reason, attribution, approval.
- **Principal Effect** — the Case's account-wide runtime consequence, applied by calling
  `AdministrativeAccessLock`, never a duplicate state.
- **Authentication Method Effect** — the Case's consequence for one `(principal, method)` pair.
- **Identifier Effect** — the Case's consequence for one identifier value (email, telephone,
  Google/Apple `issuer`+`subject`), independent of any surviving principal row.
- **Principal Link** — a Case's association with a target, former, related, suspected-duplicate,
  reinstated, or false-positive principal.
- **In force** — an effect's runtime-evaluated state; see Duration and expiry.
- **Realm** — `app`, `com`, or `org`.

## Existing implementation audit

Full findings are in the Phase 1/2/3/4 sections of the working audit (retained in git history of
this ADR's authoring session). Load-bearing facts:

- `AdministrativeAccessLockable` (`app/models/concerns/administrative_access_lockable.rb`) and
  `AdministrativeAccessLock` (`app/services/administrative_access_lock.rb`) are implemented,
  service-only, with no controller, route, or policy. Runtime enforcement is wired into
  `palm_access_token_authenticator.rb:47-49`, `oidc_access_token_authenticator.rb:44-46`, and
  `authentication_current_resource_resolver.rb:286-301`.
- `established_authentication_method` does not exist anywhere in the repository outside the
  superseded ADR's own prose (one string match, in that file).
- No credential table has an `ON DELETE CASCADE` foreign key. `app_zenith_structure.sql` has six
  CASCADE constraints and none targets a credential table.
- Zero `CREATE TRIGGER` statements exist anywhere in the repository. Five (not eight) orphaned
  trigger functions exist under `db/app_principals_migrate/`.
- Session revocation (`AuthenticationSessionRevoker`, `AccountSessionRevocation`) is all-or-nothing
  per account; there is no method-scoped filter.
- `establish_signed_in_session!` (`authentication_base.rb:2324`) is called both through the
  `AuthenticationSessionCommitter` seam and directly from
  `sign_up_sequence_controller_support.rb:596,728`, bypassing the seam for telephone-OTP and TOTP
  finalize.
- `establish_signed_in_session!` already accepts `auth_method:`, but its value set (`"email"`,
  `"passkey"`, `"secret_credential"`, `"entra_id"`, `"social"`, plus several flow-type markers and
  `nil`) cannot serve as a Method Effect key — `"social"` does not distinguish `google` from
  `apple`.
- `normalize_amr` (`authentication_base.rb:2240-2249`) derives `amr` from token kind, not from a
  recorded establishing method, and returns `[]` for telephone OTP, TOTP, and Entra.
- `IdentifierBlindIndex` (`app/services/identifier_blind_index.rb`) is keyed HMAC-SHA256 with no
  key-version or digest-version column; `adr/identifier-hmac-emergency-rotation.md` deliberately
  rejected versioned columns because of a uniqueness-index conflict that does not apply to
  Identifier Effect rows (see Identifier normalization).
- `AccountAccessEvent` (chronicle DB) has NOT NULL, two-valued `previous_access_state` /
  `next_access_state` columns and cannot carry enforcement event types without a schema change, and
  already carries a cross-DB `account_id :bigint` that must not be repeated.
- `ClientTotpCredential` and `ClientExternalIdentity` have neither `discarded_at` nor `purged_at`
  and are absent from `RetentionPurgeJob::RETAINABLE_MODELS`; `ClientExternalIdentity` is being
  actively rewritten in the working tree behind a `IdentityRepositoryFactory.common_storage?`
  runtime branch.
- `clients.visibility_id` → `ClientVisibility` (`NOTHING/USER/STAFF/BOTH`) is an existing, reusable
  profile-visibility mechanism.
- A per-subject retention hold mechanism already blocks purge
  (`docs/security/withdrawal-privacy-erasure.md`), and occurrence rows are already documented as
  history-only, never current-state source of truth.
- `.agents/harnesses/rules/project/value-object-boundaries.mdc` sanctions a Service class as a last
  resort for exactly the multi-aggregate/multi-DB coordination this feature needs; the
  no-new-Service constraint given for this work is stricter than the repository's own rule.
- `.agents/harnesses/rules/generic/routing.mdc` forbids `ban` and `approve` as controller actions;
  every operator control must be a noun resource.
- `.agents/harnesses/rules/generic/testing.mdc` forbids test helper methods; shared test structure
  must be duplicated explicit tests, not helpers.

## Prior plan review

The superseded ADR's storage design (per-`(principal, method)` lock table as its own SSOT) and its
claim that Identity Freeze would occupy "disjoint tables, names, and responsibilities" are both
reversed by this decision. Its runtime contract — mode taxonomy (`change_locked` / `unusable` /
`permanently_frozen`), method-scoped session revocation, hidden-freeze response discipline,
break-glass-only permanent-freeze release, and operator lockout prevention — is retained and
absorbed into Authentication Method Effect. Its two factual claims about session attribution and FK
cascades are withdrawn; the trigger justification is narrowed accordingly (see Trigger design).

## External platform policy comparison

Fetched 2026-07-27. `help.x.com` and `support.reddithelp.com` returned HTTP 403 to direct fetch; X
entries below are search-snippet level and marked as such. Nothing here is used to justify any
internal storage or matching design — no platform publishes that.

| Source                                                                              | Confirmed from official documentation                                                                                                                                                                                                                                                                                                                                                                                       |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mastodon, `docs.joinmastodon.org/admin/moderation/`                                 | Four independently applicable actions: Sensitive (auto-flag media), **Freeze** ("prevents the user from doing anything with the account, but all of the content is still there untouched," reversible, local), **Limit** (hidden from public view except existing followers, content still reachable by search/mention/follow), **Suspend** (public removal, 30-day admin-side reinstatement window, then permanent purge). |
| Meta, `transparency.meta.com/en-gb/enforcement/taking-action/restricting-accounts/` | Graduated strike ladder: 1 = warning, 2-6 = time-limited feature restriction, 7/8/9/10+ = 1/3/7/30-day creation restriction; severe violations get longer restrictions from strike 1; in-app appeal; no published post-disabling account policy or appeal deadline.                                                                                                                                                         |
| Bluesky, `bsky.social/about/support/community-guidelines`                           | Enforcement described only as "restrictions or removal"; explicit ban-evasion prohibition ("do not create new accounts... to evade bans, suspensions, or other enforcement actions"); appeals exist, procedure deferred to ToS.                                                                                                                                                                                             |
| X, help.x.com (snippet-level, direct fetch 403)                                     | Temporary disabling vs. permanent suspension; permanent suspension removes the account from view and the violator "will not be allowed to create new accounts"; appeals available including for permanent suspension. Unverified against primary source.                                                                                                                                                                    |

Umaxica design decisions informed by this comparison, each marked as inference beyond the source:

- Freeze / Limit / Suspend as orthogonal, independently combinable effects (Confirmed pattern at
  Mastodon) — directly supports keeping Principal Effect, Method Effect, and Identifier Effect
  separate rather than one severity scale.
- Delayed-purge reinstatement rather than immediate anonymization on permanent action (Confirmed
  pattern at Mastodon's 30-day window) — informs rejecting immediate anonymization on permanent
  method freeze (Umaxica design decision, not derived from a specific numeric window).
- Ban-evasion / identifier-reuse prohibition as a published policy commitment (Confirmed at Bluesky,
  snippet-level at X) — supports Identifier Effect's purpose; the matching mechanism itself is pure
  Umaxica design (Inference/Unknown for all sources — no platform publishes identifier-matching
  internals).
- No appeal filing deadline (Confirmed absence at Meta, Bluesky; unverified at X) — Umaxica design
  decision to ship without one in v1.
- Hidden enforcement response discipline — Unknown/no precedent at any source examined; entirely a
  Umaxica design decision, stated as such in Visibility below.

## Realm isolation

Enforcement Case, every Effect table, and Principal Link are created independently in each of
`app_zenith`, `com_zenith`, `org_zenith` (see Database placement). No enforcement table crosses a
realm boundary at any layer:

- **Storage** — three independent table sets, no shared enforcement database.
- **Application** — `EnforcementCase#apply!` only ever operates within its own realm's models.
- **Identifier matching** — each realm holds its own HMAC key (see Identifier normalization); an
  `app` digest is not computable with the `com` key.
- **Authorization** — enforcement permissions are realm-scoped
  (`enforcement.app.apply_permanent_ban` is a distinct grant from
  `enforcement.com.apply_permanent_ban`); the org policy scopes reads by realm. This closes a gap in
  the current `AdministrativeAccessLock`, which accepts any `Operator` against any of `Client`,
  `Visitor`, `Operator` with no realm dimension, and satisfies
  `.agents/harnesses/rules/project/surfaces.mdc`'s requirement that surface independence hold at
  "request handling, authorization, and persistence layers."

The `Operator` population itself stays unified in `org` — creating app/com-resident operator classes
was considered and rejected as out of scope and contrary to the org-as-control-plane architecture.
Realm isolation is a property of what an operator is authorized to touch, not of where operators
live.

## Unified Enforcement boundary

```text
Enforcement Case
├─ Principal Effect            (drives admin_locked; never a parallel access state)
├─ Authentication Method Effect
├─ Identifier Effect
├─ Principal Link
├─ Approval (columns on the Case)
├─ Appeal (separate ceremony, references the Case)
└─ Audit Event (chronicle DB, separate table)
```

Distinct from, and not touched by, this boundary:

- **Normal withdrawal / deactivation / reactivation window / privacy erasure / retention / purge /
  anonymization** — unchanged self-service lifecycle machinery.
- **`admin_locked`** — unchanged runtime access gate; Unified Enforcement calls it, never duplicates
  or widens its state.

## Enforcement taxonomy

Five kinds: `security_lock`, `cooldown`, `temporary_freeze`, `permanent_ban`, `method_protection`.
Effects are first-class stored rows; `kind` restricts which combinations are legal via CHECK
constraints and a cross-column model validation in the shape
`app/models/concerns/administrative_access_lockable.rb:55-71` already uses — not derived from `kind`
at read time. Storing rather than deriving keeps a Case's meaning stable across schema evolution,
including while under appeal.

| Rule                                                                                                       |
| ---------------------------------------------------------------------------------------------------------- |
| `cooldown` requires `expires_at`; `duration_mode = timed`; max 30 days (CHECK)                             |
| `permanent_ban` requires `duration_mode = permanent`; `expires_at` must be NULL                            |
| `method_protection` permits no Principal Effect                                                            |
| `permanently_frozen` only on `permanent_ban` and `method_protection`                                       |
| `permanently_frozen` on `google` / `apple` methods forbidden until the common-storage cutover (CHECK)      |
| `visibility = hidden` only on `permanent_ban`                                                              |
| `withdrawal_purge_blocked`, `principal_hard_delete_blocked` only on `permanent_ban`, `method_protection`   |
| sets `admin_locked` only for `temporary_freeze`, `permanent_ban` — never `cooldown` or `method_protection` |
| Identifier Effect attachable to `permanent_ban` and `cooldown` only; never auto-created                    |
| `security_lock` requires `release_mode = verification_required`; no Identifier Effect                      |
| `temporary_freeze` supports `timed` and `indefinite`, never `permanent`                                    |
| indefinite `temporary_freeze` requires `release_mode = operator` and NOT NULL `review_due_at`              |

`method_protection`'s legal `authentication_method` set differs by realm: `entra` is org-only;
`google` / `apple` exist only in `app`.

## Case model

Per-realm table `enforcement_cases` (`app_zenith`, `com_zenith`, `org_zenith`). No foreign key to
any principal or credential row (see Purge protection). Columns, informed by the request's candidate
list and narrowed by the decisions above:

```text
public_id, realm, kind, state, duration_mode, visibility, release_mode

effective_at, expires_at, ended_at, end_reason
review_due_at            -- NOT NULL only for indefinite temporary_freeze; no runtime effect

reason_code, reason_note, ticket_id

principal_public_id                 -- target; no FK
applied_by_operator_public_id
approved_by_operator_public_id      -- NOT NULL when kind requires approval; CHECK != applied_by
ended_by_operator_public_id
break_glass                          -- boolean
break_glass_approved_by_operator_public_id

sessions_revoked_at, audited_at      -- D2 apply ledger, nullable until convergent jobs finish

created_at, updated_at
```

`end_reason` ∈ `expired`, `revoked`, `superseded`, `corrected`, `appeal_approved`,
`break_glass_released`.

## Principal effects

Table `enforcement_principal_effects`, one row per Case carrying an access-blocking or cold-path
effect. Booleans, not an enum/preset, because the combination is not the run-time complex part — the
run-time complex part is `admin_locked` itself, which this table never duplicates:

```text
login_blocked / authenticated_access_blocked      -- realized by calling AdministrativeAccessLock
recovery_blocked
reactivation_blocked
withdrawal_purge_blocked
principal_hard_delete_blocked
profile_effect            -- maps to clients.visibility_id / ClientVisibility, no new mechanism
```

`login_blocked` / `authenticated_access_blocked` are not independently toggleable columns read at
runtime — they are the trigger for calling `AdministrativeAccessLock.lock!` and are represented here
only as the Case's declared intent, validated against `kind` (Enforcement taxonomy). The remaining
four are read only at their own specific cold-path gate: recovery controller, reactivation
controller, `RetentionPurgeJob`, the principal-deletion trigger, and the profile resolver,
respectively.

## Authentication method effects

Table `enforcement_authentication_method_effects`. Grain: `(principal, authentication_method)`, not
a credential row — required because `change_locked`-equivalent forbidding of _adding_ a method the
principal does not yet have cannot be expressed as a flag on a nonexistent row. Per-credential-row
locking, if ever needed, is an additive column on this table.

```text
principal_public_id, authentication_method   -- CHECK against the per-realm vocabulary
effect                                        -- mutation_locked | unusable | permanently_frozen
effective_at, expires_at, ended_at
```

`authentication_method` values: `email`, `telephone`, `secret`, `passkey`, `totp`, `google`, `apple`
(app); `email`, `telephone`, `secret`, `passkey` (com); those plus `entra` (org). Must match
`established_authentication_method` exactly (see Session attribution).

| Effect               | Login     | Add/change/remove | Credential deletion | Ordinary operator revocation |
| -------------------- | --------- | ----------------- | ------------------- | ---------------------------- |
| `mutation_locked`    | allowed   | forbidden         | allowed             | allowed                      |
| `unusable`           | forbidden | forbidden         | allowed             | allowed                      |
| `permanently_frozen` | forbidden | forbidden         | forbidden           | forbidden                    |

An Authentication Method Effect never writes `access_state` or `token_valid_after_at`.

## Identifier effects

Table `enforcement_identifier_effects`. No foreign key to any principal (see Purge protection) —
these rows must outlive the account they originated from.

```text
identifier_kind         -- email | telephone | google_subject | apple_subject | identity_id
lookup_digest, key_version, digest_version, normalization_version
encrypted_display_value  -- gated behind enforcement.view_sensitive_identifiers

registration_blocked, attachment_blocked, recovery_blocked
effective_at, expires_at, ended_at
```

Google/Apple identifier rows key on `issuer` + `subject`, matching the in-flight
`ClientExternalIdentity` model's own uniqueness (`subject` scoped to `issuer`), not on email. Never
auto-created by a method-only freeze.

## Principal links

Table `enforcement_principal_links`. Relationship kinds: `target_principal`, `former_principal`,
`related_principal`, `suspected_duplicate`, `reinstated_principal`, `false_positive`. Stores
`principal_kind`, `principal_public_id` (no bigint FK — see Purge protection), `linked_at`,
`ended_at`, `relationship_kind`. Reinstatement creates a `reinstated_principal` link on the original
Case; the original Case is never deleted.

## State machine

`draft → pending_approval → active → ended`, plus `failed`.

## Transition matrix

| From               | To                 | Trigger                                                             |
| ------------------ | ------------------ | ------------------------------------------------------------------- |
| `draft`            | `pending_approval` | operator submits, `kind` requires approval                          |
| `draft`            | `active`           | operator applies, `kind` requires no approval                       |
| `pending_approval` | `active`           | second operator approves (CHECK: differs from applier)              |
| `active`           | `ended`            | expiry job, operator ends, appeal approved, break-glass release     |
| `active`           | `failed`           | apply-time invariant violation (rolled back within the transaction) |

## Duration and expiry

**Open** (`ended_at IS NULL`) is distinct from **in force**
(`effective_at <= now AND ended_at IS NULL AND (expires_at IS NULL OR expires_at > now)`), evaluated
at read time. Runtime correctness never depends on the expiry job having run. `expires_at IS NULL`
means no scheduled lapse — never `Float::INFINITY` (`Retainable::SENTINEL` means "not scheduled for
deletion," the near-opposite) and never `9999-12-31`.

PostgreSQL index predicates must be immutable, so `now()` cannot appear in a partial unique index.
Uniqueness is therefore enforced on the time-free predicate: one open row per
`(principal_public_id, authentication_method) WHERE ended_at IS NULL`, and per
`(identifier_kind, lookup_digest) WHERE ended_at IS NULL`. Applying a new effect closes any open row
occupying that slot in the same transaction (close-before-apply), which is what prevents an expired
row from blocking a new one and makes escalation/de-escalation atomic with an append-only history.

The expiry job is convergent and idempotent only — it writes `ended_at` and `end_reason = 'expired'`
where `ended_at IS NULL AND expires_at <= now`, and is never load-bearing for a security decision.
Timestamps come from the database transaction clock, not Ruby `Time.current`, so a Case and its
Effects share one instant.

## Visibility

`visible` or `hidden`; `hidden` legal only on `permanent_ban`.

Hidden enforcement is a Umaxica design decision with no external precedent (see External platform
policy comparison — no platform examined documents hidden enforcement). Guaranteed:

1. Byte-identical response — status, headers, public error code, body, redirect.
2. The same code path — the check sits at the credential-verification point and returns the existing
   invalid-credentials result object; there is no second branch to drift.
3. Identical side-effect profile — no email, SMS, OTP row, notification, or user-visible
   log/analytics event, because the ordinary failure path produces none.

**Not guaranteed**: wall-clock timing identity. The check adds no I/O beyond one indexed read the
ordinary path already performs — bounded, not usefully distinguishable, not zero. Because
`admin_locked` is rejected _after_ credential verification, hidden enforcement necessarily uses a
different insertion point than visible enforcement.

## Profile effects

`profile_effect` maps to the existing `clients.visibility_id` → `ClientVisibility` catalog
(`NOTHING=0`, `USER=1`, `STAFF=2`, `BOTH=3`). Initial mapping: `security_lock` / `cooldown` leave it
unchanged; `temporary_freeze` leaves the profile visible; `permanent_ban` (visible) sets an
unavailable/suspended presentation; `permanent_ban` (hidden) uses the ordinary unavailable/not-found
contract. Content moderation (post visibility, DM handling, cache invalidation) is out of scope — a
separate moderation decision.

## Appeal

Built on the existing withdrawal-ceremony pattern (`docs/security/withdrawal-privacy-erasure.md`): a
dedicated appeal ceremony cookie, email-OTP entry, resolves as `current_appeal_subject` (never a
normal current resource), issues no access token/refresh token/DBSC state/device binding, generic
entry response for unknown/active/ ineligible subjects. Reviewer separation is a CHECK constraint:
the appeal reviewer must differ from both the applying and the approving operator.

A hidden `permanent_ban` gets no appeal-specific entry point — offering one is itself the disclosure
the hidden-response contract exists to prevent. The ordinary, universally-visible support channel
remains available and carries no enforcement-specific signal.

No filing deadline in v1. An approved appeal releases through the same close-before-apply /
`admin_locked` refcount path as any other Case ending (see State machine, Administrative Access Lock
integration), and must also end any Identifier Effect the Case carries, or the user still cannot
re-register. `method_protection` appeals are excluded pending confirmation of demand. Org operators
appeal through internal escalation, not the ceremony.

## Approval

Enforced in the data model, not only in policy, because a policy-only rule is bypassed by
`Rails.console`, a rake task, or any future internal caller. `approved_by_operator_public_id` is NOT
NULL for kinds requiring approval, with a CHECK that it differs from
`applied_by_operator_public_id`; a CHECK denies operator self-action against their own principal
row. Required for: hidden `permanent_ban`; any `permanent_ban` targeting an `Operator`; any
break-glass release.

Surfaced as noun resources under `org` only, per `.agents/harnesses/rules/generic/routing.mdc`
(which forbids `approve` / `ban` as controller actions): `resources :enforcement_cases` with nested
`resource :approval`, `resource :release`, `resource :appeal_review`, each a `create`. Step -up
required on every mutating action via the existing `StepUpResolver`. This gives `admin_locked` its
first controller and policy — `adr/administrative-access-lock.md:104-105` explicitly declined to
approve a UI; this ADR records that expansion.

N-person approval beyond two would need a join table, not a column — deferred, not designed here.

## Break-glass

Release of a `permanently_frozen` Authentication Method Effect or a non-appealed `permanent_ban`
requires `break_glass = true` plus a second approver (`break_glass_approved_by_operator_public_id`),
both NOT NULL, flagged in the corresponding `enforcement.break_glass_released` audit event.

## Reinstatement

A `reinstated_principal` Principal Link is created on the original Case; the Case itself is never
deleted or rewritten. Old sessions/tokens are never revived — reinstatement re-establishes access
through the normal sign-in path, not by resurrecting prior tokens.

## Identifier normalization

Email: `lib/jit_utils_email_validator.rb:13-20` performs only `strip.downcase` plus a
`URI::MailTo::EMAIL_REGEXP` check — no Unicode NFC/NFKC, no IDNA, no plus-address handling.
Identifier Effect inherits exactly this canonicalization at `normalization_version = 1`; a future
correction to plus-addressing or Unicode handling is a new `normalization_version`, decided
separately (deferred; needed before Phase 6, not before this ADR). Telephone:
`TelephoneNormalization.normalize_to_e164`, unchanged. Google/Apple: `issuer` + `subject`, matching
`ClientExternalIdentity`'s own uniqueness scope, not email.

## HMAC

A dedicated enforcement digest, per realm, distinct from `EMAIL_ADDRESS_HMAC_SALT` /
`TELEPHONE_NUMBER_HMAC_SALT`. This narrows, but does not amend,
`adr/identifier-hmac-emergency-rotation.md`: that ADR rejected versioned columns and online rotation
because a dual-key window conflicts with a uniqueness index on the credential digest columns.
Identifier Effect rows carry no such uniqueness constraint — two Cases may legitimately restrict the
same identifier — so the conflict that motivated the rejection does not apply here. `lookup_digest`,
`key_version`, `digest_version`, `normalization_version` support dual-read online rotation.

**Ordering constraint**: `WithdrawalPersonalDataAnonymizer` nulls `address_digest` and rewrites the
address. Identifier capture must occur before anonymization runs, or the value is unrecoverable —
this pins the Case apply sequence (Identifier normalization → HMAC → Case confirmation → runtime
effect → session/token revocation → privacy contract).

## Encryption

`encrypted_display_value` stores the identifier for operator review, gated behind a dedicated
`enforcement.view_sensitive_identifiers` permission, separate from the HMAC used for matching.
Deterministic encryption (reversible, no separate stored digest) was considered and rejected: it
keeps the plaintext recoverable from the enforcement table indefinitely, which a data-minimization
review would reject for a table designed to outlive the account.

## Key rotation

Per-realm keys limit blast radius: compromising the login-lookup key does not hand an attacker an
offline oracle over the ban list, and vice versa. Rotation supports dual-read via `key_version`,
unlike the credential-table rotation contract, which remains stop-the-world per
`adr/identifier-hmac-emergency-rotation.md`.

## Database placement

**Per-surface `*_zenith`.** Enforcement Case, every Effect table, and Principal Link are created
independently in `app_zenith`, `com_zenith`, `org_zenith`, beside the principal they govern. Audit
events go to the existing shared `chronicle` database. No dedicated enforcement database, no
projection, no projection-reconciliation layer.

This follows the precedent `admin_locked` already set (state on the principal's own database,
history in `chronicle`), lets the permanent-freeze trigger read its predicate in the same database
it protects (satisfying `adr/database-trigger-usage-boundary.md`'s "a trigger must not attempt a
cross-database reference" without a stale-projection hazard), and makes realm isolation physical
rather than conventional. The cost accepted: an operator console queries three connections;
migrations are written three times; cross-realm reporting is a read-side concern, not a storage
concern.

A dedicated enforcement database with `*_zenith` projections (Option C in the audit) was considered
and rejected: it would force the deletion-protection trigger to read a projection rather than the
SSOT, making the projection the thing that actually protects data, while simultaneously removing
(via the no-new-Service constraint) the natural owner of cross-database apply, retry, and
reconciliation.

## Local projections

Not applicable — closed by the database placement decision above. No projection exists to reconcile,
go stale, or diverge from its source.

## Multi-database consistency

A single enforcement action still touches three databases even within one realm: `*_zenith` (state),
`*_ticket` (session/token revocation), `chronicle` (audit). The `EnforcementCase` ActiveRecord model
owns `apply!`: one `*_zenith` transaction writes the Case and all its Effect rows and sets
`state = active`; **runtime enforcement reads only that committed row**, so the security decision is
atomic and fail-closed at commit. Session revocation and the chronicle write are separate idempotent
jobs keyed on the Case `public_id`, recorded on `sessions_revoked_at` / `audited_at`. A model is not
a Service under `.agents/harnesses/rules/project/value-object-boundaries.mdc`; realm-shared
behaviour lives in a deliberately thin `EnforcementCaseApplicable` model concern, bounded by
`.agents/harnesses/rules/generic/rails-concerns.mdc`.

This also repairs an existing gap: `administrative_access_lock.rb:32-52` commits the state change
before revoking sessions and writing the audit event outside the transaction, so a failure after the
commit today leaves a locked account with no audit row.

`ChronicleOutboxEntry` was evaluated as a transactional-outbox option and rejected: it lives in the
`chronicle` database itself (per its own schema annotation) and is used only as a chronicle-write
degradation path (`authentication_audit_writer.rb:142`); it cannot make an audit record durable
against a `*_zenith` transaction.

## Failure recovery

A Case whose `state = active` with `sessions_revoked_at` or `audited_at` still null after apply is
in a recoverable, not inconsistent, state: the security decision (the committed `*_zenith` row) is
already correct and enforced; only the convergent side effects are pending.

## Reconciliation

A recurring job selects Cases with `state = active` and either `sessions_revoked_at` or `audited_at`
null, and retries the corresponding job. Idempotent by construction (session revocation and
chronicle writes are both safe to repeat).

## Concern architecture

`EnforcementCaseApplicable` (model concern, shared across the three per-realm `EnforcementCase`
models) is deliberately thin: it must not install callbacks or change authorization merely by
inclusion, per `.agents/harnesses/rules/generic/rails-concerns.mdc`. It supplies `apply!`,
close-before-apply effect superseding, and the in-force query helpers. Controller-side shared
behaviour (hidden-response handling, error-code mapping) lives in a controller concern applied
explicitly at each of the login/mutation/recovery/reactivation/signup gates — never installed
implicitly.

## Controller enforcement

No `ban`/`approve`/`toggle` actions (forbidden by `.agents/harnesses/rules/generic/routing.mdc`).
Org-side approval/release/appeal-review are noun resources (see Approval). Runtime gates (login,
mutation, recovery, reactivation, signup, identifier attachment) are existing controllers extended
with an explicit enforcement check at the point credential verification already occurs, not a new
controller layer.

## Model enforcement

`EnforcementCase#apply!` (Multi-database consistency); Effect models validate `kind`-vs-effect
legality (Enforcement taxonomy) via a cross-column validation in the
`administrative_access_lockable.rb:55-71` shape; the permanent-freeze deletion invariant is
additionally enforced by a model-layer guard so the ordinary application path raises a validation
error rather than surfacing a raw `ActiveRecord::StatementInvalid` from the trigger.

## Administrative Access Lock integration

The Case is the policy SSOT; `admin_locked` remains the sole runtime access gate, applied by calling
`AdministrativeAccessLock.lock!` / `unlock!` — no new read is added to
`palm_access_token_authenticator.rb`, `oidc_access_token_authenticator.rb`, or
`authentication_current_resource_resolver.rb`, and `ACCESS_STATES` stays two-valued.

`AdministrativeAccessLock#unlock!` (`administrative_access_lock.rb:64-72`) unconditionally clears
all lock columns. Ending one Case must not unlock a principal another active Case still blocks: a
refcount predicate — "no other Case with an access-blocking Principal Effect is in force for this
principal" (reusing the in-force definition from Duration and expiry) — gates the unlock call.
`admin_locked` remains directly settable by an operator with no Case at all; Unified Enforcement is
an additional caller, not the only path.

## Session attribution

New column `established_authentication_method` on `client_tokens`, `visitor_tokens`,
`operator_tokens`, CHECK-constrained to the per-realm vocabulary in Authentication method effects.
Distinct from, and explicitly not unified with, two existing vocabularies: the `auth_method:` kwarg
already accepted by `establish_signed_in_session!` (a flow-type marker, including non-method values
like `"session_limit_promotion"`), and the OIDC `amr` claim (an outbound contract that cannot
express `google` vs `apple` under RFC 8176's registered values). All three stay separate with
explicit mappings between them.

Populated by unifying the two `establish_signed_in_session!` entry patterns (the
`AuthenticationSessionCommitter` seam and the direct calls in
`sign_up_sequence_controller_support.rb:596,728`) so every login path writes it, and by resolving
`auth_method: "social"` into `google` / `apple` at the OmniAuth callback and social-completion call
sites. Nullable and additive; pre-migration sessions have
`established_authentication_method IS NULL` and this empties on its own after one maximum session
lifetime.

This is a prerequisite phase (Phase 1a), shipped and verified before any enforcement table exists.

## Session revocation

`unusable` and `permanently_frozen` revoke the union of three principal-scoped sets:

1. sessions whose `established_authentication_method` matches the target method;
2. sessions with `established_authentication_method IS NULL` — always, not only on the first effect,
   avoiding an inexplicable difference in behaviour on a second effect;
3. only when the target method is `totp`, sessions with `last_step_up_method = 'totp'`, revoked in
   full — a session whose elevation rests on a compromised authenticator is itself suspect.

`access_state` and `token_valid_after_at` are never touched. No AAL downgrade machinery is
introduced. `AuthenticationSessionRevoker` gains a method filter to express set (1); sets (2) and
(3) are additional `WHERE` clauses on the same revocation job.

Verification required during Phase 1a: `last_step_up_method` has no catalog (free-form string from
the ceremony's `allowed_methods_array`); confirm TOTP step-up actually writes `"totp"` before
relying on rule 3.

## JWT AMR

Phase 1b, approved separately from Phase 1a because it changes an OIDC claim external consumers
already read. `normalize_amr` is repaired to read `established_authentication_method` via an
explicit map, replacing derivation from token kind.

## Signup enforcement

An in-force Identifier Effect with `registration_blocked` on the normalized, HMAC-matched identifier
rejects signup at the same enumeration-resistance discipline as
`docs/security/withdrawal-privacy-erasure.md`'s existing generic ceremony-entry response.

## Identifier attachment enforcement

An in-force Identifier Effect with `attachment_blocked` rejects adding the identifier to an existing
account (email/telephone add, Google/Apple link) at the point the existing `AuthMethodGuard`-style
credential-mutation gate already runs.

## Recovery enforcement

An in-force Principal Effect with `recovery_blocked`, or an in-force Identifier Effect with
`recovery_blocked` on the identifier used for recovery, rejects the recovery flow at its existing
entry point, under the same generic-response discipline used for withdrawal ceremony re-entry.

## Withdrawal interaction

Unchanged. Normal withdrawal/deactivation/reactivation-window/erasure remain self-service lifecycle
machinery, wholly separate from Enforcement. `withdrawal_purge_blocked` is a Principal Effect read
only by `RetentionPurgeJob`, not a withdrawal-flow change.

## Erasure interaction

Identifier capture (HMAC + encrypted display value) must occur before
`WithdrawalPersonalDataAnonymizer` nulls `address_digest`, per the ordering constraint in Identifier
normalization. `principal_hard_delete_blocked` does not block ordinary erasure of personal data
fields — only the principal row's hard deletion (see Purge protection).

## Retention interaction

`RetentionPurgeJob` gains an explicit guard reading Principal Effect (`withdrawal_purge_blocked`,
`principal_hard_delete_blocked`) and the permanent-freeze predicate on Authentication Method Effect,
in addition to the database trigger — so the ordinary purge path produces a clean validation error
rather than surfacing a raw database exception.

## Purge protection

No enforcement table holds a foreign key to any principal or credential row. Every link is a
`principal_public_id` (plus, where convenient, a nullable non-FK internal id) — never a bigint FK.
This makes it structurally impossible for a lapsed, non-permanent Case to block deletion, and
satisfies `adr/cross-db-reference-policy.md`. `ON DELETE RESTRICT` was considered and rejected
outright: a `RESTRICT` FK cannot be conditioned on "active" or "permanent," so it would make a
lapsed 24-hour cooldown block principal deletion forever.

Deletion is instead enforced by a per-table trigger function reading the Effect table directly on
the time-free predicate `effect = 'permanently_frozen' AND ended_at IS NULL`, backed by a partial
index (see Trigger design). Because a permanent freeze has no `expires_at` by construction, the
trigger never evaluates wall-clock and cannot disagree with the application about "now."

## Trigger design

Per `adr/database-trigger-usage-boundary.md` (Context corrected by this ADR — see below): one
function per protected table, function and `CREATE TRIGGER` in the same migration, an exact-reverse
`down`, a test that deletes via raw SQL and asserts the database raises, and registration in a
per-database trigger-inventory test. Triggers are duplicated per realm; none reads another database.

**v1 scope (16 tables): stable storage only.** Per realm: `*_emails`, `*_telephones`, `*_passkeys`,
`*_secret_credentials`; plus `client_totp_credentials` (app), `operator_entra_identities` (org);
plus principal hard-delete protection on `clients`, `visitors`, `operators`.

**Deferred**: `client_google_identities`, `client_apple_identities`, `client_external_identities`.
The database-trigger-usage-boundary ADR exists because a table rename once orphaned trigger
functions silently; `client_external_identities` is being rewritten in the working tree behind a
runtime `common_storage?` branch at the time of this decision. Attaching a trigger to it now would
risk re-enacting that documented failure. A CHECK constraint forbids `permanently_frozen` on
`google` / `apple` methods until the cutover completes — an unenforceable freeze is not a freeze,
and shipping one would be a silent fallback forbidden by
`.agents/harnesses/rules/generic/no-silent-fallback.mdc`. `mutation_locked` and `unusable` need no
trigger and are available for `google` / `apple` from v1.

`client_totp_credentials` and `client_external_identities` have neither `discarded_at` nor
`purged_at` and are absent from `RETAINABLE_MODELS`, so no `delete_all` route reaches them; their
trigger's justification rests on `dependent: :destroy` and direct SQL only, weaker than the
justification for the other fourteen tables.

### Correction to `adr/database-trigger-usage-boundary.md`

That ADR's Context states "several credential foreign keys cascade with `ON DELETE CASCADE`" and
"eight orphaned trigger functions." Both are corrected in that file directly: zero credential tables
have a cascading FK anywhere in `app_zenith_structure.sql`, and there are five orphaned functions,
not eight. That ADR's Decision — triggers permitted narrowly, because `delete_all` in
`RetentionPurgeJob` and direct SQL still defeat a model callback — is unaffected and remains
Accepted.

## Audit contract

Lifecycle events go to a new `enforcement_events` table in the existing `chronicle` database, keyed
on `case_public_id` and `principal_public_id` strings (never bigints, unlike the existing
`AccountAccessEvent.account_id :bigint`, which is not repeated here), with a mandatory `realm`
column and typed NOT NULL `event_type`, `reason_code`, `operator_public_id`, `break_glass` boolean,
`ticket_id`, `occurred_at`, plus sanitized `metadata` jsonb:

```text
created, approval_requested, approved, applied, activated, extended, escalated, reduced,
ended, expired, corrected, break_glass_released,
appeal_submitted, appeal_approved, appeal_rejected,
principal_linked, principal_reinstated,
revocation_failed, revocation_reconciled
```

High-volume denial events (`login_denied`, `mutation_denied`, `registration_denied`,
`identifier_attachment_denied`, `recovery_denied`, `reactivation_denied`) go to `occurrence` as
counters, not to `chronicle`: they are unbounded and attacker-driven, and one row per attempt would
make any enforced account an amplification vector against the audit database. This keeps
`occurrence` a deliberately separate domain, per `adr/chronicle-audit-db-consolidation.md`. Accepted
consequence: per-attempt denial timing is not individually reconstructible; if appeals need it,
bounded `first_denied_at` / `last_denied_at` / `denial_count` columns on the Case are the answer,
not a per-event log.

Per `adr/chronicle-audit-implementation-guidance.md`: fixed catalog event names, written at the
domain layer when the outcome is known, never raw OTPs/tokens/auth headers/cookies/full params,
corrections as follow-up events rather than row updates. Enforcement events survive principal purge,
matching `client_chronicles`'s existing deliberate retention.

## Authorization

Realm-scoped permission grants (see Realm isolation): `enforcement.view`,
`enforcement.view_sensitive_identifiers`, `enforcement.apply_security_lock`,
`enforcement.apply_cooldown`, `enforcement.apply_temporary_freeze`,
`enforcement.apply_permanent_ban`, `enforcement.apply_method_effect`, `enforcement.extend`,
`enforcement.end`, `enforcement.approve`, `enforcement.break_glass_release`,
`enforcement.review_appeal`, `enforcement.link_principal`, each namespaced per realm.

## Operator safety

Operator self-action denial and approval separation are CHECK constraints, not only policy (see
Approval). The last-enabled-operator guard applies to `Operator` only — never to `Client` or
`Visitor`, which have no equivalent constraint — reusing
`AuthenticationCredentialInventory#retains_aal1?`, already used by `AuthMethodGuard` for
credential-removal guarding, and extended to cover `entra` as an in-scope org method. The asymmetry
is grounded in recovery paths, not convenience: a locked-out `Client` recovers through support; a
locked-out `org` has no remaining actor able to perform the recovery. The repository already takes
this position in two existing Operator-only guards (`administrative_access_lock.rb:128-141`,
`org_operator_lifecycle_execute.rb:113-122`).

## Privacy and minimization

Identifier Effect stores an HMAC digest for matching and a separately-gated encrypted display value
for operator review, never the plaintext in a generally-readable column (see HMAC, Encryption).
Denial telemetry is aggregate-only (see Audit contract). Enforcement audit metadata follows the same
sanitization discipline as `adr/chronicle-audit-implementation-guidance.md`: never raw OTPs, tokens,
auth headers, cookies, or full request params.

## Threat model

Evaluated against the request's list; notable items resolved by decisions above rather than left
open: ban evasion via re-registration (Identifier Effect, realm-scoped keys prevent cross-realm
matching); insider operator abuse (approval CHECKs, realm-scoped permissions, cannot be bypassed by
console/rake); unauthorized break-glass (dedicated permission, two-approver CHECK); hidden
enforcement enumeration and timing side channel (Visibility contract, explicitly bounded not zero);
direct model mutation / raw SQL / bulk delete (trigger, Trigger design); stale projection (not
applicable — no projection exists, Database placement); expiry race and concurrent
signup/identifier-attachment race (close-before-apply plus the time-free unique index, Duration and
expiry); rollback / backup restore and clock skew (time-free trigger predicate, Purge protection);
cross-realm leakage (Realm isolation); Rails console / maintenance script bypass (CHECK constraints
and triggers, not policy alone).

## Race conditions

Handled structurally rather than by locking discipline alone: the time-free partial unique index
plus close-before-apply (Duration and expiry) makes concurrent effect application on the same slot
resolve to exactly one open row; the time-free trigger predicate (Purge protection) makes deletion
protection immune to clock skew between the application and the database.

## Observability

Enforcement lifecycle events are the durable record (Audit contract); denial volume is `occurrence`
counters, kept separate from `chronicle` so that attacker-driven volume cannot degrade the audit
database (Audit contract). No new `Rails.event` observability channel is introduced by this ADR.

## Rollout

Sequenced as eleven phases, gated on explicit approval between each:

0. ADR and documentation (this document). 1a. Session establishing-method attribution (prerequisite;
   highest-risk single change, touches every login path). 1b. JWT `amr` repair (separately approved;
   OIDC contract risk).
1. Enforcement Case and Effect tables.
2. Audit (`enforcement_events`, occurrence counters, apply-ledger jobs, reconciler).
3. Authentication Method Effects (runtime gates, method-scoped revocation).
4. Principal Effects and `admin_locked` integration (refcount predicate).
5. Identifier Effects (per-realm HMAC, capture-before-anonymize ordering).
6. Withdrawal/erasure/retention protection guards.
7. Triggers (16 functions, largest single phase).
8. Org console, approval, break-glass, appeal.
9. Expiry and reconciliation.
10. app/com/org parity, rollout, documentation.

## Backfill

No backfill of `established_authentication_method` for existing sessions — treated as
permanently-NULL until natural session expiry (Session attribution). No backfill of Enforcement Case
rows from any prior mechanism; there is no prior mechanism with equivalent data.

## Migration

Every phase's migrations are additive (new tables/columns/CHECK constraints) except the Phase 8
trigger migrations, which are the first `CREATE TRIGGER` statements in this repository and require
their own reversible `down`. Per `.agents/harnesses/rules/generic/migrations.mdc`, schema and data
changes stay in separate migrations throughout.

## Rollback

Every phase before 8 is rollback-safe by dropping additive columns/tables. Phase 8 triggers drop
with a one-line reversible migration (`DROP TRIGGER`), leaving deletion protection to the
model-layer guard alone until re-applied. A Case can be ended without ever having touched
`access_state` if it carried no access-blocking Principal Effect.

## Test strategy

Per `.agents/harnesses/rules/generic/testing.mdc`, no test helper methods — every test's setup,
action, and assertion is inline. Coverage required per phase: realm isolation (a Case in one realm
never affects another, including through shared identifier values); each Method Effect mode's full
behavioural matrix (login/mutation/deletion/session-scope, per row of the table in Authentication
method effects); each Case kind's taxonomy CHECK constraints (illegal combinations must fail to
save, not merely fail validation in application code); trigger tests that delete via raw
SQL/`delete_all`/cascade and assert the database raises, per
`adr/database-trigger-usage-boundary.md`; multi-database apply failure/retry/idempotency/
reconciliation; privacy (no raw identifier in logs/audit, encrypted-display gating); operator safety
(self-action denial, last-enabled-operator, two-person approval, cross-realm denial); and regression
coverage for existing withdrawal, `admin_locked`, OIDC, DBSC, passkey, secret, email, telephone,
TOTP, Google, Apple, Entra, and retention behaviour untouched by this work.

## Open questions

Deliberately deferred, not decided, by this ADR:

- N-person approval beyond two — decide before the Phase 2 migration if foreseeable.
- Appeal filing deadline, re-filing limits, evidence upload.
- Entra tenant + object id as an Identifier Effect kind.
- Google/Apple triggers and the `permanently_frozen` CHECK, post-cutover.
- Plus-address / Unicode / IDNA canonicalization policy and telephone reassignment/recycling —
  needed before Phase 6.
- Whether `method_protection` requires approval and whether it is appealable.

## Decisions

Recorded in full, with rationale and rejected alternatives, in the audit's Decision Log (D1–D20)
produced during this ADR's authoring session. Summary:

D1 per-surface `*_zenith` SSOT · D2 `EnforcementCase#apply!` + idempotent jobs · D3 Case drives
`admin_locked`, never duplicates it · D4 session attribution is a two-step prerequisite phase · D5
this ADR supersedes the prior one; the trigger ADR's Context is corrected in place · D6 dedicated
per-realm HMAC digest with version columns · D7 no FKs to principals; trigger reads Effects on a
time-free predicate · D8 open vs. in-force, close-before-apply, no Infinity sentinel · D9 effects
stored, `kind` constrains via CHECK · D10 `enforcement_events` in chronicle, denials as `occurrence`
counters · D11 hidden response: byte-identical, same path, bounded timing, no wall-clock guarantee ·
D12 approval/self-action/break-glass enforced by CHECK, not policy alone · D13 realm-scoped
permissions, unified Operator population · D14 appeal ships in v1 on the withdrawal-ceremony
pattern; hidden bans use generic support only · D15 cooldown: no fixed standard duration, 30-day
CHECK maximum, opt-in signup/attachment blocking · D16 new CHECK-constrained vocabulary for
`established_authentication_method`, distinct from `auth_method:` and `amr` · D17 Method Effect
revokes matching ∪ NULL ∪ (TOTP-only) step-up sessions · D18 indefinite `temporary_freeze` permitted
with mandatory `review_due_at`, no auto-release · D19 Entra in v1 scope; last-usable-method guard
applies to `Operator` only · D20 triggers on 16 stable tables in v1; Google/Apple deferred with a
CHECK blocking `permanently_frozen` until cutover.

## Rejected alternatives

- Dedicated enforcement database with `*_zenith` projections (Database placement).
- `ON DELETE RESTRICT` from enforcement to principals (Purge protection).
- Deriving effects from `kind` at read time instead of storing them (Enforcement taxonomy).
- Reusing `AccountAccessEvent` for enforcement lifecycle events (Audit contract).
- Reusing `IdentifierBlindIndex`'s existing key for Identifier Effect digests (HMAC).
- Deterministic encryption in place of an HMAC digest for identifier matching (Encryption).
- A fixed standard `cooldown` duration encoded in schema (Enforcement taxonomy).
- Mandatory `expires_at` on `temporary_freeze` (Enforcement taxonomy — this fails open under the
  in-force read-time evaluation in Duration and expiry).
- A unified cross-realm operator permission set (Realm isolation).
- Separate app/com-resident operator populations (Realm isolation).
- Applying the last-usable-method guard to `Client` / `Visitor` (Operator safety).
- Attaching triggers to `client_google_identities` / `client_apple_identities` /
  `client_external_identities` in v1 (Trigger design).
- A single hidden-enforcement branch constructed to mimic ordinary failure, rather than sharing the
  exact same code path (Visibility).

## Future work

- Common-storage cutover completion, at which point the deferred Google/Apple triggers and the
  `permanently_frozen` CHECK relaxation become a scoped follow-up phase.
- Per-credential-row locking (additive column on Authentication Method Effect), if a use case beyond
  method-level granularity emerges.
- Appeal filing deadlines and re-filing limits, if volume demands them.
- Cross-realm aggregate operator reporting, as a read-side concern layered on the per-realm storage
  in Database placement.
- `plans/backlog/credential-abuse-rate-limit-policy.md`'s pre-Case rate-limiting tuple framework,
  layered on top of `cooldown` without conflict.

## Related

- `adr/administrative-access-lock.md`
- `adr/authentication-method-lock.md` (superseded by this ADR)
- `adr/database-trigger-usage-boundary.md`
- `adr/cross-db-reference-policy.md`
- `adr/identifier-hmac-emergency-rotation.md`
- `adr/chronicle-audit-db-consolidation.md`
- `adr/chronicle-audit-implementation-guidance.md`
- `adr/retainable-concern-and-retention-purge.md`
- `adr/authentication-assurance-level-boundaries.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/database-authority-placement.md`
- `docs/security/withdrawal-privacy-erasure.md`
- `docs/security/observability-boundary.md`
- `docs/security/unified-enforcement.md`
- `.agents/harnesses/rules/project/value-object-boundaries.mdc`
- `.agents/harnesses/rules/project/surfaces.mdc`
- `.agents/harnesses/rules/generic/routing.mdc`
- `.agents/harnesses/rules/generic/testing.mdc`
- `.agents/harnesses/rules/generic/no-silent-fallback.mdc`
