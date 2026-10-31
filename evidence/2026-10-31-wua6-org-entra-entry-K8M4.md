# ORG normal Entra and emergency entry checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the checks.
- A targeted run of normal Entra and emergency entry cases first reported one failure: the baseline-listed normal sign-in page test followed an outdated admission flow and reached the binding confirmation redirect rather than the sign-in page (4 runs, 17 assertions, 1 failure).
- Updated that test to use the existing admission-entry helper. The helper exercises Auth entry and binding attachment by HTTP, then confirms the Base binding directly; it is not a full browser journey through Base confirmation. The test retains its assertion that the ORG sign-in page offers the Entra provider entry. Its isolated run passed (1 run, 5 assertions).
- Ran both the ORG Entra sessions controller and emergency Passkey controller test files: 20 runs, 136 assertions, no failures, errors or skips. These are local test scenarios and do not establish a real external Entra provider round trip or deployed browser behavior. RuboCop and scoped `git diff --check` passed for the edited file.
- The full-suite result in `2026-10-31-two-full-suite-after-corrections-N5R8.md` predates this test change.
