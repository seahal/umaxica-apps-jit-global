# WU-A8 RP request binding and local logout storage failures

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree already contained extensive uncommitted changes.
  `git status --short --untracked-files=all` reported 615 entries before this evidence file was
  added; unrelated work was preserved.

`RpRequestAuthenticator#bound?` now requires the stored RP identity binding and its OP session
anchor to match the fixed cell issuer, realm, and client ID, in addition to the verified token `sid`
and `sub`. Before the change, the new regression case changed the stored identity issuer and
reproduced acceptance (1 run, 1 assertion, 1 failure). After the change, the RP request
authenticator and Base Zenith resolver tests passed (14 runs, 36 assertions, 0 failures, 0 errors, 0
skips).

The Core APP RP-cell logout integration case now injects an `ActiveRecord::ConnectionNotEstablished`
at local session read and at the local revoke transaction boundary. Both requests return 503, retain
the live RP session and all three browser credential cookies, and make no RFC 7009 request. A
subsequent request in the same case commits local revocation before invoking the adapter and
redirects without an ID Token hint. The selected integration case passed (1 run, 33 assertions, 0
failures, 0 errors, 0 skips). These are application-level injected failures, not an actual database
outage.

Scoped RuboCop reported no offenses for the three changed Ruby files. Ruby syntax checks and
`git diff --check` passed. No full suite, external Visa request, migration, or production/Neon
operation was performed.
