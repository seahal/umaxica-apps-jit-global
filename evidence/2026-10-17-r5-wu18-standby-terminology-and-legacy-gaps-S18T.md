# R5-WU18 Org Standby terminology and closed legacy gaps (partial)

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree has the uncommitted R4/R5 changes that
  are the subject here.
- Date: 2026-10-17T13:45:42Z

## Delivered

- Org alternative-auth context renamed to Standby:
  `AuthenticationContextValue::STANDBY_KEY = "standby"`, `standby?`,
  `standby_authentication_context?`, `OrgStandbyAccessPolicy`, `SignOrgStandbyPasskeyCeremony`;
  consumers updated. The pre-R5 `emergency` claim value now resolves to UNKNOWN and is refused (new
  test in `test/values/authentication_context_value_test.rb`).
- Migrations `20261017140000` in op_base_org (operator_sign_in_flows, operator_tokens) and
  op_base_app/op_base_com (sign-in flows) convert stored `emergency` to `standby` and replace the
  CHECK constraints. Applied to the development databases (`db:migrate:op_base_<realm>`) and the
  test fleet `codex_integrity_20261017c1a2_*`. Structure dumps were patched to exactly the two
  constraint lines and the version; a fresh dump of the development database was not used because it
  differed from the checked-in dump in unrelated `NOT VALID` foreign keys.
- Kept unchanged on purpose: public URLs `/sign/in/emergency/...` and their controllers, challenge
  purpose `emergency_sign_in`, user-facing copy, and unrelated Emergency mechanisms (identifier HMAC
  emergency rotation, TokenEmergencyService, emergency session revocation events,
  ClientEmergencySignInOperation). Documented in docs/security/org-emergency-access.md.
- docs/mermaid/idp-state-machine-storage-topology.md constraint excerpts updated.
- Legacy/unwired R5 pieces closed: cell callbacks verify the ID Token with `OidcOpIdTokenVerifier`
  against the OP JWKS; `OpOutboxDispatchJob` and a new `OpIdentityEventSweepJob` are scheduled in
  config/recurring.yml (development and production).

## Results

- Affected suites (values, models, auth/org controllers, presenters, concerns, policies, resolvers,
  operations, two integration files): 6385 runs, 0 failures, 0 errors.
- Palm cell callback with the JWKS ID Token verifier: 37 runs, 0 failures.
- `OpIdentityEventSweepJob` tests (window boundary inside/outside, applied, empty): 9 runs with the
  invalidator tests, 0 failures.

## Not done in WU18

- Removing the old OP-chain RP authentication path: the `shared` role still uses it until R5-WU19
  cutover; removal follows that cutover.
