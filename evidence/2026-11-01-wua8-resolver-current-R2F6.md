# WU-A8 Base Zenith resolver current-state check

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (567 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- Current code contains `BaseZenithIdentityResolver`. It validates the valid Browser RP access
  state, exact Base cell/client, issuer, realm, subject, SID and active local session, then decodes
  the typed `OidcSubject`, reads the matching Zenith Client or Operator by `public_id`, checks actor
  eligibility, and re-encodes the subject for exact equality. The Base APP/ORG controller overrides
  call it from `preference_write_actor` when running in an RP role.
- The resolver test file covers both realm success cases, changed subject, wrong RP cell, suspended
  actor, unsupported surface and unauthenticated state. The current direct resolver suite passes. A
  prior run with global fixtures failed before the test body on a Bureau ownership FK to an absent
  Operator row; the self-seeding test now disables global fixtures and ensures its required
  Client/Operator references explicitly.
- Scope limitation: this does not establish that every Base identity-management action resolves or
  authorizes against the canonical Zenith actor. `two.md` §6.4 calls for Base canonical resolution;
  `docs/security/role-secret-isolation.md` assigns RP-cell identity to a local principal and states
  the canonical actor is OP-owned. This conflict needs contract reconciliation before expanding
  resolver use.

## Verification

- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer RAILS_ENV=test bin/rails test test/resolvers/base_zenith_identity_resolver_test.rb`
  — 6 runs, 19 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/resolvers/base_zenith_identity_resolver_test.rb` — 1 file inspected, no
  offenses.
- `ruby -c test/resolvers/base_zenith_identity_resolver_test.rb` — Syntax OK.
- `git diff --check -- test/resolvers/base_zenith_identity_resolver_test.rb` — passed.

No application behavior, schema, or migration was changed in this slice. Tests ran only against the
local test databases; production and Neon were untouched.
