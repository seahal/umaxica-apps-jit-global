# Org control plane production readiness

Where each part of the org administrative control plane stands, reconciled with earlier decisions in
ADRs, security docs, and owner instructions, and with the code at
`evidence/2026-09-26-org-control-plane-release-candidate-baseline-Q4T7.md`. It records decisions; it
makes none. Where a decision has no repository source other than the owner's instruction of
2026-09-26, that is stated.

## Summary

| Item | Category | What remains |
| --- | --- | --- |
| Capability authorization (default deny, per-operation, no wildcard, no role/type derivation) | Ready | none |
| Support account read (app, com) | Ready after deployment configuration | grant assignment |
| Enforcement read (app, com) | Ready after deployment configuration | grant assignment |
| Enforcement apply / approve / release / appeal review (app, com) | Blocked by implementation | OQ-AUD-001; grant assignment |
| Support session revoke (app, com) | Blocked by implementation | OQ-AUD-001; grant assignment |
| IAM grant / revoke | Blocked by implementation | OQ-AUD-001; grant assignment |
| Bootstrap task | Ready after deployment configuration | operator ids at deployment |
| Chronicle compliance retention (OQ-AUD-004) | Ready | 365 days, decided 2026-09-26 |
| Chronicle tamper resistance (OQ-AUD-001) | Blocked by implementation | method decided (DB role privileges); infrastructure and migration pending |
| Chronicle retention enforcement (`erasable_at` purge) | Blocked by implementation | retention gap, separate issue |
| Audit read (Chronicle UI) | Blocked by implementation | access model decided, access path not built |
| Break-glass release | Blocked by implementation | policy decided, second-approver flow not built |
| Membership mutation | Intentionally closed | ownership source of truth unresolved |
| Org-realm Enforcement | Intentionally closed | operator-to-operator authorization matrix unresolved |
| Operator lifecycle mutation | Intentionally closed | authorization matrix unresolved |
| Billing / configuration / system consoles | Intentionally closed | no data source |
| `test_primary_db` artifacts, `avatars/show.tsx` type error | Environment / unrelated | separate issues |

## Ready

- **Capability model.** Default deny; one fixed capability per operation and realm; no wildcard; no
  capability from role names, operator type, or Bureau ownership/grants; granting separate from
  holding; no self-grant; delegation never widens; IAM capabilities only by bootstrap; continuity
  guard with row locking, verified under concurrency.
- **Step-Up for high-risk operations.** Decided: an operator's high-risk operations require a fresh
  passkey Step-Up; ORG Step-Up is passkey only (`docs/security/authentication-assurance-levels.md`);
  Email OTP, TOTP, Secret Credential, and Entra do not substitute; Step-Up completion is not an
  assurance level. Implemented for session revoke, IAM grant and revoke, Enforcement apply, approve,
  release, and appeal review, after the capability check, and verified through the real ceremony.
- **Assurance.** Decided: achieved AAL today is AAL1 only; AAL2 and AAL3 are unsupported at runtime
  and must not be claimed; AAL3 is reserved for future platform-level operations and recovery and is
  outside this work. Implemented: the administrative scopes require `StepUpRequirement::NO_AAL` and a
  passkey completion records `aal1`. The condition for high-risk operations is explicit capability
  plus fresh passkey Step-Up, and it is not described as AAL2.
- **Emergency.** Decided and implemented: an Emergency session gets no high-risk administrative
  ability and cannot start or satisfy Step-Up to become an ordinary administrator.
- **Four-eyes.** Decided (`adr/unified-enforcement.md`, Approval) and implemented: the applying
  operator cannot approve; the appeal reviewer differs from applier and approver; no self-approval
  fallback. Staffing needs only "an authorized operator other than the initiator".

## Ready after deployment configuration

Only environment values remain; the architecture is decided.

- **Bootstrap operators.** Decided: bootstrap only explicitly named operators; no automatic
  administrator, no grant to all operators; at least two operators with the IAM capabilities as an
  operational recommendation (the console cannot prevent expiry or ineligibility of the last holder;
  this is not a system guarantee). Deployment input: the operator public ids.
- **Initial grant assignment.** Decided: least privilege, per-operation capabilities, nothing granted
  by default. No repository source fixes an exact initial set. The grants stay separable:

  | Group | Capabilities |
  | --- | --- |
  | IAM bootstrap authority | `iam.capability.read`, `iam.capability.grant`, `iam.capability.revoke` |
  | Support read | `support.console.read`, `support.account.read.{app,com}` |
  | Support mutation | `support.session.revoke.{app,com}` |
  | Enforcement read | `enforcement.read.{app,com}` |
  | Enforcement mutation | `enforcement.{apply,approve,release,review_appeal}.{app,com}` |

  Deployment input: which operator receives which group. Only the IAM group is issued by bootstrap;
  the rest are delegated in the console by a holder who has them.

## Decided on 2026-09-26

- **OQ-AUD-004, compliance retention: 365 days**, set by the owner, who noted it may change later.
  Inserted by `db/chronicle_migrate/20260926130000_insert_compliance_chronicle_retention_policy.rb`
  (`INSERT ... ON CONFLICT (code) DO NOTHING`, idempotent, never overwrites). A later change is a new
  migration that updates the row. `docs/srs.md`'s 180-day floor is met. The period has no deletion
  effect until retention enforcement is built (below). Enforcement events do not use a retention
  policy.
- **OQ-AUD-001, tamper-resistance method: database role privileges** (`adr/chronicle-tamper-resistance.md`),
  chosen by delegation to the recommendation. Not implemented, so it remains a blocker below.
