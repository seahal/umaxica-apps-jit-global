# WU-A14 BL-19 candidate classification

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had 561 tracked paths with
  uncommitted changes and 281 untracked paths; none were staged. No commit was created.
- The first selected candidate run reported 29 runs, 66 assertions, 0 failures and 9 fixture-setup
  errors. The errors were `client_telephones.user_id` foreign-key violations while the Client Secret
  audit suite loaded fixtures. The local test-only database was then snapshotted and rebuilt;
  details and recovery command are in `evidence/2026-11-02-wua14-app-zenith-test-rebuild-T6K2.md`.
- After the rebuild, the selected candidate group passed: 43 runs, 408 assertions, 0 failures, 0
  errors, 0 skips. It included `social_pending_client_termination_test.rb`,
  `sign_up_passkey_termination_http_test.rb`, the external-return-target Tech case,
  `sign_in_path_browser_allowlist_test.rb`, `authentication_rate_limit_test.rb`,
  `client_secret_audit_delivery_job_test.rb`, and `connection_adapter_port_test.rb`.
- Added the exact historical signed-return candidate `https://evil.example.test/steal` to the public
  Base Welcome signed-target cases. The expanded case group passed separately: 7 runs, 7 assertions,
  0 failures, 0 errors, 0 skips. Ruby syntax, scoped RuboCop (excluding one pre-existing
  `Layout/EmptyLinesAroundClassBody` offense in the file), and `git diff --check` passed.

| Candidate                         | Current classification                                                                                                                                                                                                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| External signed return target     | Not reproduced in the current public contract. The exact historical URL and protocol-relative, backslash, empty, whitespace and NUL inputs resolve to the Dashboard rather than an external location. The Tech sign-in path does not carry external targets into its flow.                              |
| Outdated-browser status           | No current defect: Auth browser sign-in pages return the documented 406; Visa token and Core logout endpoints are not blocked by the browser-page gate.                                                                                                                                                 |
| Passkey-options rate limit        | No current defect: the admitted burst reaches the limiter and receives 429 with `Retry-After: 60`; the earlier 400 came from stale test navigation setup before the endpoint. See `evidence/2026-11-01-wua14-rate-limit-candidate-recheck-X8Q2.md`.                                                     |
| Secret audit delivery             | The current delivery suite passes, including paging past a conflicting event and the separate-commit lifecycle case. The earlier poison-page behavior was corrected in WU-A5; see `evidence/2026-11-01-wua5-audit-pages-F9S2.md` and `evidence/2026-11-01-wua14-secret-audit-lifecycle-commit-L6D8.md`. |
| Social pending-client termination | No current failure: Cancel, expiry and Halt retire pending Google and Apple clients without creating identities or Root tokens.                                                                                                                                                                         |
| Passkey termination response      | The current real HTTP lock-wait/curfew cases pass, including 409 at the terminal boundary and preservation of completed registration. The missing Binding argument found during triage was fixed; see `evidence/2026-11-02-wua14-admission-curfew-finalization-R6N2.md`.                                |
| IPv6 address classification       | No current failure: non-global IPv6 answers such as `fd00::1` are rejected before connection, while a global IPv6 address is pinned and accepted.                                                                                                                                                       |

- This classifies the BL-19 candidates checked here, not all WU-A14 or `two.md` acceptance. The full
  Rails suite was not run.
