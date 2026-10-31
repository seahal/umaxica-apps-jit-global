# APP signup OTP deadline at delivery and verification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- Before the change, the delivery guard file passed its existing cases (12 runs, 98 assertions). Synthetic transaction/Flow expiry mismatches were then delivered by both Email and Telephone guards (two focused failures). After guarding delivery, both verification committers still accepted fresh codes for the mismatched transactions (two focused failures).
- Both delivery guards now compare the locked transaction and Flow deadlines. Both verification committers lock the transaction and reject a mismatch before verification and again before Source failure-counter reset. Focused cases cover both channels and both fresh and already-verified evidence (4 runs, 54 assertions).
- An initial attempt to change a verified transaction directly failed because database triggers enforce terminal OTP immutability; the test instead changed its synthetic parent Flow expiry. No trigger or production data was changed.
- The two issuer files, delivery guard and concurrency files, and Email/Telephone controller files passed together: 172 runs, 1,790 assertions, no failures or errors. Scoped RuboCop and `git diff --check` passed.
- These are synthetic inconsistencies; the tests do not establish an actual production writer causing one, a real external delivery, or complete XDB-14 coverage.
