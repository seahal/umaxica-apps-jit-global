---
title: Identity Decision Register
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

# Namespace Note

The DEC numbers in this register are vendor-facing / VDR scope identifiers. They do not always map
1:1 to the procurement-internal DEC numbers of the original audit ledger.

For this remediation, vendor-facing DEC-012 corresponds to pinwheel DEC-012, vendor-facing DEC-013
corresponds to pinwheel DEC-013, and vendor-facing DEC-014 corresponds to pinwheel DEC-001/002.

# Purpose

Record the decisions that should govern vendor-facing identity documentation.

# Scope

This register includes adopted and rejected decisions relevant to the vendor package.

# Non-scope

This is not a full ADR replacement.

# Source Evidence

- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `adr/frontend-architecture-toolchain.md`
- `docs/vendor/identity/07_social-linking-policy.md`

| Decision ID | Decision                                                                                                                                                                                                                                                                       | Status   | Rationale                                                                                        | Consequences                                                                                       | Evidence                                                     | Revisit Condition                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| DEC-001     | Sign may host session-management UI, but Sign is not session/token/protocol authority.                                                                                                                                                                                         | Adopted  | Route and sequence docs separate UI hosting from authority.                                      | UI changes do not reassign authority.                                                              | `docs/security/session-token-authority.md`, route contracts  | Only if a future ADR changes authority.                                           |
| DEC-002     | Social email match must not auto-link accounts; explicit user-confirmed linking is required.                                                                                                                                                                                   | Adopted  | Email is not a stable identity key.                                                              | Prevents takeover by email collision.                                                              | `docs/vendor/identity/07_social-linking-policy.md`           | Only if a future decision explicitly changes linking policy.                      |
| DEC-003     | Current vocabulary is Acme / Sign / Core / Base / Palm.                                                                                                                                                                                                                        | Adopted  | Matches current architecture records.                                                            | Vendor docs must use current names.                                                                | `adr/acme-sign-core-base-port-boundary.md`                   | Only if repo truth changes.                                                       |
| DEC-004     | Current repo frontend truth is Rails + Vite + React/Inertia + Stimulus/Turbo. Hono / React Router are future/external unless repo evidence is added.                                                                                                                           | Adopted  | Frontend architecture ADR states current toolchain.                                              | Vendor docs must not claim Hono/React Router as current implementation.                            | `adr/frontend-architecture-toolchain.md`                     | Only if new repository evidence is added.                                         |
| DEC-005     | Vendor-facing docs use current English terminology only.                                                                                                                                                                                                                       | Adopted  | Repository language policy requires English for documentation.                                   | Historical vocabulary must be marked as historical.                                                | `docs/index.md`, repository language policy                  | Only if the repository language policy changes.                                   |
| DEC-006     | All identity ceremonies share a common failure/dropout/retry/timeout taxonomy. UI copy may remain flow-specific.                                                                                                                                                               | Adopted  | Gives reviewers one shared vocabulary.                                                           | Documentation and review can normalize states.                                                     | `docs/vendor/identity/06_failure-taxonomy.md`                | Only if a future decision requires flow-specific taxonomy.                        |
| DEC-007     | `docs/auth-ceremony` (removed 2026-09-13) was evidence-only. `docs/vendor/identity` is the stable external handoff package.                                                                                                                                                    | Adopted  | Separates working evidence from stable vendor docs.                                              | Vendor reviews should not rely on working notes alone.                                             | this package                                                 | Only if the documentation model changes.                                          |
| DEC-008     | Automatic social account linking by email match.                                                                                                                                                                                                                               | Rejected | Email alone is not a reliable identity key.                                                      | Must not be implemented or documented as current truth.                                            | `docs/vendor/identity/07_social-linking-policy.md`           | Only if a future security decision explicitly adopts it.                          |
| DEC-009     | Treating Sign as protocol authority.                                                                                                                                                                                                                                           | Rejected | Sign is a UI gateway and ceremony surface.                                                       | Avoids authority drift.                                                                            | `docs/security/session-token-authority.md`                   | Only if a new ADR reassigns authority.                                            |
| DEC-010     | Treating Hono / React Router as current repo truth without evidence.                                                                                                                                                                                                           | Rejected | Not evidenced in current repository snapshot.                                                    | Vendor docs must not describe them as current.                                                     | `adr/frontend-architecture-toolchain.md`                     | Only if repo evidence is added.                                                   |
| DEC-011     | Using historical `acme/www` or `sign/id` vocabulary in vendor-facing docs.                                                                                                                                                                                                     | Rejected | Current vendor docs must use current component vocabulary.                                       | Historical names should be labeled historical only.                                                | `docs/identity/authority-boundary.md`                        | Only if a historical comparison section is explicitly needed.                     |
| DEC-012     | Token endpoint null_session fail-closed. The token endpoint is a back-channel protocol endpoint. If null_session or missing protocol context occurs, it must return a deterministic OAuth error and must not issue tokens.                                                     | Adopted  | Token issuance must not depend on browser session state.                                         | Token endpoint behavior must fail closed and avoid token issuance when protocol context is absent. | `docs/vendor/identity/13_normative-baseline.md` NR-003       | Only if a future ADR changes token endpoint security behavior.                    |
| DEC-013     | Audit log integrity is a normative security requirement. Critical security audit events must be append-only at the application boundary. DB-level prevention or detection of update/delete is required. Application-level sanitization plus event_uuid UNIQUE is insufficient. | Adopted  | Critical audit events must remain trustworthy after recording.                                   | DB-level append-only or tamper-evidence remediation is required before this blocker can close.     | `docs/vendor/identity/15_audit-log-integrity-requirement.md` | Only if a future ADR replaces NR-004.                                             |
| DEC-014     | `notes/oauth2-1-compliance-gap.md` is non-authoritative, uses stale vocabulary such as `sign.*` as AS, and must not be distributed in any vendor package.                                                                                                                      | Adopted  | The note conflicts with current vendor-facing authority vocabulary and is internal-only context. | RFI/RFP/vendor packages must exclude this note and use vendor-facing authority documents instead.  | `docs/vendor/identity/13_normative-baseline.md`              | Only if the note is replaced by an accepted ADR or stable vendor-facing document. |

# Open Questions

- Whether the rejected items should be mirrored into a future ADR summary for external auditors.

# Related Documents

- `docs/vendor/identity/12_gap-risk-register.md`
