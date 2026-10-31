# Social authentication candidate binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The focused pre-change store and contract files passed 19 tests and 131 assertions. A new candidate-subject mutation test then failed before the fix (1 run, 1 assertion, 1 failure): fetch accepted the modified subject.
- Reads now recompute the existing keyed digest and compare it in constant time, and require the payload provider to match the stored provider. Consumption and validation share a transaction so a rejected corrupt candidate is not consumed.
- The candidate store, contract, Auth completion and social-link integration files passed: 39 runs, 279 assertions, no failures or errors. RuboCop passed for the changed service and test.
- The existing digest joins fields with colons and does not cover audience, verification time or authority. This change preserves that persisted format; a versioned, unambiguous format proposal is awaiting review. The tests modify local candidate records, not provider responses or deployed state, and do not prove the complete XDB-12 failure matrix.
