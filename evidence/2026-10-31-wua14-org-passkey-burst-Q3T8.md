# ORG Passkey options burst limit

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application and tests.

The existing ORG burst-limit test used a removed Admission form. Before the edit its focused run ended with 1 error before any assertions. The test now issues an OIDC transaction and Admission, follows the current Auth redirects, confirms the binding through its production API, and reaches the ORG sign-in page. With no pending Entra transaction, the first five options requests returned 422 and the sixth returned 429 (1 run, 10 assertions).

The APP and ORG burst-options cases passed together (2 runs, 23 assertions). RuboCop and `git diff --check` passed for the modified file. This checks the limiter for requests without a pending Entra transaction; it does not establish a successful Entra-to-Passkey journey or the other burst and sustained limit cases. The test confirms the binding directly, not through a complete Base browser journey. No production code changed. Temporary raw test logs were removed.
