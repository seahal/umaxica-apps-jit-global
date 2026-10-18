# Auth back/cancel/plain-text transition audit

Commit: e423890e7357e1fa7975eac45aeacdb416b3bce9. The worktree had unrelated uncommitted changes (including the staged removal of the
session-limit cancellation endpoints); results below were observed with those changes present.

## Changes verified

- Org session-limit page no longer offers a link back to the sign-in form. Authentication has
  already succeeded and a restricted session exists at that point; the DELETE cancellation is the
  only exit, matching app and com.
- Settings passkey-options Turnstile failure (app, com, org) redirects to the passkey list instead
  of the client-supplied Referer.

## Commands

- Red before the change: the new org session-limit test failed on the back_link assertion; the
  three Referer tests redirected to `/sign/in/challenge`.
- `bin/rails test test/controllers/auth test/integration`: 2271 runs, 0 failures, 0 errors.
- `bun run test`: 87 files, 1055 tests passed.
- `bin/rails test`: 11854 runs, 0 failures, 0 errors, 2 skips (pre-existing).
- `bun run typecheck`: one error in `src/pages/base/org/avatars/show.tsx`, outside this change.
