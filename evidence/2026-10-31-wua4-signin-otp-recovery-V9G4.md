# APP Email sign-in recovery after queue refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- A request test injected queue refusal, verified the 503 page's delivery-unavailable description and its generated resend state, then POSTed that state to the existing resend endpoint. The endpoint returned success and the challenge generation changed. An initial assertion incorrectly omitted the existing `ri` query parameter; it was corrected to compare the endpoint path.
- This case and the existing public Back-after-delivery-failure test passed together: 2 runs, 30 assertions. The latter verifies cancellation of the Email challenge, rejection of its old code, and a still-pending OIDC parent; it does not claim that the parent ceremony is fully cancelled.
- Scoped RuboCop and `git diff --check` passed. No real email transport, browser execution, or full parent-cancellation operation was tested.
