# C13 PreferenceSelect browser reproduction and fix

Date: 2026-11-04 HEAD: b30345216886c98af1f04cbd434f067f12decf01 Worktree: extensively uncommitted;
results include only the scoped changes described here.

## Work

Reproduced the same-page server-props defect in Chromium on a live Rails-rendered Base com Inertia
page. A controlled PATCH response supplied a new form value while the component retained its old
selection.

Changed PreferenceSelect to derive its clean value from current server props and to retain a dirty
user draft. The draft revision prevents a successful earlier submission from clearing a newer edit.
Added a component interaction case for clean prop synchronization and dirty-draft preservation, plus
two browser cases: clean selection updates and an edit made while the PATCH response is pending.

The E2E initial request was a read-only GET against configured test databases. Playwright fulfilled
the PATCH responses, so no preference write reached Rails. The E2E launcher required the system
Chromium path and Base surface availability flags in scripts/e2e/server.rb. Existing edits in that
already-dirty launcher were preserved.

## Verification

- bun run test -- gait/features/preferences/preference_screens_interaction.test.tsx — passed, 13
  tests.
- PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium bun run test:e2e:rails --
  e2e/rails/preference-select-props.spec.ts — passed, 2 Chromium E2E tests.
- bun x oxlint src/features/preferences/PreferenceSelect.tsx
  gait/features/preferences/preference_screens_interaction.test.tsx
  e2e/rails/preference-select-props.spec.ts — passed.
- bun x oxfmt --check src/features/preferences/PreferenceSelect.tsx
  gait/features/preferences/preference_screens_interaction.test.tsx
  e2e/rails/preference-select-props.spec.ts — passed.
- Scoped git diff --check — passed.
- bun run typecheck — failed at gait/pages/auth/org/org_auth_screens.test.tsx:342 because turnstile
  is unused after the existing uncommitted diff removed the invitation tests that referenced it.
  That file and unrelated change were left intact.

## Follow-up verification

The failure above was caused by the now-orphaned `turnstile` fixture declaration in the existing
changed test file. After confirming that no remaining test referenced the declaration, removed that
declaration. The subsequent full `bun run typecheck` passed. Scoped Oxlint and Oxfmt checks passed
again on the four affected frontend/test files. This follow-up changed only an unused test fixture
declaration; application behavior is unchanged.

HEAD remains `b30345216886c98af1f04cbd434f067f12decf01`; the worktree remains extensively
uncommitted.

No development or production database was accessed. No preference data or schema was changed.
