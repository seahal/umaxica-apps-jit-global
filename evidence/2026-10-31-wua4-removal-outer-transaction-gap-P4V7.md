# Credential removal inside an outer Ticket transaction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- A temporary nontransactional APP TOTP probe opened an outer OP transaction, invoked `IdentityCredentialRemovalCommitter.call!` with a valid target-bound Step-Up, then rolled the outer OP transaction back. The call reported removal, the Zenith credential remained `DELETED`, and the token's original Step-Up timestamp was restored: 1 run, 3 assertions, no failures or errors. The probe used newly created test records, removed its records, and was removed after execution.
- This confirms that the standalone commit-order fix does not establish the required order under an enclosing OP transaction: the nested locks join the caller's transaction, while the separate Zenith transaction can commit first. It does not establish that any production HTTP caller currently opens such a transaction or that a stale proof can authenticate a particular later operation.
- No production code was changed in this check. A fail-closed transaction boundary and its caller/test migration, or another design that proves an actual independent OP commit without lock inversion, remain unimplemented.
