# WU-A6 policy-inventory test boundary documentation

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 560 staged, unstaged or
  untracked status entries when recorded; no commit was created.
- Inspected `test/unit/security/authentication_context_operation_inventory_test.rb`. It enumerates
  policy classes and public rule names, but calls `AuthenticationContextValue#permits_rule?` rather
  than invoking the policies or their public operations.
- Updated `docs/security/org-emergency-access.md` to describe that boundary and to leave AC-41's
  real Normal/Standby per-operation checks open. Updated `four.md` with the same disposition.
- `git diff --check -- docs/security/org-emergency-access.md four.md` passed. No test was run for
  this documentation-only correction.
