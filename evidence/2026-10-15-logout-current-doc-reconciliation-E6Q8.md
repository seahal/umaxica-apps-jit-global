# Current logout evidence reconciliation

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application/test/documentation changes present.

Executed on normal Rails test databases:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_authority_first_logout_test.rb test/operations/sign_out_refresh_race_test.rb
```

Result: 6 runs, 220 assertions, 0 failures, 0 errors, 0 skips. The authority-first file covers
existing Base APP/COM, Base self-RP and Edit sequences and untrusted-origin refusal. The race uses
independent PostgreSQL connections to exercise sign-out against RP refresh.

Updated the logout security documents and Tech/Palm ADR implementation-status note to distinguish
these executed checks from still-unverified complete all-RP authority-flow/issuance-race coverage,
BCL removal and real-browser acceptance. No contract, deployment, database reset or isolated fleet
operation was performed. This is current-document maintenance required by Step 18, not a claim that
global acceptance is complete.
