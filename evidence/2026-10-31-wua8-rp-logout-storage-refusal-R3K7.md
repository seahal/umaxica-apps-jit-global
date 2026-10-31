# RP logout storage failure source review

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the logout concern; this review describes that worktree.

`OidcRpLogoutLauncher#resolve_rp_cell_logout_credentials` rescues `ActiveRecord::ActiveRecordError` and returns no credentials. Its caller `authenticate_oidc_rp_session!` renders HTTP 401 for an absent resolution, so this source path does not distinguish an RP-cell credential-read database error from absent or invalid credentials. Separately, `launch_oidc_rp_logout!` rescues database errors during launch and invokes an unavailable renderer; both implementations of that renderer currently return 422. `two.md` section 6.5 requires 503 when local revocation cannot commit.

This is source inspection only: no real database outage or HTTP request was injected, and no change to response behavior was implemented. The separate RFC 7009 connection remains outside this review.
