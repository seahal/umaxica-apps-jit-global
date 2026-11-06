# WU-A8 RP-local logout handoff

Work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was
already broadly dirty; `git status --short --untracked-files=all` reported 612 entries before this
evidence file was added. No commit, migration, production/Neon operation or live RFC 7009 request
was made.

The RP-cell logout launcher now captures a Refresh Token only when its parsed public ID matches both
the local binding `sid` and the verified access-token `sid`. It commits local-session revocation
before clearing RP credentials, then calls the registered Visa revocation adapter. The adapter uses
the registered client authentication method, puts the token only in the form body, limits the
request to two seconds and retries one transient network failure at most once. The
adapter/integration focused group passed 14 runs and 89 assertions; the HTTP adapter was stubbed in
tests.

Visa's no-hint end-session request accepts a return only when `client_id` and the exact registered
URI validate. With no usable OP device it stages no authority change and returns through Jump with
the request state; without a usable return it keeps the already-signed-out page. A no-OP-session APP
request and the existing active-session no-hint completion case passed in the follow-up selection (2
runs, 24 assertions). The service/controller group also passed 20 runs and 97 assertions after the
test supplied the required `ri=jp`. Its first attempt omitted `ri` and received the existing
region-normalization 302.

An additional active-OP request with a registered no-hint return was attempted using a simplified
test request header. It redirected to the end-session URL before reaching the expected confirmation
response, so that attempted test was removed. The active-OP confirmation-to-registered-return branch
remains unverified; the test did not assert its post-response authority state. No claim is made that
this branch passed.

The logout ADR, sequence and session-management documents, and SIGNOUT checklist were updated to
record the D-59 contract. These edits supersede the ADR's 2026-10-26 statement that RP sign-out
makes no revocation-endpoint call, while retaining its OP-wide root-stop and Back-Channel Logout
decisions.

Ruby syntax checks passed for the changed Ruby files. Scoped RuboCop passed for four files with no
offenses, and `git diff --check` passed for the changed tracked
documentation/controller/service/test files.

WU-A8 remains open. `OidcRpLogoutLauncher` still has a `rp_cell_process? == false` path that reads
the OP grant/logout hint and skips local-first RFC 7009. Cross-realm/ORG end-session acceptance and
the active-OP no-hint return remain unverified. The full suite was not run.

## Follow-up on the same HEAD

After replacing the simplified active-OP request setup with the existing authenticated Visa
integration setup, the no-hint OP confirmation-to-registered-return path passed (1 run, 16
assertions). The no-hint controller selection passed again (2 runs, 25 assertions); the
service/controller group passed (20 runs, 98 assertions); and the adapter/RP-cell readiness group
passed after the adapter refactor (14 runs, 89 assertions). This supersedes the active-OP return
`unverified` statement above. Ruby syntax, scoped RuboCop and the changed-file diff check were also
rerun; all passed.

A separate attempt to inject a local database commit failure by stubbing the initially loaded
session instance did not affect the instance reloaded by the request; it proceeded to the adapter
stub and failed with a test-stub `NoMethodError`. That temporary injection was reverted, and the
existing Core APP sign-out case passed afterward (1 run, 24 assertions). No authority-state
assertion was completed for the failed injection attempt. The runtime 503-before-cookie-clear
local-commit-failure case remains unverified.
