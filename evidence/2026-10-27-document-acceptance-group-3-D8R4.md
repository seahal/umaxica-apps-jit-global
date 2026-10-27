# Document-reviewed acceptance cases (A04-7, A23-1, A33-1, A35-1, A39-1)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes. Reading only; no document was changed.
- A04-7 Passed: `docs/security/turnstile.md` lines 147–164 list `PATCH /sign/up/check/email/otp` and
  `PATCH /sign/up/check/telephone/otp` for app and com (visible required), with the entry rows.
- A23-1 Passed: `adr/runtime-secret-isolation-deferred.md` (amended 2026-10-23: one credentials set,
  AWS KMS), `docs/security/role-secret-isolation.md` ("Withdrawn for every environment"),
  `plans/backlog/2026-10-18-production-runtime-secret-isolation.md` ("per-role design withdrawn").
- A35-1 Passed: `two.md` §6.2 (WU-35 report, D-139) covers Sign-up, Finalization, termination and
  cleanup, Admission redemption, root login and the named Re-verification committers; its scope
  excludes refresh/rotation, logout, revocation and avatar/group paths.
- A33-1 Partial: `two.md` §5.4 is titled "first pass"; ORG Passkey (Normal, Emergency) is "Not traced
  in this pass", and the rows give entry and result path but not the D-73 class and HTTP result per
  cell. Line references are from 2026-10-22 and were not re-checked.
- A39-1 Partial: each `two.md` WU-39 item has a written location — `adr/sign-in-path-continuation-protocol.md`
  (linked from `adr/README.md`); sign-out ADR "(10 minutes) plus 30 seconds" (D-111) and the
  `ActionController::API` receiver exception; Passkey capacity in the three passkey ADRs; D-92 in
  `adr/authentication-security-mode.md`; D-105 in `adr/sign-up-finalization-in-auth.md`;
  `adr/oidc-authorization-request-profile.md` (D-145/D-147); `adr/rp-oidc-state-and-return-target.md`
  (`target_link_uri`); D-155 in `docs/security/sign-in-sequence.md`; key-rotation timing in
  `docs/operations/jwt-key-rotation.md`. The check was by presence of the decision text, not a
  line-by-line consistency review against one.md.
- Not reviewed: A01-5 (already recorded as a Deviation, evidence L0R1) and A27-4 (diff review of the
  rewritten TR G2/G5/G3 tests).
