# WU-44 remaining acceptance: A44-4 failure

- Date: 2026-10-26
- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`
- Worktree: already had unrelated unstaged and untracked changes before this task; those were
  preserved. This task added or edited only WU-44 tests, the A44-9 backlog entry, and the requested
  acceptance/evidence records.
- Scope: tests only; no application code, sign-out implementation, database schema, or test database
  rebuild was changed.

## Results

| Case | Test | Result |
|---|---|---|
| A44-2 | `test/controllers/concerns/root_issuance_recheck_test.rb:63` | Not run. Execution stopped after A44-4 failed. The test now checks browser-root and Access JWT refusal before the identity-stop apply, plus revocation after apply. |
| A44-4 | `test/services/oidc_access_token_authenticator_test.rb:77` | Failed: 1 run, 6 assertions, 1 failure. The test confirmed writer epoch `1` and test-replica epoch `0`; `OidcAccessTokenAuthenticator` returned `success=true` and authenticated the root. |
| A44-5 | — | Not run. Execution stopped after A44-4 failed. |
| A44-6 | `test/operations/wu44_root_epoch_revocation_contract_test.rb:8, 52, 108` | Not run. Execution stopped after A44-4 failed. |
| A44-7 | `test/security/invariants/root_token_creation_invariant_test.rb:15` | Passed: 1 run, 2 assertions. |
| A44-9 | `docs/backlog/2026-10-26-credential-version-recheck-at-root-issuance.md` | Deferred to the requested backlog entry; no implementation was attempted. |
| A44-10 | `test/concurrency/root_revoke_others_concurrent_login_test.rb:84` | Not run. Execution stopped after A44-4 failed. |

The initial A44-4 run stopped during global fixture loading because `client_chronicles.event_id = 36`
has no matching event row (`fk_rails_829f1830de`). No database rebuild was performed. The OIDC
authenticator test class does not use fixtures, so its fixture list was set to empty and A44-4 was
rerun to reach the assertion.

The failing result is observable at the OIDC authentication boundary. The actor writer query in the
test returned epoch `1`, while a separately configured test reading role held the matching actor at
epoch `0`; authentication nevertheless succeeded with a root at epoch `0`. The implementation
currently wraps `find_resource` in the writing role at
`app/services/oidc_access_token_authenticator.rb:130-133`. The result disagrees with the D-165
contract and needs an owner review before further WU-44 verification.

## Other verification

- `bin/rails test test/security/invariants/root_token_creation_invariant_test.rb` — passed, 1 run,
  2 assertions.
- `bin/rails test test/services/oidc_access_token_authenticator_test.rb -n '/A44-4/'` — after
  isolating the class from unrelated fixtures, failed as recorded above. Rails emitted the notice to
  prefer `-i/--include` over `-n/--name`.
- RuboCop and the remaining WU-44 test files were not run because the task directs work to stop when
  an acceptance test exposes a real defect.
- The full test suite and the test database rebuild were not run.
