# WU-7 com schema worktree inspection

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contains staged, unstaged and
untracked changes. This is a source inspection, not a fresh database migration or deployment.

- The current com structure dump declares non-null generation, status and issuance timestamps;
  unique generation and public identifiers; and independent non-null binding, consent receipt and
  Web Push rows. The binding and receipt each have a unique preference index, and Web Push has a
  unique preference index and an option foreign key. The dump contains no `NOT VALID` foreign
  key declaration.
- Both `20261030120000_create_com_preference_web_pushes.rb` and
  `20261030164914_create_com_preference_browser_bindings.rb` are untracked; the com structure dump
  has both staged and unstaged changes. The dump lists both versions and the later foreign-key and
  status validation migrations. No staging, commit, migration or database mutation was performed
  during this inspection.
- This does not establish the complete lifecycle or the repository-wide schema-drift gate. The
  database status check permits only known IDs but does not prevent direct SQL from reactivating a
  retired parent, as documented in the earlier status-constraint evidence.
