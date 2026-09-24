# Full-suite regression recheck

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing modified and untracked files were preserved.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted or modified.

## Full-suite command and result

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
bin/rails test
```

The Compose-backed full suite completed with:

```text
11530 runs, 73418 assertions, 1 failure, 0 errors, 8 skips
```

The failure was:

```text
Base::Com::Oidc::LogoutsControllerTest#test_post_logout_redirect_uri_registered_for_another_realm_never_redirects_externally
test/controllers/base/com/oidc/logouts_controller_test.rb:106
```

It observed the response body containing the test state value `xyz`, while the response remained a
successful non-redirect completion page. The test did not fail when rerun alone:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/com/oidc/logouts_controller_test.rb:113
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips

PARALLEL_WORKERS=1 bin/rails test test/controllers/base/com/oidc/logouts_controller_test.rb
7 runs, 36 assertions, 0 failures, 0 errors, 0 skips
```

The OIDC logout-focused collection, including all three Base realm controllers and related logout
services, also passed under the normal parallel threshold:

```text
52 runs, 277 assertions, 0 failures, 0 errors, 0 skips
```

## Classification

The failure was a test-observation defect, not a production logout defect. The assertion searched
the complete rendered HTML for the short value `xyz`; the response contains a random CSP nonce, and
the failing response's nonce happened to contain that substring. The test now inspects the public
Inertia props JSON instead, which excludes nonce markup while still proving that the untrusted state
value is not reflected in the rendered contract.

After that test-only correction, the focused Base com OIDC logout file passed with 7 runs / 37
assertions / 0 failures / 0 errors / 0 skips, and the Compose-backed full suite passed with:

```text
11530 runs, 73419 assertions, 0 failures, 0 errors, 8 skips
```

No production authentication or logout behavior was changed. No test was deleted, skipped, mocked,
or weakened; the assertion was narrowed to the actual public response contract to remove a random
nonce false positive.
