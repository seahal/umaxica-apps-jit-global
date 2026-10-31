# ORG contact finalization device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A test issued and verified an ORG contact OTP, then passed a token read before its device association was changed. The focused test initially failed (1 run, 5 assertions, 1 failure) because a finalizer returned a result other than the required refusal.
- Both ORG contact finalizers now require the locked token still to name the locked device. The new Email/Telephone operation case and the two ORG registration controller files passed together: 53 runs, 373 assertions, no failures or errors. RuboCop passed for the changed files.
- This uses transactional fixtures and synthetic reassignment; it does not establish a production reassignment workflow, independent-connection timing, target-specific Step-Up, authoritative ORG contact audit, or Ticket-first commit order.
