# WU-9 APP Secret receipt-scan journey

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 731 status entries: 500 modified tracked files and 231 untracked files, with no staged files.
Existing worktree changes were preserved; no commit was created.

Updated `test/integration/app_secret_receipt_collection_journey_test.rb` to exercise the existing
Visa POST continuation with two test-owned APP Clients and Secret credentials. The test explicitly
enables and restores the APP Sign In availability flag, and disables Rails' enclosing test
transaction so Secret claim consumption uses its independent App Zenith commit. Teardown removes
only the created flows, receipts, admissions, sessions, tokens, grants, credentials, issuances,
contacts, holds and Clients. It preloads the Client's dependent records and external identities
before physical cleanup.

With `.env.container.devcontainer` and the explicit local COM Preference JWT settings, the final
focused command
`PARALLEL_WORKERS=1 bin/rails test test/integration/app_secret_receipt_collection_journey_test.rb`
passed: 1 run, 18 assertions, 0 failures, 0 errors, 0 skips. It verifies that a receipt under an
active legal hold remains while the later eligible receipt is collected, with both resulting root
tokens still usable. Existing NanoID frozen-string warnings appeared.

An initial current-code recheck stopped at the blocked Sign In boundary because the test had not
enabled its APP availability flag (1 run, 1 failure). After the journey reached its assertions, an
intermediate teardown attempt failed on a nonexistent `client_emails.client_id` column. The cleanup
was corrected to use the Client's owned dependent associations. The exact two Clients left by that
intermediate run were then removed; a read-only post-run check reported zero rows for their Client,
Email, Email history, sign-in Flow, Token, Secret, issuance, hold, and OIDC connection records.

`ruby -c` passed, scoped RuboCop inspected the file with no offenses, and `git diff --check` passed.
No full test suite was run. This verifies this one APP receipt-scan journey only; WU-9's full
three-realm acceptance matrix and final baseline comparison remain open.
