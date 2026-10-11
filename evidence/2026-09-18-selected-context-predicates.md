# Selected-context predicate verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Commit before this slice: `858210b46`
- Existing unrelated working-tree changes were preserved and not staged.

## Implemented boundary

`Actor::SelectedContext#persona_selected?` now identifies a selected Persona/account identifier.
`#organization_context_selected?` requires that identifier plus the organization and
organization-unit identifiers. The existing `#selected?` predicate delegates to the complete
organization-context predicate, preserving the full-access controller contract. Persisted selection
field names and authorization behavior were not changed.

## Checks

- A test run without the required `VALKEY_TEST_HOST`/`VALKEY_TEST_PORT` failed at the repository's
  explicit test configuration boundary; no fallback datastore or Valkey service was used.
- With isolated loopback test variables, the RED test run reached the new assertions and failed with
  three missing-method failures, confirming the test exercised the intended contract.
- After implementation, the focused selected-context test passed: 6 runs / 22 assertions / 0
  failures / 0 errors / 0 skips.
- The related full-access and dashboard regression set passed: 37 runs / 113 assertions / 0 failures
  / 0 errors / 0 skips.

No selector field migration, authorization relaxation, Unit/Position implementation, or new route
was added.
