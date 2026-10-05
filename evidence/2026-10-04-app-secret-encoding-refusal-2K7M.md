# app Secret encoding refusal

Executed on 2026-10-04 at approximately 00:02–00:05 UTC against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with concurrent uncommitted changes.
Only the task-owned `codex_integrity_20261003secret_*` disposable fleet was used.

The public lookup and whole-value verifier called Regexp#match? before checking
string encoding. Added real public-boundary cases for invalid UTF-8 and an ASCII
value encoded as UTF-16LE. Red: two ArgumentError errors for invalid UTF-8,
with 11 tests and 50 assertions; no environment preparation error caused them.

Both boundaries now require valid encoding and ASCII-only input before evaluating
the existing Base58 grammar. Neither normalization nor transcoding is performed.
Invalid values return the existing nil/false refusal, and valid exact Secrets
still verify. Infrastructure exceptions remain observable; no broad rescue was
added and no lifecycle fact is modified by lookup.

Command:

```text
bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/queries/client_secret_lookup_query_test.rb
  test/models/client_secret_credential_rebuild_test.rb
  test/operations/client_secret_name_committer_test.rb
```

Green: 19 tests, 179 assertions, no failures, errors or skips. This includes
existing adjacent-length, type, ownership and name-mutation behavior. No private
methods or successful-authentication mocks were used. These are Ruby public API
tests, not malformed HTTP transport or complete Secret login evidence.

Initial RuboCop identified one continuation indentation offense in the query;
it was corrected without changing the gate. Final RuboCop passed on all four
files with no offenses; `git diff --check` passed. No schema, payload, key, session
issuance, shared database or external deployment changed.
