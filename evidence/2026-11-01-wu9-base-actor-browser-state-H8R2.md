# WU-9 Base Actor browser-state projection

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had 550 changed or untracked
  paths before this evidence file was added; this verification ran against that uncommitted state.
  No commit was created.
- Implemented Base app/org/com HTML GET and HEAD projection of active anonymous Preference region,
  receipt-authorized consent (including receipt version and decision time), and browser-bound Web
  Push into `Actor.preferences`. Realm, JWT expiry, active row and constant-time binding checks are
  required. APP/ORG use the shared read-only browser-state concern; Base JSON API requests leave the
  Actor unchanged, and non-Base controllers do not include the projection. The COM Web Push endpoint
  keeps its existing `200/disabled` behavior on database read failure.
- Updated the Preference architecture and lifecycle checklist to describe the Base-only projection.
  Updated integration coverage for COM bound/mismatched/retired browser state and APP/ORG bound and
  mismatched binding, saved region and receipt metadata.
- With `.env.container.devcontainer` sourced and one test worker, the selected eight-file Preference
  reader/API group passed: 114 runs, 2,414 assertions, 0 failures, 0 errors, 0 skips. After adding
  APP/ORG mismatched-binding assertions, `test/integration/preference_read_symmetry_test.rb` passed
  separately: 5 runs, 50 assertions, 0 failures, 0 errors, 0 skips.
- `test/security/invariants/controller_lifecycle_order_invariant_test.rb` passed: 2 runs, 4
  assertions. Scoped RuboCop on the reader, projection, endpoint and affected integration tests
  passed; the final APP/ORG assertion update also passed its scoped RuboCop run. Scoped
  `git diff --check` passed.
- An intermediate focused run found that the consent-receipt failure test stubbed `exists?` after
  the reader had moved to `find_by`; the failure injection was updated to the actual lookup
  operation and the selected suite passed on rerun.
- No migration, schema edit, production/Neon operation or full-suite run occurred in this slice. The
  single WU-9 closure full-suite comparison remains reserved. HTML-projection database-failure
  behavior is logged and leaves the current safe Actor browser defaults; a direct injected failure
  case for that specific callback remains unverified.
