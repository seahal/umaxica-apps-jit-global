# WU-A8 RP-cell logout controller follow-up

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 630 staged, modified, or untracked entries when checked; no changes were
  committed.

`OidcRpLogoutLauncher` now has one local-session logout path for all RP cells. It resolves the
current Refresh Token only when its public ID matches both the verified Access Token `sid` and the
local session binding; commits local revocation before clearing RP cookies; then calls the RFC 7009
adapter and redirects to the registered Visa endpoint without `id_token_hint`. Local authentication
and revocation storage failures render 503. The old OP-grant, stored ID Token hint, and refresh-only
credential branches were removed from this concern. All RP logout controller callers now use the
single `client_id:` argument.

Updated controller coverage seeds real cell-local sessions, stubs the RFC 7009 adapter in-process,
and verifies no outbound call. Tech ORG coverage confirms sign-out remains available after Tech
capability revocation and refuses cross-site submission. Warp ORG coverage follows the surface's
`header_or_legacy_token` rule: same-origin Fetch Metadata is accepted, while cross-site metadata is
refused.

The combined focused run of the RP authenticator, Base resolver, local-session readiness, and all
affected RP sign-out/completion controllers passed: 77 runs, 804 assertions, 0 failures, 0 errors, 0
skips. Scoped RuboCop inspected 17 files with no offenses; `git diff --check` passed. No full suite,
production/Neon operation, or external Visa request was run.

WU-A8 remains incomplete: `RuntimeRole` and legacy branches in browser authentication, callback, and
Core browser API remain; Base owner isolation and remaining §3.9 acceptance are open.
