# Logout continuation refusal cache policy

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application/test/documentation changes.

Added no-store directive checks for missing and mismatched browser intent proof in the twelve-client
completion matrix. Red: Core APP refusal had no-cache (1 run, 42 assertions, 1 failure). The shared
continuation boundary now sets no-store before challenge lookup and rendering, covering GET/POST,
unavailable and unknown-challenge responses without changing authentication or state. The next run
exposed an overly exact test expectation on Base's legitimate private,no-store header; assertions
now inspect the no-store directive instead of requiring the whole header equal one token. No
production relaxation followed that test correction.

Final normal Rails test command selected the completion matrix, authority-first flow, Palm
completion and Tech completion with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset and one worker: 8 runs,
750 assertions, 0 failures, 0 errors, 0 skips. Targeted RuboCop inspected two files without
offenses; scoped diff checking passed. The matrix's proportional assertion-count exception is
documented at its test declaration. No database reset or isolated fleet was used. Complete all-RP
authority-flow and external/manual acceptance remain separate unfinished work.
