# WU-7 Warp com untrusted display cookies

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected the result.
- The selected signed Warp reader and read-only notice tests initially passed: 2 runs, 16 assertions. The Warp reader test now sends a valid signed display JWT, a host-only binding value, and an untrusted display cookie claiming affirmative consent categories and enabled Web Push.
- The rendered actor kept every consent category false and Web Push disabled while honoring signed display values. The request made no com preference-table SQL queries and emitted none of the four preference/binding cookies. The read-only notice test also passed. The broader Warp root and com initialization files passed: 39 runs, 512 assertions, zero failures, errors or skips. RuboCop passed on the modified test.
- This is a Rails integration check rather than a real browser or independent-process key-distribution test. Full-suite comparison remains outstanding. No migration or non-test purge was performed.
