# WU-A4 TOTP enrollment display HTTP verification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- Two existing controller cases previously errored in their setup while looking for a removed admission POST form; both failure IDs are in the recorded baseline. Their setup now follows the confirmed admission's current HTTPS GET and redirect, then exercises the existing page and POST endpoints.
- The enrollment case checks creation and repeated display of the same candidate. After revoking its device, a subsequent HTTPS GET is refused with a 400, 401 or 403 response; its body contains neither the candidate's private key nor the original QR image, and candidate proof and parent status remain unchanged. The test confirms the binding directly; it does not exercise a complete Base browser confirmation or explicitly enable forgery protection.
- The two controller cases, enrollment query and the three enrollment operation files passed together (22 runs, 299 assertions, 0 failures, 0 errors, 0 skips). Scoped `git diff --check` passed.
- This does not establish independent-connection device-revocation races, the full HTTP verification/finalization matrix, or resolve the separate finalization commit-order and audit gaps.
