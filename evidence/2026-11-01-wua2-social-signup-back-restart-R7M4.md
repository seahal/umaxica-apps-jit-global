# WU-A2 social sign-up Back and restart

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already contained a large set of
unstaged and untracked changes, including this work; no staged changes were present. No commit was
created.

The App Google and Apple sign-up provider POSTs leave the admitted first page without a
`ClientSignUpFlow`. Back keeps Cancel and Switch available. A successful verified provider callback
creates and advances one Flow while holding the Admission Binding before the Auth Ceremony lock, and
refuses when a prior Flow or cancellation owns the admission. A new provider POST consumes the
current session's previous callback state before issuing a replacement. Tests cover same-provider
restart, Google/Apple switching and Apple nonce replacement, refusal of old callback state,
pre-existing Email/Telephone Flow, cancellation before callback, competing callback Flow creation,
and cancellation winning the Binding/Ceremony lock race.

Verification performed with the repository local container environment loaded:

- Seven focused Minitest files: 165 runs, 1,737 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on six affected Ruby files: no offenses.
- `ruby -c` on the changed controller, service, integration test and concurrency test: syntax OK.
- `git diff --check`: passed.

No full test suite was run. No cross-tab stale signed-cookie generation race was tested. The
proposed persisted callback-generation binding and atomic supersession remain unimplemented pending
the separate storage-shape decision; the checks above establish only the current-session sequential
restart behavior.
