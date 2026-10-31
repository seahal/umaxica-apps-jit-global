# Secret claim under an outer Zenith transaction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the Secret claim operation and concurrency test; the result applies to that worktree.

A temporary case in the existing nontransactional Secret claim concurrency file opened an outer `AppZenithRecord.transaction`, called `ClientSecretClaimCommitter.call!`, observed a non-nil claim, and rolled the outer transaction back. The same Secret was then found by `ClientSecretLookupQuery` again. The focused probe passed: 1 run, 2 assertions. Its temporary test was removed after execution.

The source claim therefore is not guaranteed independently committed when a caller already owns the Zenith transaction. The direct application caller is `Auth::App::Sign::In::SecretsController`, which proceeds to authentication orchestration after a non-nil claim; its runtime surrounding transaction state was not established. The probe did not record authentication evidence, issue a session, or demonstrate an HTTP exploit. No fix was made.
