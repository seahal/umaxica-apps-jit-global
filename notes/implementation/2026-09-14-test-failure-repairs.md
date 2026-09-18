# Test Failure Repairs Implementation Notes

## Context

- Original plan/spec: Repair the three failures from the Rails test run.
- Related decisions/docs/plans: Surface isolation and mounted Rack app invariants in the affected tests.
- Implementation date: 2026-09-14

## Decisions Made During Implementation

- Keep the Edit staff surface on its current ERB rendering path:
  - The current code removed its Inertia layout and entrypoint, leaving thirteen active Inertia layouts.
  - The stale contract assertion was updated from fourteen to thirteen rather than restoring the removed pipeline.
- Treat the taxonomy term model class as part of the move scope:
  - Different publishing cells use separate tables whose integer IDs can overlap.
  - A cross-cell parent therefore raises `ScopeMismatchError` before cycle validation.
- Record both configured Flipper hosts in the mounted-app review invariant:
  - `config/routes/flipper.rb` already wraps the mount in fail-closed `Rack::Auth::Basic`.
- Remove the Publishing React management spec after the Edit surface returned to ERB:
  - The spec imported four deleted components, while the Rails controller integration tests cover the current management pages.
- Configure Vitest to use four worker threads:
  - Bun's default fork pool timed out before starting workers; the bounded thread pool ran all 1,050 frontend tests successfully.

## Review Notes

- Tests run: The three affected Rails test files passed; the full Rails suite passed with 12,957 runs, 78,572 assertions, zero failures, zero errors, and three skips. `bun run lint`, `bun run format`, and `bun run test` passed; Vitest reported 85 files and 1,050 tests.
- Tests not run: None required for the repaired behavior.
- Documentation promotion needed: No.
