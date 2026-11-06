# WU-A2 registration completion receipt inventory

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At the time of the read-only inventory, the
worktree had 483 changed or untracked paths, including ongoing changes; no staged changes were
present.

The first Rails runner query stopped before returning data because its inspection used the
deprecated `ActiveRecord::Base.connection` method, which this repository treats as a deprecation
error. A repeat using `connection_pool.with_connection` completed without changing a database.
Counts from local development and test were:

| Environment | Client rows by status ID | `ClientSignUpFlow` rows | `client_registration_completions` |
| ----------- | -----------------------: | ----------------------: | --------------------------------- |
| Development |                        0 |                       0 | table absent                      |
| Test        |     7 (`11`: 6, `13`: 1) |                       0 | table absent                      |

Source inspection found that the ORG invitation signup entry and its acceptance service currently
return the Bureau migration refusal; no active Operator registration completion writer was found in
the inspected App/ORG signup controllers, operations and services. No historical receipt is inferred
from the Client counts. No migration, backfill, production or Neon operation was performed.

The proposed App-only table shape is recorded in
`plans/2026-11-01-wua2-registration-completion-receipt-shape-review.md`; owner approval remains
pending. No full test suite was run.
