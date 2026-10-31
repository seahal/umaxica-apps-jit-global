# RP Logout Token validity interval

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- The existing clock-skew boundary case passed first (1 run, 9 assertions). A signed token with equal issuance and expiry then reproduced acceptance despite having no validity interval. The verifier now requires numeric times, expiry later than issuance, and a lifetime of at most 300 seconds.
- The new public-verifier cases cover reversed and equal times, 1/300/301-second durations, and a valid fractional NumericDate; together with the existing skew boundary they passed (2 runs, 15 assertions). An earlier attempt to construct string times failed in the JWT encoder before reaching the verifier; the encoder accepts numeric times, including fractions, and fractions remain accepted.
- The temporal validation, OP verifier, RP session revoker, and back-channel JWKS outage files passed together: 27 runs, 218 assertions, no failures or errors. Scoped RuboCop and `git diff --check` passed.
- This checks the verifier and selected consumers locally; it does not establish all RP endpoints, a live network delivery, or completion of WU-A8.
