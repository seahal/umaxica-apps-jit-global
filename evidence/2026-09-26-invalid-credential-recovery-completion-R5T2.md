# Invalid Browser Credential Recovery: Completion Verification

Commit: `310745dc291913c5b9baaae76738442c4ec9ff1d` (HEAD moved from `e423890e7` during the session).
The worktree had extensive uncommitted changes, including this task's changes and unrelated work.

## Database

`bin/rails test` ran with no extra environment. `primary` resolved to 10.89.0.3 and TCP 5432 was
open. `pg_postmaster_start_time()` was 2026-09-24 04:55 UTC, so the server was not restarted during
this session. The earlier failure (`evidence/2026-09-26-invalid-cookie-recovery-N4Q8.md`) could not
be reproduced, and its cause was not established.

## Defects found and fixed

- A refused auth access cookie was detached for policy states (`withdrawal_required`,
  administrative lock), which removed the credential those gates need.
- JSON requests with an invalid auth access cookie lost the existing 401 body.
- Preference `rotation_failed` was detached as a credential refusal; `unclassified` became a 401.
- A stale preference GET deleted the cookies of a newer rotated generation.
- `GET /edge/v0/cookie` with a refused credential inserted a preference row (second lookup after
  the cookie was deleted from the jar).
- A credential cookie with invalid UTF-8 raised ArgumentError (500) on auth and preference paths.
- The DBSC endpoint's `rescue StandardError` turned database errors into a missing token.

## Results

- Target set (auth matrix, preference matrix, parallel read, entry recovery, corrupt cookie, Core
  boundary, rescue inventory): 136 runs, 0 failures.
- Related set (`test/controllers/auth`, `test/controllers/concerns`, `test/security`, preference and
  refresh integration tests): 2230 runs; 3 failures in the auth token check fixed afterwards;
  `test/controllers/auth` plus the auth matrix then passed, 1140 runs, 0 failures.
- Full suite, run 1: 11957 runs, 1 failure (`StandardErrorRescueInventoryTest`, count 5 to 4 after
  the intentional removal of the refresh rescue). Inventory updated; it then passed.
- Full suite, run 2: 11965 runs, 5 failures, 4 errors, all in `Auth::App::Settings::TotpsControllerTest`
  and `Security::PublicEntrypointInventoryTest` ("Missing controller class for application route").
  The TOTP controllers, tests, and `config/routes/auth.rb` were modified at 16:20 UTC while the run
  was in progress, by work outside this task. These failures are not attributed to this change,
  and a green full suite was not observed.

## Not performed

- Real-browser cookie checks; `__Host-` names in the test environment (`force_secure?` is false).
- Threaded tests of rotating writes (chronicle audit rows are append-only and cannot be removed).
