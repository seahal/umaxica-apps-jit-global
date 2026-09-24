# First-party OIDC screen-hint neutrality revalidation

Date: 2026-09-22
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: pre-existing uncommitted changes were present; this verification included the
first-party OIDC regression-test change and did not reset or discard unrelated work.

## Scope

The first-party browser RP contract was rechecked for the `app`, `com`, and `org` Base surfaces.
Both `screen_hint=signup` and `screen_hint=signin` were supplied to the public OAuth authorization
endpoint. Each request created a surface-local authorization transaction with the neutral
`authentication` intent and an `authentication` admission purpose. Auth's internal sign-in and
sign-up routes remain separate ceremony capabilities; the deprecated `core-next-rp` compatibility
client was not changed by this verification.

## Verification

Focused command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/oauth_oidc_authority_test.rb
```

Result: `42 runs, 243 assertions, 0 failures, 0 errors, 0 skips`.

Repository-wide command:

```text
bin/rails test
```

Result: `11531 runs, 73411 assertions, 0 failures, 0 errors, 8 skips`.

Additional checks passed:

* `bundle exec ruby -c test/controllers/base/oauth_oidc_authority_test.rb`
* `bundle exec rubocop test/controllers/base/oauth_oidc_authority_test.rb`
* `git diff --check`

No application authentication behavior, client registry, external registration, key deployment,
or deprecated compatibility client was changed in this slice.

