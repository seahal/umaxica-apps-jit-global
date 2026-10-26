# WU-16 authority-stop primitive — gate check and stop

- Date: 2026-10-25
- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`
- Worktree: about 268 uncommitted files of other in-progress work plus the uncommitted WU-10 change.

## Gate (two.md 6.6 step 4: WU-44 A44-1/A44-2 green before WU-16)

`evidence/2026-10-23-wu44-root-issuance-epoch-E4R4.md` recorded A44-2 as not run. A deterministic
A44-2 case was added to `test/controllers/concerns/root_issuance_recheck_test.rb`: `log_in` issues
the Root, then a withdrawal stop commits; the Root is no longer current
(`AuthenticationEpochValue.root_current?` false) and `OpIdentityEventInvalidator.call` revokes it.

`bin/rails test test/controllers/concerns/root_issuance_recheck_test.rb`:
`3 runs, 10 assertions, 0 failures, 0 errors, 0 skips`. The case was written against the existing
behavior; no Red run was recorded.

## Stop

No WU-16 schema or code change was made. BX-1 and the 5.8 v2 static guard require every Root or
Grant revocation to go through the primitive with a `cause` from `op_authority_stop_causes`
(`browser_logout`, `rp_initiated_logout`, `token_revocation`, `refresh_reuse`, `revoke_others`,
`credential_change`, `identity_stop`, `administrative`, `risk`). These current callers of
`AuthenticationLogoutCurrentSession` revoke Roots with reasons that have no recorded cause:

| Caller | Reason passed today |
|---|---|
| `SessionLimitResolutionTransactionable` (two sites) | `session_limit_selected_revoke` |
| `AuthenticationSelectedSessionRevoker` | caller-supplied (one chosen session) |
| `AuthenticationSessionRevoker` | `session_revoke_all` |
| `AccountSessionRevocation` | `logout_reason` |
| `EnforcementCaseApplicable` | `enforcement_<effect>` |
| `AuthenticationBase` (DBSC refresh failure) | `dbsc_refresh_failed` |
| `AuthenticationBase` (root refresh invalidated) | `refresh_token_invalidated` |

Open owner question: which cause and scope applies to each row (an existing value, for example
`revoke_others` or `administrative`, or new cause values), and is each of them inside the BX-1
static guard? WU-15's sender depends on the stop record and was not started.
