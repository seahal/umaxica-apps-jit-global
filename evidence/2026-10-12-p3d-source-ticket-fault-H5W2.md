# P3d source/Ticket fault and retry check

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty at the start of this check. Existing staged, unstaged and
untracked changes were preserved. No reset, clean, stash, worktree, push, production operation or
shared database operation was used. The run-owned manifest was
`tmp/acceptance-isolated-20261010p8b-primary.json`, using the primary PostgreSQL host and four
workers.

## Fault journey collection

The Email sign-up source-audit integration exercises APP and COM source commits followed by
injected Ticket failures and identical HTTP retries. It checks that the consumed ceremony proof,
source binding and audit intent remain the committed facts, that retry is a receipt/recovery path,
and that changed or invalidated intent cannot authorize another operation. The Step-Up settings
collection exercises the analogous binding-failure and exact retry boundary for App, Com and Org
contacts.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from tmp/acceptance-isolated-20261010p8b-primary.json>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test \
  test/integration/contact_email_signup_source_audit_test.rb \
  test/integration/contact_settings_otp_atomic_commit_test.rb
```

Observed result: `28 runs, 1236 assertions, 0 failures, 0 errors, 0 skips` in 6.367 seconds.
A read-only PostgreSQL follow-up reported zero run-owned worker databases and zero active
sessions.

This closes the exercised Email source/Ticket fault and Step-Up settings retry subconditions for
the current dirty worktree. It does not claim a distributed transaction, every provider or
credential family, or all remaining CONTACT-4/5 cross-database paths. The public Telephone
sign-up fault journey remains covered by the existing
`telephone_signup_source_proof_retry_test.rb` evidence and should be reconciled with this result
before CONTACT-5 is marked complete. No raw code, secret or personal data was written to this
record.
