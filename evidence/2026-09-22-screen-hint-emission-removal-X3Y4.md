# First-party OIDC screen-hint emission removal

Date: 2026-09-22
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: pre-existing uncommitted changes were present; no unrelated changes were reset or
discarded.

## Change

`OidcSsoInitiator` no longer accepts or emits the unused `screen_hint` keyword. Current Core,
Side, and Edit first-party browser RP entrypoints therefore cannot reintroduce a
`screen_hint=signup`/`signin` choice through this shared initiator. The Auth sign-in and sign-up
routes remain separate internal ceremony capabilities. The deprecated `core-next-rp` Base
compatibility branch was not changed.

## TDD and verification

The first RED run changed the public request expectation before production code changed:
`9 runs, 79 assertions, 1 failure, 0 errors, 0 skips`; it observed the obsolete `signup` query
parameter. The implementation then removed the unused keyword and query emission.

Focused command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/oidc/sso_initiator_test.rb \
  test/integration/routes/neutral_rp_entry_contract_test.rb \
  test/integration/core_rp_browser_flow_test.rb \
  test/integration/oidc_rp_browser_flow_test.rb
```

Result: `35 runs, 434 assertions, 0 failures, 0 errors, 0 skips`.

Repository-wide command:

```text
bin/rails test
```

Result: `11531 runs, 73409 assertions, 0 failures, 0 errors, 8 skips`.

Additional checks passed:

* `bundle exec ruby -c app/controllers/concerns/oidc_sso_initiator.rb`
* `bundle exec ruby -c test/controllers/concerns/oidc/sso_initiator_test.rb`
* `bundle exec rubocop app/controllers/concerns/oidc_sso_initiator.rb test/controllers/concerns/oidc/sso_initiator_test.rb test/controllers/base/oauth_oidc_authority_test.rb`
* `git diff --check`

No external RP registration, key deployment, provider call, Cloudflare/AWS operation, or GitHub
write was performed.

