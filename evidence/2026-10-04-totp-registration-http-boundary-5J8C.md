# TOTP registration HTTP boundary

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and concurrent Rails, Secret, localization and frontend work. No commit or deployment was made.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`; preparation selected `codex_integrity_20261003auth6f3_app_ticket`, with `PARALLEL_WORKERS=1`. Rails test commands ran sequentially. This continuation performed no additional schema rebuild.

`bin/rails test test/integration/totp_registration_boundary_test.rb test/controllers/base/identity_read_only_pages_test.rb test/controllers/auth/step_up_admission_test.rb` passed: **24 runs, 332 assertions, no failures/errors/skips**, seed 39925.

The combined fifteen-file authentication regression selection passed: **115 runs, 1205 assertions, no failures/errors/skips**, seed 49935. It comprises the thirteen files listed in `2026-10-03-bootstrap-totp-base-finalization-9C5B.md`, plus the new TOTP registration integration file and Base identity read-only page tests.

Coverage includes real APP local Base login, bootstrap admission, encrypted pending TOTP candidate, first-code confirmation, opaque result transport, Base credential creation and repeat completion, absence of registration freshness, subsequent separate TOTP assertion, and return to the protected birthdate page. Auth receives no root cookies. Other cases reject missing or normal-purpose registration continuity, retain candidate expiry and failures across redisplay/restart, cancel the exact transaction, and exercise independent COM/ORG setup admission and cancellation. A real CSRF check refuses an untrusted cross-site origin with HTTP 422 without consuming admission; the legitimate HTTPS origin then accepts the same reference. Jump and Turnstile are stubbed; cryptographic TOTP validation is real. Time is controlled through public clock boundaries for the subsequent TOTP window.

`bun run test spec/pages/auth/app/settings/totp_enrollment_start.test.tsx spec/pages/auth/app/settings/settings_screens.test.tsx spec/pages/auth/app/settings/settings_screens_interaction.test.tsx` passed: **29 tests** across three files.

RuboCop passed on the changed authentication slice after corrections; the final five-file check covers both new queries, the TOTP controller and concern, and the new integration test. `git diff --check` passed before this documentation update.

The full R01–R16 implementation remains incomplete. Passkey registration, later registration and credential changes, Base-owned initial contacts, registration audit/notification, selector invalidation, legacy retirement and the remaining consumer/race/fault campaign are outstanding. Old Cookie-based TOTP controller tests have not been migrated or run in this slice. No full-suite, browser, live-provider, independent-connection race or actual principal-commit fault result is claimed. The earlier schema-drift gate remains non-green because shared uncommitted snapshots differ. Browser verification is user-owned, OTP logging remediation is excluded, and APP Email primary JSON success changes remain held.
