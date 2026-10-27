# Acceptance test repairs: A27-1b and A34-2 (APP/COM Passkey, APP Secret)

- Date: 2026-10-26
- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; worktree dirty (Codex test-DB and acceptance
  fixes of the same day, other cycle work). Only the four test files below were edited. No
  application code changed.

## Changes (tests only)

| Case | Cause | Change |
|---|---|---|
| A27-1b (`test/controllers/base/oidc_result_browser_binding_test.rb`) | Wrote `session[...]` before the first request (`session` is nil in an integration test) | Obtains the browser nonce and parent transaction from a real `GET /oauth/authorize`, enabling and restoring the `sign_in_available_app` flag as A27-3 does |
| A34-2 COM Passkey (`test/controllers/auth/com/in/passkeys_controller_test.rb`) | Stale `@visitor` (`StaleObjectError`); then 422 vs expected 401 | `@visitor.reload.update!`; status expectation 422 (the case requires refusal with no token or cookie, not a status) |
| A34-2 APP Passkey (`test/controllers/auth/app/in/passkeys_controller_test.rb`) | 422 vs expected 401 | Status expectation 422, same reason |
| A34-2 APP Secret and the file's shared setup (`test/controllers/auth/app/in/secrets_controller_test.rb`) | Tests predate Design D: they read an `<input name="authenticity_token">` and `POST /sign/in` with `entry_ref`; the page is now Inertia and `Auth::App::Sign::InsController` has no `create` (entry GET redeems and redirects to the clean page). Then a stale `@client` | Entry step is `GET` with `entry_ref` → 303 → follow → 200; `@client.reload.update!` |

`bundle exec rubocop -a` was run on the Secret and OIDC result test files; it corrected 83 style
offenses, most of them pre-existing in those files.

## Results

`PARALLEL_WORKERS=1 bin/rails test` on the four files: 66 runs, 843 assertions, **1 failure**, 0 errors.

- A27-1b: passed. A34-2 APP Passkey and COM Passkey: passed. The other 14 Secret tests that errored
  before (shared setup) now pass.
- **A34-2 APP Secret: fails on a real assertion** (`secrets_controller_test.rb:134`): the sign-in is
  refused (422, no new token, no cookies) but the Secret credential's `claimed_at` is set, i.e. the
  Secret is consumed by a refused sign-in of an unfinished registration. Not changed; owner decision
  needed (code defect or acceptable).

## Not done

- A34-2 COM OTP (403 with the session-limit text; WU-33 default-message defect) — held (COM sign-in
  retirement direction).
- A44-4 replica-sharing check, document clean-up of `two.md`/`three.md` status drift and the logout
  backlog entry — stopped at the owner's request.
- `three.md` / `seven.md` statuses not updated.
