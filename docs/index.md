# Documentation Index

Repository documents are separated by purpose.

- `docs/` contains current, stable documentation for the single Rails app, its `app` / `org` / `com`
  surfaces, and the repository boundary with the separate regional codebase.
- `plans/` contains future work, proposals, drafts, migration plans, and backlog notes.
- `adr/` contains accepted architecture and design decisions, including rationale and tradeoffs.
- `notes/` contains non-authoritative ADR-adjacent notes and implementation handoff notes.
- `memos/` contains exploratory observations and rough analysis that do not affect implementation.
- `evidence/` contains records of verification that was actually performed - what was checked, how,
  what was observed, and what was concluded. Tests, validations, audits, security checks,
  performance checks, migration verification, and defect reproduction belong here.

Rules:

- Write repository documentation in English. Non-English text is allowed only for explicit
  localization material, translation fixtures, or quoted external sources where the original
  language matters. See `docs/reference/repository-language-policy.md`.
- Keep non-authoritative implementation notes out of `docs/`, `plans/`, and `adr/`; use `notes/`
  instead.
- Keep exploratory notes that do not affect implementation in `memos/`.
- Keep future-facing material out of `docs/`.
- Keep stable operational guidance out of `plans/`.
- Record major accepted design decisions in `adr/`.
- When a plan is implemented, update `docs/`.
- Keep intentions out of `evidence/`: it records work that was performed, not work that is planned.
  A check that could not be completed is recorded as such, with the reason and the partial result.
  `evidence/` is flat, holds only `.md` files named `YYYY-MM-DD-<topic>.md`, and never holds raw
  logs, screenshots, dumps, or other generated artifacts - summarize those in the record.
- Do not document `safe_path_from_encoded_rt` as an approved helper. It is deprecated; if this term
  appears while updating docs, remove it or replace it with signed `ReturnTargetToken` handling.

Current content-model references:

- `docs/architecture/umaxica-v1-architecture-lock.md` locks the v1 Identity / Account / Organization
  / Unit / Avatar / Group resource model, Avatar DB vs content DB boundary, actor snapshot
  exclusion, Avatar lifecycle states, known violations, and guard-rail scope before implementation.
- `docs/architecture/avatar-social-graph.md` records the Avatar-to-Avatar follow, block, and mute
  boundary and the current implementation gaps.
- `docs/architecture/model-database-inventory.md` is the current-state model/database placement map
  used for future authority and placement decisions.
- `adr/principal-zenith-physical-consolidation.md` records the accepted physical consolidation of
  `*_principal` migration history into matching `*_zenith` databases while retaining empty
  `*_principal` connection keys for future regional-ready storage.
- `docs/architecture/principal-zenith-membership-organization-placement.md` audits the ambiguous
  `Member` / `ClientMembership` / `Organization` cluster and the related runtime actor and OIDC
  connection rows.
- `adr/member-client-membership-organization-decomposition-before-placement.md` establishes the
  decomposition-first rule before any placement migration for that cluster.
- `docs/architecture/acme-sign-core-base-port.md`
- `docs/architecture/sns-subject-resource-grill.md`
- `docs/architecture/sns-subject-resource-decision-record.md`
- `docs/architecture/database-authority-placement.md`
- `docs/identity/authority-boundary.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/current_context.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/flat-ruby-source-layout.md`
- `docs/architecture/controller-boundaries.md`
- `docs/architecture/controller-lifecycle.md`
- `docs/architecture/avatar-account-bridge.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/i18n.md`
- `docs/architecture/preference.md`
- `docs/security/session-limit.md`
- `docs/security/authentication-remediation.md`
- `docs/security/action-policy-conventions.md`
- `docs/security/credential-gateway.md`
- `docs/security/ceremony-grant-result.md`
- `docs/security/session-token-authority.md`
- `docs/security/withdrawal-privacy-erasure.md`
- `docs/security/step-up-ceremony-delegation.md`
- `docs/security/webauthn-rp-id-origin-boundary.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/logout-session-management.md`
- `docs/security/preference-settings-authority.md`
- `docs/architecture/sign-settings-to-acme-identity.md`
- `docs/security/downstream-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
- `docs/qa/identity-authority-regression-checklist.md`
- `docs/security/credential-abuse-rate-limits.md`
- `docs/security/public-entrypoints.md`
- `docs/security/chain_seal.md`
- `docs/security/observability-boundary.md`
- `docs/security/db-write-allowlist.md`
- `docs/security/security-headers.md`
- `docs/operations/health-check.md`
- `docs/operations/search-engine-webmaster-tools.md`
- `docs/architecture/search-metadata-boundary.md` records deferred direction for search metadata and
  structured data; it is not an implementation contract.
- `docs/operations/external-scan-cadence.md`
- `docs/architecture/controller-boundaries.md`
- `docs/security/turnstile.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/step-up-mfa-status.md`
- `docs/security/mfa-reset-account-recovery.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/identifier-hmac-emergency-rotation.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/social-login-provider-scope.md`
- `docs/security/session-reset-policy.md`
- `docs/security/sign-withdrawal-and-membership.md`
- `docs/policy/signup-eligibility.md`
- `docs/security/redirect_targets.md`
- `docs/operations/container-engine-podman-notes.md`
- `docs/operations/development-host-port-exposure.md`
- `docs/operations/cloudflare-private-origin.md`
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
- `docs/operations/jump-rt-key-rotation.md`
- `docs/operations/jwt-key-rotation.md`
- `docs/operations/apple-second-key-runbook.md`
- `docs/operations/entra-org-login-runbook.md`
- `docs/runbooks/chain_seal_key_rotation.md`
- `docs/dictionary/README.md`
- `docs/dictionary/access-terms.md`
- `docs/dictionary/alphabet.md`
- `docs/dictionary/glossary.md`
- `docs/design.md` is this application's UI primitives and token layer.
- `docs/reference/digital-agency-design-system.md` records the Digital Agency of Japan Design
  System introduction (<https://design.digital.go.jp/dads/introduction/>) as external
  implementation reading for UI work.
- `docs/reference/api-design-standards.md` is the canonical contract for JSON API endpoints and
  carries **only rules backed by a published specification**: RFC 9457 Problem Details errors, RFC
  9110 status and negotiation semantics, RFC 3339 timestamps, RFC 9700 authentication practice, RFC
  9745 / RFC 8594 deprecation signaling, and the protocol endpoints exempt from those rules. Areas
  with no governing standard are recorded separately as decisions in
  `adr/api-error-format-problem-details.md`, `adr/api-collection-contract.md`, and
  `adr/api-versioning-and-client-conventions.md`.
- `docs/reference/feature-flags.md`
- `docs/reference/forbidden-rails-methods.md`
- `docs/reference/repository-language-policy.md`
- `docs/reference/ruby-static-analysis.md`
