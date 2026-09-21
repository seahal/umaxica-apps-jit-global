# Step-Up secret credential boundary verification

- Date: 2026-09-20
- Scope: Base com/org direct secret credential management routes
- Worktree: existing dirty worktree preserved; no commit or external write performed

## Finding and change

The app direct secret credential controller already declared the shared Step-Up guard, but the com
and org direct controllers did not. Their dedicated removal endpoints were protected, while the
direct `destroy` route could bypass that boundary. The com and org controllers now use the same
bootstrap-aware guard for `new`/`create` and the same session-bound `settings_secret_credential`
guard for `edit`/`update`/`destroy`. No CSRF, authentication, authorization, or bootstrap control
was weakened.

## Reproduction and verification

Before the controller change, the new public integration tests reached the direct DELETE routes
without fresh Step-Up and failed with a 303 success redirect; both credentials were therefore
exposed to a deletion bypass. After the change:

- com direct deletion without fresh Step-Up: 401 and credential remains ACTIVE;
- org direct deletion without fresh Step-Up: bootstrap Step-Up setup redirect and credential remains
  ACTIVE;
- existing dedicated removal, credential-management, and settings-coverage behavior remains green.

Commands:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/com/identity/removals_controller_test.rb test/controllers/base/org/identity/removals_controller_test.rb test/controllers/base/identity_credential_management_test.rb test/integration/identity_settings_page_coverage_test.rb
```

Result: 19 runs, 138 assertions, 0 failures, 0 errors, 0 skips.

```text
bundle exec rubocop app/controllers/base/com/identity/secret_credentials_controller.rb app/controllers/base/org/identity/secret_credentials_controller.rb test/controllers/base/com/identity/removals_controller_test.rb test/controllers/base/org/identity/removals_controller_test.rb
```

Result: 4 files inspected, no offenses.

## Remaining boundary

The bootstrap path intentionally lets an actor with no usable Step-Up method enter the credential
setup ceremony. It does not authorize the sensitive operation without completing the prescribed
ceremony. Direct route behavior for live external identity providers was not exercised; repository
integration tests use local fixtures and test authentication helpers only.
