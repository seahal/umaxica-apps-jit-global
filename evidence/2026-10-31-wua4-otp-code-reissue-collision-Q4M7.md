# OTP reissue numeric collision

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- A temporary local Minitest probe forced the random-number boundary to return the same six-digit value for consecutive issues of a single APP Email ceremony and a single APP telephone ceremony. In both cases the first value was accepted after the second generation was issued: 2 runs, 4 assertions, no failures or errors. The temporary probe was removed after execution. No actual OTP or credential was logged.
- The existing generation-bound verifier is replaced on issuance and the verification interface receives a numeric code without the generation; source inspection therefore explains the observed collision. The Auth Email sign-in issuer and verifier have the same relevant structure, but this probe did not exercise that path.
- Independent six-digit draws can collide; this check does not measure production frequency or test a proposed fix. Preventing only an immediately repeated value would not exclude the value from an earlier generation after two or more resends. No code or stored shape was changed in this check.
