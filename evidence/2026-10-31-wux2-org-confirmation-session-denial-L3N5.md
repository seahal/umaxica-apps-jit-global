# ORG confirmation refusal diagnostic

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the ORG journey and admission code; the observations describe that worktree.

With the same temporary test-only second Passkey and GET relay from `evidence/2026-10-31-wux2-org-admission-relay-probe-N7W4.md`, a temporary exception diagnostic recorded the fixed denial classification and a fixed source-message category only. The Base confirmation request raised `session_binding_mismatch` from the `Base session does not match binding` check (1 run, 54 assertions, 1 failure). No reference, cookie or credential values were printed. All temporary test edits were removed.

The check fails when the current Base session token is absent, differs from the bound token, or is inactive. This probe does not distinguish those possibilities or establish their cause; it was not a deployed browser test. No production implementation was changed.
