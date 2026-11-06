# Auth APP phase-bound Email browser history

Date: 2026-11-01 HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` Worktree: already contained
extensive uncommitted changes before this slice. They were preserved; no commit was created.

## Change

The Auth APP Email sign-in entry now submits as a CSRF-protected document POST. It sends the
server-provided address, Turnstile token and signed `pt` when present. The submit button disables
after submission starts to retain the previous duplicate-submit protection.

The Auth APP Inertia entrypoint reloads phase-bound sign-in entry paths when the browser restores
them through Inertia history. Server phase validation therefore receives Back navigation instead of
treating an Inertia-restored stale form as current. The authentication-flow checklist now links the
browser coverage.

## Checks performed

- `bun run test -- gait/features/auth/signin/signin_interaction.test.tsx gait/features/auth/signin/signin_screens.test.tsx`:
  2 files, 52 tests passed. A new resubmission assertion first failed against the implementation,
  then passed after the submit button state was restored.
- `bun run typecheck`: passed.
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium bun run test:e2e:rails -- e2e/rails/auth-phase-history.spec.ts`,
  with `.env.container.devcontainer` loaded: 2 browser tests passed. They exercised Back after APP
  sign-up OTP and Flow-less sign-in OTP, confirmed the stale entry returned 409 without
  authentication/DBSC response state, then exercised Forward; the sign-up journey also used explicit
  Cancel. The runner reported 51 configured test pools and 4/6 Valkey test databases reachable, then
  cleaned its Rails E2E scope and stopped Puma.
- Oxfmt check on the changed TS/TSX/E2E/config files passed; Oxlint on the changed TS/TSX/E2E files
  passed.
- Ruby syntax checks for the changed controller, controller test and E2E server passed. RuboCop
  inspected the controller and test (2 files, no offenses).
- `git diff --check` passed.

## Not established

- The focused Rails controller test at `test/controllers/auth/app/in/emails_controller_test.rb:208`
  did not reach its example: fixture loading stopped on foreign-key errors
  (`enterprise_units.enterprise_id`, then `clients`). No fixture-scope workaround was retained.
- Browser history restoration for the Secret entry path is wired to server reload but was not
  exercised in this browser test.
- The E2E journeys created synthetic local test records. No broad database cleanup was performed.
- The full Rails suite was not run; it remains reserved for WU closure.
