# WU-A3 simultaneous initial-admission browser attempt

Date: 2026-11-01 HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` Worktree: already contained
extensive uncommitted changes; existing work was preserved and no commit was created.

The existing AC-53 integration case models two first admissions and both shared-cookie arrival
orders sequentially. A browser test was attempted to send both App sign-in entry requests without an
`auth_sid`, hold the responses, deliver their distinct cookies in order, refuse the losing target,
and redeem the selected target.

The first browser run failed before reaching Rails because the page route did not use the Rails E2E
host rewrite (`ECONNREFUSED`). After adding the same local host rewrite used by the E2E route
fixture, the second run reached Rails but the initial entry request returned HTTP 400 instead of the
expected HTTP 303. The cause was not isolated within these two attempts. The exploratory test and
its temporary fixture allowance were removed; the E2E file retains its previously passing two Email
history tests. The concurrent browser case remains unverified.

Both attempts created synthetic local OIDC issuance records before the browser request. The second
may also have created partial admission records; no broad cleanup or database reset was performed.
No production or Neon database was accessed. No full suite was run.
