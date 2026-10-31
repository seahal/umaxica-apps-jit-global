# Credential mutation caller transaction review

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the affected credential operations and controller concerns; this review describes that worktree.

The direct application callers of `IdentityTotpNameCommitter` and `IdentityCredentialRemovalCommitter` found by source search are Base APP/ORG identity controllers. Both Base APP controller bases prepend `with_actor_lifecycle`; the implementation in `ActorSupport` yields and restores request-local state without explicitly opening a database transaction. This does not establish the runtime transaction state of the full request or other middleware, and it does not fix the previously reproduced outer Ticket transaction defect.

The transition inventory was corrected to reflect the independent-connection TOTP and APP/ORG Passkey failure checks and the observed outer-transaction rollback. No tests were run for this documentation correction.
