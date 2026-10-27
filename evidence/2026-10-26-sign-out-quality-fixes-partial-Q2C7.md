# Sign-out quality fixes (partial, done by Claude while Codex was rate-limited)

- HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; worktree dirty with SO-1 … SO-5 and other cycle
  work. Instructions: `tmp/sign-out-quality-fixes.md`.

| Item | State |
|---|---|
| 1 Warp/Tech superseded expectations | Already migrated by Codex before it stopped; the four files pass (18 runs, 151 assertions) |
| 2 One outcome classification | Done in `SignOidcLogout#perform_oidc_end_session_logout`: rescues narrowed to `CommitOutcomeUnknown`, `PreconditionFailed`, `ActiveRecord::ActiveRecordError`, `OpAuthorityStopCommitter::Refused`; the persisted device state decides once (revoked → committed path, active → stop failure, unknown → indeterminate). `finish_oidc_committed_logout` rescues only `RedirectFailure`, `Umaxica::Valkey::Error` and the stop errors. `persisted_oidc_device_state` rescues only Active Record errors. Programming errors propagate |
| 3 Defensive presence checks | Done in `sign_oidc_logout.rb` only (`clear_auth_cookies!`, `Actor.clear`, `record_logout_audit` called directly; all three Visa logout controllers provide them, checked with `bin/rails runner`). Not done in `oidc_rp_logout_launcher.rb`, `authentication_logout_current_session.rb` |
| 4 No internal English text | Done. Red: `test/controllers/base/app/oidc/logouts_controller_test.rb` new case showed `id_token_hint is invalid`; now renders `sign.shared.sign_out.invalid_request` (en/ja) and logs `error_code` |
| 5 One Jump redirect | Not done |
| 6 Session marker | Not done |

Test changes caused by item 2 (injected failures now use the error classes the collaborators really
raise; no assertion removed): `oidc_current_device_logout_test.rb` — stop failure
`ActiveRecord::ConnectionNotEstablished`, notice store `Umaxica::Valkey::Unavailable`, Jump issuer
returns no token; `oidc_logout_enqueue_failure_test.rb` — enqueue failure
`ActiveRecord::ConnectionNotEstablished`.

Results (`PARALLEL_WORKERS=1`): three Visa logout controller files, current-device, enqueue-failure
and registered-RP matrix tests — 133 runs, 1,523 assertions, 0 failures, 0 errors. RuboCop on the
four changed files: no offenses. Full sign-out inventory and full suite not run.
