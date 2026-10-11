# Refresh-token realm lookup hardening evidence

- Date: 2026-09-17 UTC
- Branch: `feature`
- Parent commit: `d8895d6b7`
- Working tree: pre-existing `README.md` modification and `misc.md`/`refactor.md` deletions were
  preserved and were not staged.

## Implemented check

`OidcTokenExchangeCoordinator` now passes the fixed Base OAuth endpoint realm to both refresh-token
resolution and rotation. `OidcRefreshTokenIssuer` maps `client`, `visitor`, and `operator` to their
explicit surface connection and RP-session class before lookup. A refresh request therefore cannot
search another surface's RP-session table before the realm/client checks; a missing or unsupported
realm fails closed without a surface lookup.

The affected direct surface tests now pass the realm explicitly. The realm-binding regression test
captures the public coordinator boundary and asserts that the selected realm reaches lookup before
rotation.

## Verification

- Ruby syntax checks for the changed operation, coordinator, and affected tests: passed.
- `bundle exec rubocop` for the six changed Ruby files: passed; no offenses.
- `git diff --check` for the changed files: passed.
- The affected Rails tests were attempted with isolated test Valkey variables, but Rails boot
  stopped before assertions because PostgreSQL host `primary` could not be resolved.

## Not verified

Real PostgreSQL per-surface lookup isolation, refresh rotation/replay behavior, and concurrent
refresh/revoke ordering remain unverified until the isolated PostgreSQL and Valkey test services are
available. No production or shared datastore was used.
