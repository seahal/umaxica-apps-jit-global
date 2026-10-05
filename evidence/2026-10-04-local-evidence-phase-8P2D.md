# Local authentication evidence phase

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes affecting the results.

The public local-flow evidence method previously accepted a principal-bearing flow after its credential phase, including session-limit and terminal states. APP/COM also accepted a still-fresh pending-MFA Cookie after the corresponding Base flow advanced to guardrail. The three new regressions failed before implementation (seed 24331: three tests, fifteen assertions, three failures).

`record_local_authentication_evidence!` now requires both the state and status predicate to identify PRIMARY_PENDING or MFA_PENDING, under its existing writer row lock. Other phases cannot introduce new authentication evidence. APP/COM pending-MFA validation additionally requires the admitted Base flow to remain MFA_PENDING and its principal to equal the Cookie's pending actor. The Cookie supplies continuity only; it cannot reopen a later phase or substitute another admitted actor. HTTP negative cases verify no challenge/evidence is created and stale pending state is cleared.

The model test enumerates every configured state for Client, Visitor and Operator flows through the public evidence method. Terminal test rows retain their required completion timestamps. The session-limit continuation test now records synthetic evidence during primary authentication before advancing to capacity wait, preserving the existing retry/timestamp contract.

Final command: `bin/rails test test/models/local_authentication_result_delivery_test.rb test/controllers/auth/app/in/mfa/passkeys_controller_test.rb test/controllers/auth/com/in/challenge/passkeys_controller_test.rb test/controllers/base/app/sign/in/limitations_controller_test.rb test/integration/local_authentication_boundary_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb`.

Environment: `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3`, owned-copy manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, `POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket`, `PARALLEL_WORKERS=1`. No schema rebuild, new persisted shape or response format was used. Result: seed 13822, fifty tests, 1,050 assertions, zero failures, errors or skips. RuboCop passed for the six changed Ruby files; scoped `git diff --check` passed.

The new actor-mismatch HTTP cases deliberately alter the owned test flow's principal as fault setup; they do not demonstrate a browser API capable of that mutation. Signature evidence is supplied by the separate actual-signature integration, while legacy MFA branch cases retain their explicit verifier stubs. Provider HTTP is stubbed in the ORG integration. Independent phase-transition races and complete R01–R16 acceptance remain unproven. OTP logging remediation remains excluded and browser verification remains user-owned.
