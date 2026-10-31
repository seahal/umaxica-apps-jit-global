# Cancelled signup OTP code refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Extended the existing APP Email and telephone cancellation-before-delivery cases to submit the issued code to the corresponding verification committer after cancellation. Both return `inactive_flow`, without consuming the issued code.
- The focused cases passed: 2 runs, 24 assertions. The delivery-guard and committed-retry files passed together with `PARALLEL_WORKERS=1`: 28 runs, 292 assertions, no failures or errors. RuboCop and `git diff --check` passed for the changed test file.
- These sequential cases do not establish the independent-connection race, real transport timeout, or all XDB-14 requirements.
