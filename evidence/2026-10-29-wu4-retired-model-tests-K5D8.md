# WU-4 retired visitor model test cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes, including corporate model removal and these test changes.
- Removed 31 previously unmodified, visitor-only model test files whose corresponding application models had already been removed. They covered retired visitor credentials, status tables, actor-local preference options, sign flows and privacy/withdrawal models. The retained `VisitorOccurrence` and `VisitorOccurrenceStatus` tests were not removed. Larger or already modified visitor test files remain for individual assessment.
- Removed the retired corporate parameter from `test/operations/contact_registration_otp_bootstrap_finalizer_test.rb`, retaining all app success, denial, expiry and fault scenarios. `ruby -c` passed; a test run was not yet possible because the full suite held the test database lock.
- The ongoing `bin/rails test` had loaded the removed tests before these changes, so its eventual result will include their prior failures; static checks that read files during execution may observe the changed worktree. No completed suite result is claimed here.
- No production persistence operation or external write was performed.
