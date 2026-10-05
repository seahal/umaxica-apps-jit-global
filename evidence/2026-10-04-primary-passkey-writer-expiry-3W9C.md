# Primary Passkey writer and expiry checks

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes affecting the results.

The shared primary Passkey verification path previously accepted an ACTIVE APP/COM credential at its `discard_at` deadline. A new actual HTTP regression reproduced a 200 response where 401 was required (seed 44718: one test, ten assertions, one failure). The test obtains public Base admission, redeems it through Auth GET/CSRF-protected POST and signs a real WebAuthn assertion. It supplies no ordinary Auth login or root credential.

Verification now selects the credential on the writer and holds the actor then credential locks through eligibility, signature/sign-counter verification, credential timestamp updates and Auth proof recording. It rechecks ownership after locking. APP/COM discard time is evaluated from the writer after locking; ORG has no discard column and retains its existing status/context policy. This adds no schema or response shape and no ordinary-page credential lookup.

The public HTTP test covers one microsecond before, at, and after expiry on both surfaces. The positive case records Auth evidence and increments the counter; refusal records no authentication method and leaves the counter unchanged. All cases confirm Auth root cookies remain absent. These cases isolate expiry using the public model writer-clock seam; they do not prove the new lock ordering under an independent concurrent primary request.

Final command: `bin/rails test test/integration/local_authentication_boundary_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb test/controllers/concerns/passkey_sign_in_flow_refusals_test.rb test/operations/identity_step_up_passkey_verification_committer_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb`.

Environment: `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, `POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket`, `PARALLEL_WORKERS=1`. Only the owned copied databases were used. No rebuild occurred. Result: seed 62741, 46 tests, 688 assertions, zero failures, errors or skips. RuboCop passed for the two changed Ruby files and scoped `git diff --check` passed. The last edit after this gate added assertion-separating whitespace only.

The ORG integration simulates provider token/JWKS HTTP while exercising actual JWT and Passkey verification. Browser/provider-live verification is unclaimed. Remaining Cookie challenge retirement is proposed in `plans/analysis/passkey-challenge-db-shape-proposal.md` and awaits data-shape approval. This evidence does not establish R01–R16 completion. OTP logging remediation remains excluded.
