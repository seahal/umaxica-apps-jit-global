# Passkey legacy client retirement

Date: 2026-09-22
Branch: `feature`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: already contained unrelated and related uncommitted changes; this record does not claim a
clean worktree.

## Decision

The app/com direct Passkey contract is the discoverable React ceremony. Its options request is
identifier-free, its response contains no real credential descriptors, and its verification request
contains the assertion and challenge only. The old `src/controllers/passkey_authentication_controller.ts`
Stimulus controller was not referenced by any current page, Rails controller, runtime loader, or
application entrypoint. Its only caller was its own test, which asserted the retired identifier-first
behavior. The controller and that obsolete test were removed rather than retained as a compatibility
path.

The actor-known org normal, org Emergency, MFA, and Step-Up ceremonies remain on their existing
server-selected/actor-bound path. Their descriptor helper was not removed.

## Adversarial cross-surface revalidation

The first cross-surface UI review found a real regression in the shared React panel: org Emergency
Rails props still supplied `identifier_param: "identifier"` and a field contract, but the panel
ignored `field` and submitted an empty identifier. The existing Rails controller tests passed
because they posted directly to the endpoint and therefore did not exercise the browser panel.

The RED test reproduced the missing label and the missing actor identifier. The panel now renders
the server-provided field only when an actor lookup ceremony requires it, keeps the value in local
component state, and submits that value. The app/com discoverable path remains identifier-free
because its `identifier_param` is null and its `field` is null. The test uses the repository's
user-event driver so the controlled React field is exercised through the public UI interaction.

This was a frontend contract correction only; no server authentication boundary, org policy, or
discoverability rule changed.

## Verification

- Rails app/com/org WebAuthn and Passkey regression set: 70 runs, 328 assertions, 0 failures, 0
  errors, 0 skips.
- Frontend Passkey and sign-in contract set after cleanup and actor-bound correction: 4 files, 121
  tests passed.
- `git diff --check`: passed.
- Repository search found no remaining source or test reference to the retired Stimulus controller
  or its identifier-required message.
- Rails full suite after the actor-bound correction: 11,533 runs, 73,416 assertions, 0 failures,
  0 errors, 8 existing skips. The org Emergency controller contract was separately rechecked at
  10 runs, 53 assertions, 0 failures, 0 errors, 0 skips.
- Frontend full suite after the actor-bound correction: 84 files, 1,036 tests passed.
- `bun run typecheck`, `bun run lint`, and `bun run format:check`: passed.

No external services, production data, or remote repository state was changed. Full Rails and full
frontend suites were run in the Compose-backed verification context; coverage was intentionally not
run per the current task instruction.
