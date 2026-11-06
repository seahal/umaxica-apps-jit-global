# Standby OIDC context local inventory

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already contained 663 staged,
unstaged, or untracked paths before this record; existing changes were preserved.

Read-only Rails runner queries against Development and Test found zero App and Org OIDC
authorization transaction rows in each of the four OP Base databases. Development Org had no
Operator Sign In Flow rows. Test Org had 12 such rows and all 12 had a NULL
`authentication_context`; the query did not inspect any identity or authentication payload. No rows
were modified and no migrations or tests were run. Production and Neon were not accessed.
