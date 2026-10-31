# APP recovery and withdrawal reentry Email binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Before the change, an APP recovery OTP remained verifiable after its Email binding was released (1 run, 1 assertion, 1 failure). A separate released-binding issuance test also failed because it created and enqueued a challenge (1 run, 1 assertion, 1 failure).
- APP recovery/withdrawal reentry issuance and verification now check the locked Email is accessible, effectively bound and in an existing verified status. The tests cover release and loss of verified status after issuance; existing APP positive tests were aligned to use verified effective bindings.
- Related issuer, verifier, withdrawal and recovery-entry files passed: 24 runs, 280 assertions, no failures or errors. RuboCop passed for the four changed files.
- An intermediate expanded test had a uniqueness error from reusing one Client for several effective Email bindings; separate synthetic Clients fixed the setup. Tests use transactional fixtures and do not verify independent races. The queued-mail delivery path, recovery-case revalidation through ceremony issuance, ORG behavior, explicit withdrawal state and full WU-A7 acceptance remain open.
