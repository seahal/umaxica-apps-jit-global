# APP reentry Email delivery binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A local queued-mail test initially failed: after a recovery Email binding was released, the notification still reached the test delivery transport (1 run, 4 assertions, 1 failure).
- The APP mailer now rechecks accessible, effective and verified Email binding under the Email lock immediately before delivering an existing recovery/withdrawal OTP. New tests cover release and loss of verified status after enqueue for both purposes; the existing APP success-path fixtures were updated to verified effective bindings.
- The notifier delivery, issuer, verifier and withdrawal integration files passed: 21 runs, 258 assertions, no failures or errors. RuboCop passed for the changed files.
- This uses the local test mail transport and transactional fixtures. Real SMTP, independent races, ORG delivery, recovery-case revalidation after OTP verification and full WU-A7 acceptance remain unverified.
