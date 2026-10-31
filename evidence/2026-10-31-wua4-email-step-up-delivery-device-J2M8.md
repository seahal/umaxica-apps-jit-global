# WU-A4 Email Step-Up delivery eligibility device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The delivery file passed before the change (4 runs, 22 assertions). New revoked-device and superseded-token cases failed before the change because queued messages were delivered (6 runs, 24 assertions, 2 failures).
- Delivery eligibility now checks the locked owner-bound device and current token. A job starting after revocation or token replacement returns false before invoking the local test mailer and leaves the generation pending.
- The issuer, delivery recorder, verifier and Auth Email controller files passed after the change (20 runs, 144 assertions, 0 failures, 0 errors, 0 skips). RuboCop still reports two existing hash-syntax offenses in `credential_valid?`; its method-size offense introduced during this change was resolved. The Email challenge diagram and inventory now describe the device check and unlocked SMTP boundary.
- SMTP remains outside the eligibility locks: revocation or cancellation after the check and before external acceptance may still allow a message to be sent. Independent-connection orderings, real SMTP and total transport deadlines remain unverified; verification now separately refuses an already revoked device.
