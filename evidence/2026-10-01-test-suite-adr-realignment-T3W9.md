# Test suite realignment with Home/Dashboard and Xper ADRs

- Commit: `91974b8b05ccda80afcb1beb3174ab48f4155889`, with a large uncommitted worktree (Xper
  bootstrap, Home/Dashboard boundary, locale bundle move) that affected the results.
- Date: 2026-10-01

## Starting point

`bin/rails test`: 12126 runs, 28 failures, 4 errors. `bun run test`: 87 files, 1059 tests passed.

## Decisions

The accepted `adr/home-dashboard-authentication-boundary.md` and the newest commit's Base roots
controllers were treated as authoritative (anonymous `/` 200, authenticated `/` 404, anonymous
`/dashboard` 404, sign-out returns to `/`, Home resolves `ri` without redirecting).

- Tests updated to that contract: sign route host stub (missing `xper_*`), sign-out destination,
  root region handling, `/dashboard` and authenticated `/` 404 expectations, `page_title(...)`
  detection, resolved architecture baseline entries.
- Code fixed: guest Preference return link pointed at the 404 Dashboard; Base root pages leaked the
  internal title `Base App/Com/Org`.
- Conflict between the 404 contract and `adr/invalid-browser-credential-recovery.md`: a refused
  access cookie's deletion was lost on the 404. Added `CredentialDeletionFinalizer` (Rack, outside
  the exception renderers) that appends only registered credential deletions absent from the final
  response; the ADR records the contract.

## Result

`bin/rails test`: 12132 runs, 0 errors; the one remaining failure (`ExplicitMethodVisibility` on the
new middleware) was fixed and the affected files re-run green (56 runs, 0 failures). The full suite
was not re-run after that last fix. `bun run test`: 87 files, 1059 tests passed.

## Not verified

The production exception path (`ShowExceptions` then `ApiProblemExceptionsApp`) was not exercised;
the test environment sets `consider_all_requests_local = true`, so 404s render through
`DebugExceptions`. The middleware does not depend on which renderer ran.
