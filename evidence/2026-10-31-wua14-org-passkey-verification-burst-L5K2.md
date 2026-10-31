# ORG Passkey verification burst limit

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application and tests.

The existing ORG Passkey verification burst-limit test used a removed Admission form. Before the edit, its focused run stopped with 1 error and no assertions. The test now reaches the ORG sign-in page through the current Admission redirects and direct binding confirmation. With no pending Entra transaction, the first five verification requests returned 422 and the sixth returned 429.

With the configured local test environment, the ORG verification and options burst cases passed together (2 runs, 20 assertions). RuboCop and `git diff --check` passed for the modified test file. This covers refusal and rate limiting without a pending Entra transaction, not a successful Entra-to-Passkey journey, a complete Base browser confirmation, sustained limits or the entire test file. No production code changed. Temporary raw test logs were removed.
