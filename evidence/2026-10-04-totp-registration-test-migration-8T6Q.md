# TOTP registration tests migrated to canonical admission

Verified on 2026-10-04 against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated shared-worktree changes. Rails commands used the owned isolated manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, APP ticket-only preparation and one worker. No shared database or reconstruction was performed.

The legacy TOTP registration cases now create explicit Base bootstrap permission, accept the opaque reference through Auth GET/POST and exercise the existing DB candidate. They clear the request session/cookies and send no Auth root headers. GET/repeated enrollment retain the candidate/deadline/failure count; cancellation terminates the exact permission and requires a new Base admission. Stale candidate confirmation is rejected. Successful first-code verification creates no credential or freshness on Auth; the public Base final operation creates it once and preserves title/first-window time. Separate integration coverage still exercises the actual Base root-cookie journey.

The migration exposed two behavior regressions. The new verifier rejected the existing ASCII-space paste format; it now removes ASCII spaces and requires six ASCII digits, while letters and NUL remain rejected. A global missing-record handler changed private owner-scoped TOTP misses to 400; registration misses remain 400 and private management misses again return 404. No authentication, policy, CSRF or rate-limit hook was skipped.

The 31-case TOTP controller file remains 31 cases. Unused enrollment/Cookie/JWT-grant/social helper copies and preference constants were removed. Remaining legacy Auth management helpers are still present and are not end-to-end boundary evidence. QR/secret comparisons use digests rather than printing secret-bearing values. The GET slot-limit page retains its existing 200 information response; enrollment POST refuses the full limit with 422. Boundary cases cover one slot, two slots and attempted third insertion.

Observed isolation problems in the copied fixture data: a freshly auto-allocated Client had three existing Passkey rows, and an aggregate run refused bootstrap for another auto-allocated actor. These tests now use explicit independent identities without deleting retained rows. The underlying copied-data/sequence cause was not fully diagnosed. The new code-format partition test uses a separate actor per partition so it respects the three-session limit. Turnstile refusal controls the challenge verifier explicitly, rather than only its ordinary-verifier seam.

Commands used this environment prefix:

```sh
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3 POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/auth-boundary-isolated-20261003auth6f3.json POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket PARALLEL_WORKERS=1
```

- Five lifecycle cases: seed 50151, 5 tests/87 assertions, no failures/errors/skips.
- Success/paste/owner-miss cases: seed 5593, 6 tests/115 assertions, no failures/errors/skips, after reproducing paste rejection and the miss contract.
- Complete TOTP controller file: seed 17040, 31 tests/385 assertions, no failures/errors/skips, before final helper pruning.
- Final aggregate command: `bin/rails test test/controllers/auth/app/settings/passkeys_controller_test.rb test/controllers/auth/com/settings/passkeys_controller_test.rb test/controllers/auth/org/settings/passkeys_controller_test.rb test/controllers/auth/app/settings/totps_controller_test.rb test/operations/identity_totp_enrollment_issuer_test.rb test/operations/identity_totp_enrollment_verification_committer_test.rb test/operations/identity_totp_enrollment_final_committer_test.rb test/integration/totp_registration_boundary_test.rb --seed 12332`: **122 tests/1,030 assertions, no failures/errors/skips**. An earlier run of this gate had one fixture-history refusal, one fixture-capacity error and the new partition arrangement exceeding the session limit; the final result follows those isolation corrections.
- RuboCop inspected six changed Ruby files and corrected formatting; no outstanding offenses remained. Scoped whitespace check passed.

The earlier 18 legacy TOTP settings failures are resolved by this migration and the two production corrections. This does not close admitted credential management, Base Passkey candidates, primary challenge/JWT retirement, all protected consumers or the full suite. Browser checks remain user-owned; provider responses in existing integrated cases remain stubbed where documented. OTP logging remediation remains excluded.
