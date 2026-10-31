# WU-A1 attached, unconfirmed admission while sign-in is blocked

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained staged, unstaged and
untracked changes affecting the run. Tests used local test databases; no production or Neon
database was targeted.

Added a public HTTP case for app and org: attach an unconfirmed admission while sign-in is allowed,
block sign-in, then request sign-in. Both return 503 with `Cache-Control: no-store`, while admission,
ceremony, sign-in flow and browser cookie snapshots stay unchanged. The assertion compares a boolean
to avoid exposing credential-bearing snapshots on failure.

Before adding the case, the existing sentry integration file passed: 1 run, 48 assertions. After
adding it, the integration file plus classification guard passed: 9 runs, 91 assertions. After
the final safe-output assertion edit, the focused case passed again: 1 run, 14 assertions. RuboCop
reported no offenses on the integration file. This covers this state transition, not all WU-A1 or
two.md acceptance. The six baseline org controller failures remain separately documented.
