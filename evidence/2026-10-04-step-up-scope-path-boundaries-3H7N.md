# Step-up scope path boundaries

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Several scope catalog patterns accepted arbitrary text after an operation root, including `/settings/passkeys-extra`. Added path-segment boundaries to the existing session, withdrawal, email, telephone, Passkey, APP TOTP, COM/ORG secret and ORG lifecycle roots. Existing child paths and query/fragment delimiters remain accepted where those patterns already allow them; exact-only scope patterns remain exact-only. No scopes, routes, functions or transport fields were added.

Public catalog tests cover each affected root across APP/COM/ORG, valid root/query/child partitions and adjacent `-`, `_`, digit and encoded-slash suffixes. Base issuer tests additionally reject nil, empty, zero, object and NUL-containing invalid targets without creating a parent/session or changing root-token usability.

All Rails runs used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

- Before correction: scope catalog test file, 12 runs, 165 assertions, four failures (seed 14388).
- Final command: `bin/rails test test/services/step_up/scope_catalog_test.rb test/operations/base_step_up_admission_issuer_test.rb test/controllers/auth/step_up_admission_test.rb test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`.
- Final result: 35 runs, 929 assertions, no failures/errors/skips (seed 30986).
- RuboCop on three changed Ruby files passed after line wrapping/assertion spacing. `git diff --check` passed.

These checks establish the identified path-prefix boundary, not a full route inventory or every URL-normalization behavior. Registration/credential-management integration and other full-plan requirements remain unfinished. No browser checks, schema changes, OTP logging remediation or deployment occurred.