- **Initial capability assignment: the recommendation below**, chosen by delegation. Operator public
  ids are still deployment inputs.

### Recommended initial assignment

Delegation never widens, so an IAM holder can only grant what they hold, while bootstrap can issue any
catalog capability to a named operator with a ticket. Recommendation:

| Who | Capabilities | How | Expiry |
| --- | --- | --- | --- |
| Two IAM administrators (A, B) | IAM group; Support read; Support mutation; Enforcement read | bootstrap | 90 days, renewed after access review |
| Support staff | Support read, and Support mutation only if they revoke sessions | console grant by A or B | 90 days |
| Enforcement staff | none at launch | — | — |
| When an enforcement procedure is staffed: an opener/releaser and a different approver/reviewer | opener: `enforcement.read.*`, `enforcement.apply.*`, `enforcement.release.*`; approver: `enforcement.read.*`, `enforcement.approve.*`, `enforcement.review_appeal.*` | bootstrap, one ticket per person | 90 days |

This keeps disciplinary capabilities off the IAM administrators and splits opening from approval
across two people, matching four-eyes. The 90-day expiry is a recommendation for review cadence; the
system maximum is 366 days.

## Blocked by implementation

- **OQ-AUD-001, tamper resistance.** Method decided (`adr/chronicle-tamper-resistance.md`): the
  chronicle tables are owned by a migration role; the application's runtime role gets INSERT, UPDATE
  only on `chronicles (result, changeset, updated_at)`, and no DELETE. Needs separate migration and
  runtime database users (production uses one `NEON_PGUSER` today), then a grant migration and a test
  proving the runtime role cannot UPDATE or DELETE through raw SQL. Applies to every administrative
  operation's audit, Enforcement included.
- **Chronicle retention enforcement.** `chronicles.erasable_at` is computed from the policy, and
  `adr/chronicle-audit-implementation-guidance.md` requires applying retention and purge rules
  through the existing retention model, but `RetentionPurgeJob::RETAINABLE_MODELS` covers only the
  family chronicle tables (`ClientChronicle`, `OperatorChronicle`, preference chronicles), not
  `Chronicle`. Nothing reads `erasable_at`. This is a retention enforcement implementation gap,
  separate from choosing the period; no deletion job was added.
- **Audit read.** Access model decided (owner instruction, 2026-09-26; no earlier repository source
  was found): explicit `audit.read` capability, never operator type alone; audit read separate from
  any mutation capability; viewing, querying, and exporting the audit log are themselves audited; no
  secret, token, or credential plaintext is shown. Not implemented: no `audit.read` capability exists
  in the catalog and the audit console stays closed. Deployment of who holds `audit.read` is not
  decided in any source found.
- **Break-glass release.** Policy decided (`adr/unified-enforcement.md`, Break-glass): a permanent
  enforcement is never released through the ordinary path; release needs break-glass with a second
  approver. Implementation incomplete: the second-approver flow does not exist, so the release
  endpoint refuses permanent bans and `break_glass_only` Cases and create refuses `break_glass`.

## Intentionally closed

| Operation | Route | Policy | UI | Reason | Depends on |
| --- | --- | --- | --- | --- | --- |
| Membership create/update/destroy | not routed on org | change rules deny org records | none | two ownership representations (`BureauOwnership`/`BureauAdministrationGrant` and membership `OWNER`); no Accepted decision names the authority | ownership source of truth |
| Org-realm Enforcement | routed | every rule denies (no capability) | none linked | operator discipline must not derive from app/com support authority; no Accepted operator-to-operator matrix | operator-to-operator authorization matrix |
| Operator lifecycle (join, suspend, terminate, restore) | not routed | every rule denies | none | responsibility decided (Rails org control plane owns it; no signup/JIT creation of operators; passkey Step-Up for high-risk transitions; Emergency may not act), but who may act on which operator is not decided | authorization matrix |
| Operator session revocation | not routed | — | none | outside app/com support authority | authorization matrix |
| Billing / configuration / system consoles | routed | `OrgConsolePolicy` denies | not linked | no authoritative data source | data source |

Existing code for an operation (for example the lifecycle services) does not make it a provided
feature. None of these needs to be resolved to run the app/com control plane. No repository source
assigns dates or owners to them.

## Environment / unrelated

1. **`test_primary_db` contamination.** Functions `check_staff_identity_emails_limit`,
   `check_staff_identity_passkeys_limit`, `check_staff_identity_telephones_limit` and extensions
   `citext`, `pgcrypto` were created by a misrouted verification script (see
   `evidence/2026-09-26-org-control-plane-convergence-R8M3.md`). Standard procedure
   (`docs/operations/db-workflow.md`): stop test processes, then `RAILS_ENV=test bin/rails
   db:migrate:reset`, which drops and recreates every test database, test_primary_db included. Test
   databases are disposable, but confirm no other work is using them first. If recreation is not
   permitted, the manual alternative is `DROP FUNCTION public.<name>() CASCADE` for the three
   functions and `DROP EXTENSION citext; DROP EXTENSION pgcrypto;` on `test_primary_db` only. Not
   executed.
2. **Frontend typecheck.** `src/pages/base/org/avatars/show.tsx(25,6)` TS2375, present in a clean
   export of `e423890e7`. The frontend typecheck therefore exits non-zero on this one pre-existing
   error; the changed admin files have no type errors.
3. **Schema drift at HEAD.** `db/org_zenith_structure.sql` at `e423890e7` lacked the tables of
   migrations `20260923170002` and `20260923180002`; the regenerated dump includes them.
