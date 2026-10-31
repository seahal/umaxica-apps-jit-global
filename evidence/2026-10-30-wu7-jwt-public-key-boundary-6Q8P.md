# JWT registry verification-key boundary

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

The shared JWT registry previously put the active private EC key object in both the signing and public-verification slots for keyset issuers. The issuer builder now reconstructs the verification key from the already validated public JWK. Public lookup therefore returns an EC key without private material while the existing signing slot retains its private key. This applies to both current auth and preference keyset issuers.

Before the change, the registry and com JWT-shape tests passed: 42 runs, 280 assertions. After the change, those files plus the public-key invariant and com initialization tests passed: 71 runs, 667 assertions, no failures, errors, or skips. The invariant verifies that the public key has no private component and verifies a token signed by the matching private key for both issuers. RuboCop passed on the changed files.

This does not isolate private keys from other code in the same process and does not implement the required realm-specific Preference keysets, provisioning, distribution, or rotation. No key material was created or distributed by this change.
