# WU-A8 per-cell RP logout follow-up

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 616 staged, modified, or untracked entries; the pre-existing work was preserved.

The RP request authenticator, Base Zenith resolver, and RP-cell integration files passed together:
34 runs, 341 assertions, 0 failures, 0 errors, 0 skips. This includes nine independent APP/ORG cell
sign-out cases. Each observes local session revocation before the RFC 7009 adapter receives the
Refresh Token, a registered Visa logout redirect without `id_token_hint`, cleared RP cookies, and
unchanged OP grant/root-token state. The separate Core APP storage-failure case continues to verify
HTTP 503, retained credentials, and no adapter call for injected local read/revoke exceptions.

An earlier single test loop switching hosts between cells returned 401 at Base ORG. The loop was
replaced with independent per-cell integration cases using the existing RP-cell session harness; all
nine then passed. The initial cross-host failure's cause was not isolated.

Scoped RuboCop on the authenticator and two test files passed (3 files, no offenses). Ruby syntax
and `git diff --check` passed. No full suite, actual database outage, external Visa call, migration,
or production/Neon operation was run. WU-A8 remains incomplete: the non-cell OP-chain branch,
RuntimeRole/caller removal, complete Base owner-isolation contract, and remaining §3.9 coverage are
still open.
