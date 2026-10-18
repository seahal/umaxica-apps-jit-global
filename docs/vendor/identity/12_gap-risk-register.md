---
title: Identity Gap and Risk Register
status: draft
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: TBD
last-reviewed: TBD
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
---

# Purpose

List the current documentation gaps, risks, contradictions, and follow-ups.

# Scope

This register is based on the current audit and repository evidence.

# Non-scope

This is not a backlog replacement.

# Source Evidence

- `docs/vendor/identity/*`
- `docs/security/session-token-authority.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/observability-boundary.md`

| ID          | Type          | Security Severity | Procurement Blocker | Description                                                                                                          | Evidence                                                                                                          | Impact                                                                                                                                   | Recommended Action                                                                            | Owner                                    | Status                                                                          |
| ----------- | ------------- | ----------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| G-001       | GAP           | High              | Major               | No single vendor-facing identity dossier existed before this package.                                                | This package was created to consolidate evidence.                                                                 | Reviewers had to chase scattered docs.                                                                                                   | Keep this package current.                                                                    | Internal architecture                    | Open                                                                            |
| G-002       | GAP           | High              | Major               | Route inventory was fragmented across route files and route contract tests.                                          | `config/routes/*.rb`, `test/integration/routes/*.rb`                                                              | Route ownership was harder to review.                                                                                                    | Maintain the route inventory document.                                                        | Implementation team                      | Open                                                                            |
| G-003       | GAP           | High              | Major               | Consolidated threat model was missing.                                                                               | Current package `08_threat-model.md`                                                                              | Security review lacked one vendor-facing map.                                                                                            | Expand threat model as incidents or features change.                                          | Security vendor / internal security      | Open                                                                            |
| G-004       | GAP           | Medium            | Major               | Cookie/session/token owner matrix was missing.                                                                       | Current package `04_cookie-session-token-matrix.md`                                                               | Transport and authority were easy to conflate.                                                                                           | Keep the matrix synchronized with authority docs.                                             | Internal architecture                    | Open                                                                            |
| G-005       | GAP           | High              | Major               | Identity incident/key rotation/rollback runbook is missing or fragmented.                                            | `docs/security/*`, `docs/runbooks/*`                                                                              | Recovery actions are not centralized for vendors.                                                                                        | Create or consolidate a runbook later.                                                        | Operations/SRE                           | Open                                                                            |
| G-006       | GAP           | Medium            | Major               | Failure/dropout/retry taxonomy was missing.                                                                          | Current package `06_failure-taxonomy.md`                                                                          | Failure handling was flow-specific and hard to compare.                                                                                  | Keep the shared taxonomy current.                                                             | Internal architecture                    | Open                                                                            |
| G-007       | GAP           | Medium            | Minor               | ASVS/vendor mapping is missing.                                                                                      | No dedicated mapping in the reviewed docs.                                                                        | Security vendor comparison is harder.                                                                                                    | Add a mapping if requested.                                                                   | Security vendor / internal security      | Open                                                                            |
| G-008       | GAP           | Medium            | Closed              | Vendor deliverables/questions list was missing.                                                                      | `docs/vendor/identity/01_responsibility_matrix.md`                                                                | Superseded by the responsibility matrix.                                                                                                 | Closed; use the responsibility matrix as the current vendor-facing authority.                 | Internal architecture                    | CLOSED - superseded by `docs/vendor/identity/01_responsibility_matrix.md`       |
| G-009       | GAP           | Low               | Closed              | Japanese/internal notes were not vendor-ready.                                                                       | `docs/vendor/identity/04_cookie-session-token-matrix.md`                                                          | Superseded by the cookie/session/token matrix.                                                                                           | Closed; use the artifact matrix as the current vendor-facing authority.                       | Internal architecture                    | CLOSED - superseded by `docs/vendor/identity/04_cookie-session-token-matrix.md` |
| G-010       | RISK          | High              | Major               | Frontend stack premise mismatch could cause false implementation claims.                                             | `adr/frontend-architecture-toolchain.md`                                                                          | Vendors may misread current browser stack.                                                                                               | Cite the frontend ADR and avoid claiming Hono/React Router without evidence.                  | Implementation team                      | Open                                                                            |
| G-011       | RISK          | Medium            | Major               | Historical vocabulary can mislead vendor reviewers.                                                                  | `docs/identity/authority-boundary.md` and older notes                                                             | Readers may infer outdated authority ownership.                                                                                          | Label historical vocabulary explicitly as historical only.                                    | Internal architecture                    | Open                                                                            |
| G-012       | RISK          | High              | Major               | Session/token authority vs Sign UI ambiguity can lead to unsafe implementation assumptions.                          | `docs/security/session-token-authority.md`, `docs/security/logout-sequence.md`                                    | UI hosting may be mistaken for authority.                                                                                                | Keep authority and UI hosting separate in all docs.                                           | Internal architecture                    | Open                                                                            |
| G-013       | OPEN_QUESTION | High              | Major               | Social linking policy needed explicit documentation before this package.                                             | Current package `07_social-linking-policy.md`                                                                     | Account takeover risk if policy is unclear.                                                                                              | Preserve the fail-closed, explicit-confirmation rule.                                         | Product/security                         | Open                                                                            |
| G-014       | CONTRADICTION | Medium            | Major               | Some docs use older `acme/www` or `sign/id` language while current vendor docs use Acme / Sign / Core / Base / Palm. | `docs/identity/authority-boundary.md`, `docs/security/*`                                                          | Mixed vocabulary can confuse external reviewers.                                                                                         | Keep vendor docs current-vocabulary only and note historical context separately.              | Internal architecture                    | Open                                                                            |
| G-015       | FOLLOW_UP     | Medium            | Major               | Identity runbook coverage should later include incident, key rotation, and rollback paths.                           | `docs/runbooks/*`                                                                                                 | Recovery guidance is fragmented today.                                                                                                   | Draft a consolidated runbook when scope allows.                                               | Operations/SRE                           | Open                                                                            |
| GAP-002     | GAP           | Critical          | Blocker             | Chronicle DB-level immutability absent; NR-004 requires DB-level prevention or detection of update/delete.           | `docs/vendor/identity/15_audit-log-integrity-requirement.md`, `docs/vendor/identity/11_decision-register.md`      | Critical audit events can be modified or deleted without DB-level prevention or detection.                                               | Select and implement DB-level append-only or tamper-evidence remediation.                     | Internal architecture / SRE              | OPEN                                                                            |
| GAP-NEW-001 | GAP           | High              | Major               | Recovery passcode verification has no rate limit / lockout.                                                          | `docs/vendor/identity/14_account-recovery-procedure.md`, `docs/vendor/identity/04_cookie-session-token-matrix.md` | Recovery passcodes lack abuse throttling beyond entropy and Argon2 storage.                                                              | Specify and implement rate limit / attempt lockout before production use.                     | Internal architecture / product security | OPEN                                                                            |
| GAP-NEW-006 | GAP           | Critical          | Blocker             | MFA reset UI DISABLED; 5 prerequisite conditions required before enablement.                                         | `docs/vendor/identity/14_account-recovery-procedure.md`, `docs/vendor/identity/11_decision-register.md`           | Account recovery cannot be enabled safely without runbook, state machine, abuse protection, audit requirements, and acceptance criteria. | Complete the five prerequisite conditions before enabling the UI.                             | Internal architecture / product security | OPEN                                                                            |
| GAP-NEW-007 | GAP           | Critical          | Blocker             | Catastrophic account recovery, all credentials lost, is undefined.                                                   | `docs/vendor/identity/14_account-recovery-procedure.md`, `docs/vendor/identity/11_decision-register.md`           | Users with all credentials lost have no defined recovery path.                                                                           | Define catastrophic recovery procedure, approval path, audit events, and acceptance criteria. | Internal architecture / product security | OPEN                                                                            |

# Contradiction Notes

- Historical docs still provide valuable evidence but should not be treated as current vendor-facing
  truth when they use retired vocabulary.

# Open Questions

- Which of the follow-ups should be promoted into stable docs versus an ADR or runbook.

# Open Decisions From The 2026-06 Auth Ceremony Review

The 2026-06 auth ceremony review (`docs/auth-ceremony/`, removed 2026-09-13) left these owner
decisions open. Its other findings are recorded as decisions in `11_decision-register.md` or were
since implemented (Turnstile hostname/action/replay binding, TOTP same-window replay protection).

- New email trust cooldown: whether to adopt it, for how long, and whether surfaces differ.
  Proposal: `plans/backlog/new-email-trust-cooldown.md`.
- Telephone AAL1: whether telephone OTP alone may establish AAL1 on `app` and `com`, or an
  additional verifier is always required, as on `org`.

# Related Documents

- `docs/vendor/identity/00_readme.md`
- `docs/vendor/identity/11_decision-register.md`
