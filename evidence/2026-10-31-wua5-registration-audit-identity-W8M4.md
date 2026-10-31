# Passkey registration audit identity

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the application, documentation and tests.

The registration operation previously accepted an audit event for `passkey.removed` or an explicit reference to another actor. Focused APP/ORG tests reproduced both gaps as two expected failures before the change. Registration now accepts only the existing signup or settings registration event names and refuses a nonempty actor reference that differs from the owner. All four inspected production call sites supply one of those event names and either omit the actor reference or supply the owner reference. No schema or existing outbox event shape changed.

With the configured local test environment, the registration operation, two registration-finalizer files and audit-delivery file passed together (43 runs, 217 assertions). A later focused registration-operation run including an additional APP signup success assertion passed (14 runs, 66 assertions). `bundle exec rubocop app/operations/passkey_registration_operation.rb test/operations/passkey_registration_operation_test.rb --format simple` passed, as did `git diff --check` for those files. The full suite, direct SQL writers and all WU-A5 failure windows were not verified.
