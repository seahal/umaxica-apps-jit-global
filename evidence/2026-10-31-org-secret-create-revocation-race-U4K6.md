# ORG Secret creation and concurrent device revocation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A non-transactional test held the device row on one connection, observed a separate Secret creation connection waiting on a PostgreSQL lock, committed device revocation, and observed the creation refuse without a Secret or Step-Up consumption. Its synthetic records were removed by the test's cleanup.
- The focused race first passed with 1 run and 5 assertions. After formatting, the race and three Secret service files passed together with 25 runs and 99 assertions. RuboCop corrected formatting in the new test.
- This checks revocation-first creation only. Creation-first ordering, update/removal races, independent cross-database commit failures and target-specific Step-Up binding remain unverified.
