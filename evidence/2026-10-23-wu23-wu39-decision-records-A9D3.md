# WU-23 and WU-39: decision records and documentation amendments

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; documentation only,
  uncommitted. These record owner decisions of the authentication cycle; none of them claims the
  code already behaves this way unless stated.

## WU-23 (D-15, D-17, D-19, D-20)

- `adr/runtime-secret-isolation-deferred.md`: amendment "one credentials set in every environment;
  signing keys in AWS KMS" (KMS direction, `global` pod co-location Pending, production exposure as
  an accepted consequence).
- `docs/security/role-secret-isolation.md`, `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`:
  per-role design marked withdrawn.

## WU-39

- New ADRs: `adr/sign-in-path-continuation-protocol.md` (D-100, D-101), `adr/oidc-authorization-request-profile.md`
  (D-145 … D-149), `adr/rp-oidc-state-and-return-target.md` (D-149 … D-155, D-160, D-162); indexed in
  `adr/README.md`.
- Amended: `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`
  (10 min + 30 s, durable outbox via Solid Queue, `ActionController::API` receiver),
  `adr/authentication-security-cycle-consolidation-2026-10-15.md` §2.6 and
  `adr/authentication-security-mode.md` Open decision 1 (D-92, D-132),
  `adr/redirect-target-lanes-pt-nt-xt.md`, `adr/signed-return-targets-only.md` (RP lane),
  `docs/checklists/authentication.md` AUTH-1/AUTH-2,
  `.agents/harnesses/rules/generic/authentication-boundaries.mdc` (GET exception),
  `docs/security/sign-in-sequence.md` (one RP sign-in per browser, D-155),
  `docs/operations/jwt-key-rotation.md` (RP `state` key retention, OP key publication lead time).
- Passkey capacity ten was recorded earlier by `adr/passkey-authenticator-account-label.md` (D-171).
- Not in this unit: the Sign-up Finalization ADR (WU-05a).
