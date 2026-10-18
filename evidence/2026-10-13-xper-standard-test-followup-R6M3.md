# Xper retirement standard-test follow-up

Date: 2026-10-13 UTC. Verification ran against full commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`. The worktree contained extensive unrelated changes,
the existing Xper retirement diff, and the scoped callback/test-fixture corrections described here.

The standard Rails test environment is now reachable and passed the Xper request acceptance without
an isolated database. The retired-host integration test passed 2 runs and 72 assertions. The twelve
shared regression selectors from `one.md` passed 146 runs and 4,950 assertions. Their combined
result was 148 runs and 5,022 assertions, with no failures, errors, or skips.

The first shared-selector run exposed two issues. The strict Base/Auth token callbacks had moved
ahead of the existing no-store and FQDN gates; all nine Base/Auth roots now restore the established
`no-store -> FQDN gate -> Rails CSRF -> required token -> surface callbacks` order. The host-family
value tests also omitted the already-required `PUBLIC_TECH_STAFF_URL`; their existing inputs now
include an explicit Tech host while preserving the missing-required-value case. The no-store
invariant passed separately (8 runs, 14 assertions), and the host-family tests passed separately
(14 runs, 75 assertions).

After the callback-order correction, the focused Base/Auth CSRF matrix passed 70 runs and 713
assertions, with no failures, errors, or skips. The Base preference tests cover same-origin absent
and invalid tokens on APP/COM/ORG, and same-site missing-token refusal. Auth admission tests cover
valid, absent and malformed tokens on all three surfaces. The test-wide forgery setting was not
changed.

AT-014/AT-015 source and boot checks also passed in this follow-up. With all six Xper variables
unset, development Rails boot found zero Xper routes, host fields, availability slots or allowed
hosts. A production-like `HostFamilyValues` build using explicit non-Xper host inputs passed and
contained the configured Tech host but no Xper fields. Static searches found no Xper routes,
controllers, views, layouts, stylesheet, frontend registration, host environment key or Compose
alias. The current Compose YAML parsed successfully and has no Xper aliases. No Compose service was
started.

All Rails tests used only the standard `test_*` database configuration, with
`POSTGRESQL_ISOLATED_TEST_RUN_ID` unset and `PARALLEL_WORKERS=1`. No isolated fleet, explicit reset,
or migration command was used. `bundle exec rubocop` inspected the nine affected Base/Auth roots and
the host-family value test (10 files, no offenses); `git diff --check` passed. Existing Xper
retirement documentation was not changed by this follow-up; the earlier Xper evidence records its
scope review.
