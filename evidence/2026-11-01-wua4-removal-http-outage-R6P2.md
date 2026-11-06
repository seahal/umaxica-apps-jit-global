# WU-A4 XDB-07 HTTP removal outage and retry

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had extensive uncommitted changes;
this change was not committed.

The fixture-free APP credential-removal integration case now injects
`ActiveRecord::ConnectionNotEstablished` when `IdentityCredentialRemovalCommitter` updates the
Ticket Step-Up evidence. The actual Email DELETE returned HTTP 503. The Email remained verified and
bound, the Step-Up timestamp remained unchanged, and the same request with the same proof then
succeeded and released the Email binding.

Verification:

- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/integration/sign/app/credential_removal_constraints_test.rb:54`:
  1 run, 10 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop on nine implementation and other test files: no offenses. Ruby syntax checks passed
  for all ten changed Ruby files.
- `bundle exec rubocop` including the integration file reported three existing offenses outside the
  added case (one long teardown line and two layout offenses near the file end). `git diff --check`
  passed.

The default-transactional `Base::App::Identity::EmailsControllerTest` still cannot load its fixtures
in the current local test DB because of the previously recorded orphan `client_authority_locks` row
for Client id `980190963`. No database cleanup was performed. No full suite was run.
