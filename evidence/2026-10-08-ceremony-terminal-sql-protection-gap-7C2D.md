# Ceremony terminal SQL protection gap

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree contained uncommitted OTP ownership changes. No production connection, schema change or data mutation was performed.

`bin/rails test test/models/ceremony_otp_terminal_database_test.rb` ran against the normal local test fleet: 12 tests, 24 assertions, 12 failures, no errors/skips, seed 20744. Each independently generated and verified or cancelled APP/COM/ORG Email/Telephone ceremony permitted direct `update_columns` erasure of its terminal proof. The probes ran within test transactions. RuboCop passed for the new test after formatting.

Model terminal-proof validation does not cover direct SQL. Existing approved Source JSON proof triggers still protect the old storage, not the new ceremony columns. Removing them before equivalent ceremony protection would weaken the existing direct-SQL contract. A narrow request was sent for new migration-only functions/triggers on the six ceremony tables, preserving terminal proof and its original binding without new role grants, arbitrary flags, trigger disabling or existing-row rewrites. No such DDL has been executed or claimed complete.

Other authorized implementation work continues. This finding prevents final legacy-proof retirement and Definition of Done until the protection is implemented and these regressions pass.
