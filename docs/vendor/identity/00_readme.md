---
title: Vendor Identity Package README
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

This package is the stable vendor-facing documentation set for Umaxica identity and control-plane
behavior as evidenced by the current repository.

# Distribution Warning

- `notes/oauth2-1-compliance-gap.md` is INTERNAL ONLY.
- It must not be included in any RFI/RFP/vendor package.
- It contains stale vocabulary such as `sign.*` as AS.
- Vendor-facing authority is defined by `01_responsibility_matrix.md` and
  `13_normative-baseline.md`.

# Scope

It explains the current identity control plane, route ownership, ceremony boundaries,
cookie/session/token ownership, failure taxonomy, social linking policy, threat model, and review
criteria.

# Non-scope

This package does not authorize implementation changes. Application behavior is defined by
repository code and tests plus recorded decisions. Contradictions must be resolved through future
decisions, not silent implementation edits.

# Source Evidence

Primary evidence used for this package:

- `config/routes/acme.rb`
- `config/routes/sign.rb`
- `config/routes/core.rb`
- `config/routes/base.rb`
- `config/routes/palm.rb`
- `test/integration/routes/acme_route_contract_test.rb`
- `test/integration/routes/sign_route_contract_test.rb`
- `test/integration/routes/core_route_contract_test.rb`
- `test/integration/routes/base_route_contract_test.rb`
- `test/integration/routes/palm_route_contract_test.rb`
- `test/integration/routes/oidc_discovery_route_stability_test.rb`
- `test/integration/routes/route_target_contract_test.rb`
- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/credential-gateway.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/turnstile.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/security-headers.md`
- `docs/security/observability-boundary.md`
- `adr/acme-sign-core-base-port-boundary.md`
- `adr/frontend-architecture-toolchain.md`

# Current Decisions

- Acme is the only IdP / Authorization Server.
- Sign is an RP gateway and ceremony UI, not the token or session authority.
- Core and Base are RP/BFF-style surfaces.
- Palm is a native/API client surface.
- `/oauth/*` is Acme-owned protocol surface.
- `/oidc/*` is RP/OIDC client flow where applicable.
- `/social/*` is social-provider callback / ceremony surface, not Acme OAuth token issuance.
- Social email match must not automatically link accounts.
- User-confirmed linking is required.
- Vendor-facing docs use current English vocabulary only.
- `docs/vendor/identity/` is the stable external handoff package.

# Open Questions

- Which currently open contradictions need new ADRs versus simple doc updates.
- Whether any missing route or flow evidence should be added in a future repository change.

# Related Documents

- `docs/vendor/identity/01_current-architecture.md`
- `docs/vendor/identity/01_responsibility_matrix.md`
- `docs/vendor/identity/02_responsibility-boundary.md`
- `docs/vendor/identity/03_route-endpoint-inventory.md`
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/06_failure-taxonomy.md`
- `docs/vendor/identity/07_social-linking-policy.md`
- `docs/vendor/identity/08_threat-model.md`
- `docs/vendor/identity/09_acceptance-criteria.md`
- `docs/vendor/identity/10_vendor-questions.md`
- `docs/vendor/identity/11_decision-register.md`
- `docs/vendor/identity/12_gap-risk-register.md`
- `docs/vendor/identity/13_normative-baseline.md`
- `docs/vendor/identity/14_account-recovery-procedure.md`
- `docs/vendor/identity/15_audit-log-integrity-requirement.md`

# Documentation Status

Draft vendor package, grounded in current repository evidence.

# Security and Secret Handling Warning

Do not copy secrets, tokens, cookies, or raw request values into vendor docs. This package records
facts about the presence and handling of protected values, not the values themselves.

# Package Map

1. `00_readme.md` - entrypoint and reading guide.
2. `01_current-architecture.md` - current architecture snapshot.
3. `01_responsibility_matrix.md` - vendor-facing responsibility matrix and authority baseline.
4. `02_responsibility-boundary.md` - ownership matrix.
5. `03_route-endpoint-inventory.md` - routes and handlers.
6. `04_cookie-session-token-matrix.md` - artifact ownership matrix.
7. `05_authentication-flow-inventory.md` - flows and outcomes.
8. `06_failure-taxonomy.md` - shared failure vocabulary.
9. `07_social-linking-policy.md` - explicit social linking policy.
10. `08_threat-model.md` - initial threat model [DRAFT — context only — not normative].
11. `09_acceptance-criteria.md` - review and release criteria.
12. `10_vendor-questions.md` - vendor interview and review prompts.
13. `11_decision-register.md` - adopted and rejected decisions.
14. `12_gap-risk-register.md` - gaps, risks, contradictions, and follow-ups [UPDATED — verify before
    distribution].
15. `13_normative-baseline.md` - normative baseline and requirements.
16. `14_account-recovery-procedure.md` - account recovery procedure and blockers.
17. `15_audit-log-integrity-requirement.md` - audit log integrity requirement.

# Known Limitations

- Some route and flow details are evidenced by route contracts and sequence docs, not by a single
  consolidated architecture document.
- Some security controls are documented as current practice, but not every control has a dedicated
  acceptance test in the current repository snapshot.
- Hono and React Router are not evidenced as current implementation in the repository snapshot
  reviewed for this package.

# How Contradictions Are Recorded

When repository code, tests, and docs disagree, this package records the contradiction explicitly in
the relevant document and in the decision or gap register. It does not resolve contradictions by
changing implementation.

# How Open Questions Are Handled

Open questions are listed explicitly with the evidence that is currently available. Questions that
require product or security judgment remain open until a future ADR, plan, or implementation
decision closes them.
