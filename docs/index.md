# Documentation Index

Natural-language repository documentation for programmers, reviewers, maintainers, operators and AI
coding agents. Product-user prose belongs in [manuals](../manuals/README.md).

- [Knowledge architecture](reference/repository-knowledge-architecture.md): directory
  responsibilities, authority and maintenance.
- [Runtime compatibility](reference/agent-runtime-compatibility.md): shared guidance and vendor
  adapters.
- [Durable checklists](checklists/README.md): behavior that must keep working.
- [Risk management](risk-management/README.md): actual risks, responses and ownership.
- [Spec lifecycle](../specs/README.md): accepted changes, evidence and closure.

Write repository prose in English, following
[language policy](reference/repository-language-policy.md). Keep current descriptions aligned with
delivered behavior. A future design is not evidence of delivery. Historical evidence remains in flat
`evidence/` Markdown records named `YYYY-MM-DD-<topic>-XXXX.md`, with full commit hash and relevant
dirty-worktree qualification.

For current redirect guidance, use signed `ReturnTargetToken` handling rather than the deprecated
`safe_path_from_encoded_rt` helper.

Current content-model references:

- `docs/architecture/umaxica-v1-architecture-lock.md` records the v1 Identity / Persona /
  Organization / Unit / Avatar / Group resource model, Avatar DB vs content DB boundary, actor
  snapshot exclusion, Avatar lifecycle states, known violations, and guard-rail scope before
  implementation.
- `docs/architecture/avatar-social-graph.md` records the Avatar-to-Avatar follow, block, and mute
  boundary and the current implementation gaps.
- `docs/architecture/model-database-inventory.md` is the current-state model/database placement map
  used for future authority and placement decisions.
- `adr/principal-zenith-physical-consolidation.md` records the accepted physical consolidation of
  `*_principal` migration history into matching `*_zenith` databases. The retained `*_principal`
  connection keys are compatibility seams, not a regional-ready application store.
- `docs/architecture/principal-zenith-membership-organization-placement.md` audits the ambiguous
  `Member` / `ClientMembership` / `OperatorOrganization` cluster and the related runtime actor and
  OIDC connection rows.
- `adr/member-client-membership-organization-decomposition-before-placement.md` establishes the
  decomposition-first rule before any placement migration for that cluster.
- `docs/architecture/acme-sign-core-base-port.md`
- `docs/architecture/sns-subject-resource-grill.md`
- `docs/architecture/sns-subject-resource-decision-record.md` records the deferred Avatar/SNS
  boundary; it is not part of the current Persona/Organization authority implementation.
- `docs/architecture/database-authority-placement.md`
- `docs/architecture/persona-organization-authority.md` is the current surface-local Persona /
  Organization authority shape and phase-gated implementation reference.
- `docs/identity/authority-boundary.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/current_context.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/flat-ruby-source-layout.md`
- `docs/architecture/controller-boundaries.md`
- `docs/architecture/dashboard-navigation.md`
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
- `docs/security/inertia-history-and-props.md`
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
- `docs/security/authentication-capacity-admission.md`
- `docs/security/sign-in-first-registration-handoff.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/passkey-lifecycle-and-audit.md`
- `docs/security/app-com-withdrawal-timing.md`
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
- `docs/operations/postgresql-version-tracking.md`
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
- `docs/reference/digital-agency-design-system.md` records the Digital Agency of Japan Design System
  introduction (<https://design.digital.go.jp/dads/introduction/>) as external implementation
  reading for UI work.
- `docs/reference/action-button-labels.md` fixes the wording of proceed and cancel buttons, based on
  the Apple Human Interface Guidelines.
- `docs/reference/api-design-standards.md` is the canonical contract for JSON API endpoints and
  carries **only rules backed by a published specification**: RFC 9457 Problem Details errors, RFC
  9110 status and negotiation semantics, RFC 3339 timestamps, RFC 9700 authentication practice, RFC
  9745 / RFC 8594 deprecation signaling, and the protocol endpoints exempt from those rules. Areas
  with no governing standard are recorded separately as decisions in
  `adr/api-error-format-problem-details.md`, `adr/api-collection-contract.md`,
  `adr/api-collection-offset-pagination.md`, and `adr/api-versioning-and-client-conventions.md`.
- `docs/reference/feature-flags.md`
- `docs/reference/forbidden-rails-methods.md`
- `docs/reference/repository-language-policy.md`
- `docs/reference/ruby-static-analysis.md`
- `docs/reference/url-identifier-policy.md`
- [Identifier conventions](reference/identifier-conventions.md): scoped semantic column mapping,
  accepted decision owners and explicit incomplete transitions.
