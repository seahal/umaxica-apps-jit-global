# ORG journey admission relay probe

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the ORG journey and admission code; the results describe that worktree.

With a temporary test-only second Passkey inserted after the registration redirect, the existing ORG journey's first expected admission form was absent because the Auth response was HTTP 303 (1 run, 54 assertions, 1 failure). A temporary test rewrite followed two GET redirects and attempted the Base confirmation GET; that request returned HTTP 400 (1 run, 56 assertions, 1 failure). Both temporary edits were removed afterward.

These observations do not establish why Base refused the request or whether a real browser journey is affected. The original baseline-listed test failure and the independent one-Passkey controller gate defect remain unresolved. No production implementation was changed.
