# Unified Enforcement Operational Contract

This document is the operational reference for `adr/unified-enforcement.md`. The ADR is the source
of truth for rationale and rejected alternatives; this document is the quick-reference contract for
anyone implementing against or operating Unified Enforcement. The Case and Effect substrate, Account
Standing, appeal persistence and review, and the verified-email recovery ceremony are implemented.
Content moderation and richer notification delivery remain separate follow-up work.

## What this replaces

Two previously separate mechanisms — Authentication Method Lock and Identity BAN / Identity Freeze —
are one Enforcement Case substrate. `admin_locked` (`adr/administrative-access-lock.md`) is
unchanged; Enforcement calls it, never duplicates it.

## Three effect kinds, never collapsed

- **Principal Effect** — account-wide. Realized by calling `AdministrativeAccessLock`, never a
  parallel access state.
- **Authentication Method Effect** — one `(principal, authentication_method)` pair.
- **Identifier Effect** — one identifier value (email, telephone, Google/Apple `issuer`+ `subject`),
  independent of any surviving principal row.

These three never share a column or a state machine. A method-only freeze never implies an account
block; an account block never implies an identifier tombstone.

## Realm isolation

`app`, `com`, `org` are independent at storage (separate tables per realm in `*_zenith`),
application (`EnforcementCase#apply!` never crosses realms), identifier matching (separate HMAC key
per realm), and authorization (realm-scoped permission grants). A Case, Effect, or permission in one
realm never reads or writes another realm's data.

## Where state lives

No dedicated enforcement database. Enforcement Case and every Effect table live in the principal's
own `*_zenith` database. Audit events live in the existing shared `chronicle` database. No
projection, no projection reconciliation.

## Duration contract

An effect is **in force** when
`effective_at <= now AND ended_at IS NULL AND (expires_at IS NULL OR expires_at > now)`, evaluated
at read time — never dependent on a background job having run. `expires_at IS NULL` means no
scheduled lapse; this is never expressed as `Float::INFINITY` or `9999-12-31`.

| Kind                | `expires_at`                  | Notes                                                 |
| ------------------- | ----------------------------- | ----------------------------------------------------- |
| `cooldown`          | required, max 30 days         |                                                       |
| `security_lock`     | operator/verification release |                                                       |
| `temporary_freeze`  | optional                      | indefinite requires `review_due_at` (no auto-release) |
| `permanent_ban`     | forbidden (NULL)              |                                                       |
| `method_protection` | per effect row                |                                                       |

## Visibility contract

`hidden` is legal only on `permanent_ban`. A hidden Case guarantees: byte-identical response
(status/headers/error code/body/redirect), the same code path as an ordinary credential failure (no
second branch), and an identical side-effect profile (no email/SMS/OTP row/notification). **Not
guaranteed**: wall-clock timing identity — only that no extra I/O beyond one indexed read is added.

## `admin_locked` integration

A Case with an access-blocking Principal Effect calls `AdministrativeAccessLock.lock!` / `unlock!`.
Before unlocking, the refcount rule applies: **do not unlock if any other Case with an in-force
access-blocking Principal Effect exists for this principal.** `admin_locked` remains directly
settable by an operator with no Case at all.

## Session revocation on Method Effect

`unusable` / `permanently_frozen` revoke the union of: sessions whose
`established_authentication_method` matches the target method; sessions with that column `NULL`
(always, regardless of prior effects); and, only when the target method is `totp`, every session
with `last_step_up_method = 'totp'`. `access_state` and `token_valid_after_at` are never touched by
a Method Effect.

## Deletion protection

No enforcement table holds a foreign key to a principal or credential row — every link is a
`principal_public_id`. A per-table database trigger (v1: 16 stable tables; Google/Apple deferred
until the common-storage cutover) blocks deletion on the time-free predicate
`effect = 'permanently_frozen' AND ended_at IS NULL`. The model layer also guards this, so the
ordinary application path returns a validation error, not a raw database exception.

## Identifier storage

Per-realm HMAC key, distinct from the credential-table digest keys
(`adr/identifier-hmac-emergency-rotation.md`), with `key_version` / `digest_version` /
`normalization_version` supporting online rotation — **do not reuse `IdentifierBlindIndex`'s
existing key for Identifier Effect rows.** Capture identifiers **before** any anonymization step
runs; `WithdrawalPersonalDataAnonymizer` nulls the credential digest and is irreversible.

## Approval and break-glass

Enforced as CHECK constraints, not policy alone — a policy-only rule is bypassable from
`Rails.console` or a rake task. Two-person approval required for: hidden `permanent_ban`, any
`permanent_ban` targeting an `Operator`, and any break-glass release. The approving operator must
differ from the applying operator; the target principal must differ from the applying operator.

## Last-usable-method guard

Applies to `Operator` only, reusing `AuthenticationCredentialInventory#retains_aal1?`. Does **not**
apply to `Client` or `Visitor` — all authentication methods may be stopped for a Client or Visitor
if the Case calls for it.

## Audit

Lifecycle events (`created`, `approved`, `applied`, `ended`, `expired`, `break_glass_released`,
etc.) go to `enforcement_events` in `chronicle`, keyed on `case_public_id` / `principal_public_id`
strings. High-volume denial events (`login_denied`, `mutation_denied`, etc.) go to `occurrence` as
counters, never to `chronicle`.

## Account Standing, appeal, and recovery

`/identity/standing` is available independently on the `app`, `com`, and `org` Base surfaces. It
derives `Good`, `Notice`, `Limited`, or `Locked` from visible, in-force Cases and their Effects. It
deliberately excludes operator notes, reporter data, ticket identifiers, and internal signals.

An appeal is text-only, has one row per Case, and has no filing deadline or attachment support. The
current self-service entry is the verified recovery ceremony for eligible visible security locks;
broader Case entry points remain follow-up work. Submission writes the `appeal_submitted` chronicle
event without the appeal statement. An org appeal-review resource requires step-up and rejects
self-review by the applying or approving operator. An approved review ends the Case through the
normal refcounted release path; rejection leaves it in force. Redaction clears the encrypted
statement while preserving the decision record.

For a visible `security_lock` with `release_mode = verification_required`, `app` and `com` expose an
open recovery entry backed by a short-lived, opaque recovery-ceremony cookie. A verified email OTP
may issue that cookie; it does not issue an access token, refresh token, DBSC state, or device
binding. The recovery status only resolves Cases for the cookie's subject and can complete only that
subject's eligible Case. Unknown, active, hidden, and otherwise ineligible subjects use the same
email-OTP entry response. Passkey and TOTP proofs are tracked as follow-up work. Telephone OTP is
excluded as a recovery proof by decision — SMS is not an accepted authentication proof anywhere in
this application, so it is also absent from sign-in and from the step-up method contract.

## Related

- `adr/unified-enforcement.md` — full rationale, rejected alternatives, and phase-by-phase rollout
  plan.
- `adr/administrative-access-lock.md`
- `docs/security/withdrawal-privacy-erasure.md`
- `docs/security/observability-boundary.md`
- `docs/architecture/database-boundaries.md`
