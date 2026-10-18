# Sign-up guardrail verification

- Date: 2026-09-17 (UTC)
- Branch: `feature`
- Source before this slice: `e132a1e4b`

## Finding and change

The current tree still allowed `SignUpStateMachine#enter_checkpoint` to dispatch without checking
the current status. Both `ClientSignUpFlow` and `VisitorSignUpFlow` also listed a direct
`CONTACT_VERIFIED -> CHECKPOINT_PENDING` transition. The sign-up participant and ticket policies
accepted checkpoint entry from `contact_verified` as well.

The state machine now requires `GUARDRAIL_PENDING` for `enter_checkpoint`; the direct transition was
removed from the app and com sign-up flow tables, and both policies require `guardrail` (or the
existing participant checkpoint state where applicable). The existing app social callback completion
path remains `SOCIAL_CALLBACK_PENDING -> CHECKPOINT_PENDING` because it has a separate verified
callback contract.

## Commands and results

- Ruby syntax checks for the five changed application files and four changed test files: passed.
- `bundle exec rubocop` for the nine changed Ruby files: passed; 9 files inspected, no offenses.
- `git diff --check`: passed.
- Focused Rails tests for the state machine, sign-up policies, and sign-flow transitions were
  attempted with isolated Valkey URL variables, but stopped before assertions with
  `ActiveRecord::DatabaseConnectionError` because PostgreSQL host `primary` could not be resolved.

The focused Rails result is unverified, not a pass. No sign-up data, migration, or external service
was changed.
