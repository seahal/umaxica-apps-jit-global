# ORG contact OTP device checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The ORG contact operation test covers Email and Telephone OTP issuance and verification after a token is reassigned to another device, as well as finalization. It passed with 2 runs and 22 assertions; RuboCop passed for the test.
- The test uses transactional fixtures and synthetic reassignment. It does not cover ORG resend or delivery, real email/SMS, independent-connection races, target-specific Step-Up or cross-database commit failures.
