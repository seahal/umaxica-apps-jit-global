# Repeated sign-out and RP refresh race verification

Recorded 2026-10-14 against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on `feature`.
The worktree had 1,057 changed or untracked paths. This check used only the ordinary Rails test
database manifest and ran with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset.

Command:

```text
for i in 1 2 3 4 5; do
  env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 \
    bin/rails test test/operations/sign_out_refresh_race_test.rb
done
```

All five independent runs passed: each reported 1 run / 10 assertions / 0 failures / 0 errors /
0 skips. The test verified separate PostgreSQL backend PIDs and the invariant that a refresh racing
sign-out cannot leave an active RP session or usable root/device parent. No database reset,
migration, isolated database, manual cleanup or guard bypass was used.
