# RP cell local logout hint gap

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had substantial uncommitted changes affecting this check.
- The existing Core APP RP-cell readiness test passed (1 run, 3 assertions). It verifies authentication and refusal after a local binding revoke, not the browser sign-out action.
- A temporary HTTP integration probe used the existing RP-cell test harness to issue an OP-backed Core APP cell session, then posted the cell sign-out route. It observed 422, no redirect and a still-active local session (1 run, 4 assertions, no failures). The test log recorded `ActiveRecord::AssociationNotFoundError` for the sign-out failure. The temporary probe was removed.
- `OidcRpLogoutLauncher` looks up a `logout_hint` association before revoking the local session. `RpCoreAppSession` has no such association; the hint associations found in source belong to OP grant models. The local cell callback helper did not establish a persisted local hint. This is an implementation gap in the tested local path, not evidence about deployed systems or all nine cells.
- No external request was made. The correct storage and lifecycle of the ID Token hint, local revocation, RFC 7009 token capture and OP continuation remain unimplemented and need a coherent design. A persisted or serialized shape change is subject to the repository's explicit shape-review rule.
