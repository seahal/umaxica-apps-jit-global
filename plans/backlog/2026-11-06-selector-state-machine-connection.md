# Connect the Base Persona Selector to the Sign-In Flow State Machine

Date: 2026-11-06

Status: Backlog. The owner chose option B on 2026-11-06; Base enforces the one-selection-per-session
boundary while state-machine integration remains future work.

## Finding (source reading, 2026-11-06)

- The sign-in flow (`ClientSignInFlow`, `OperatorSignInFlow`) has a `SELECTOR_PENDING` (65) phase
  after Checkpoint. Only `SignInSelectorParticipant#auto_commit_single!` handles it
  (`app/controllers/concerns/authentication_base.rb`, `advance_sign_in_flow_to_issuance!`): with
  exactly one candidate it selects automatically and advances; with more than one it raises and
  issuance is refused. `sign_in_selector_path` falls back to a bare `/selector` because no
  `sign_app_selector_path` route exists.
- The Base `/selector` page (`Base::{App,Org}::SelectorsController`, `BaseSelectorAuthority`)
  neither reads nor transitions the sign-in flow. It writes the selection to the RP session
  (`RpBaseAppSessionSelection`) and decides "already selected" from that record.
- As a result, multi-candidate selection happens outside the state machine, and the lifecycle rule
  that `back` never crosses a commit (`adr/idp-flow-lifecycle-vocabulary.md`) does not apply to it.
  Observed in development: after selection, browser Back showed the cached selector page and
  `PATCH /selector` was accepted three times, rewriting the selection each time.

## Owner decision (2026-11-06)

Option B now: keep the selector outside the state machine and enforce "once per session" in Base. A
selected session's `update` changes nothing and goes to `/switcher`; switching personas after
sign-in is the Switcher's job. Update the owning ADR text to describe this actual boundary.

The one-candidate path remains automatic during sign-in. For multiple candidates, the sign-in
completes before Base `/selector` stores a selection on the RP session. The selector response is not
stored by the browser, and replayed updates cannot replace the first selection. ORG now uses the
same RP-local selection boundary as APP.

## This backlog item (option A)

Make persona selection a real phase of the sign-in flow: the Base selector accepts a choice only
while the flow is `SELECTOR_PENDING`, the choice completes the flow, and nothing after completion
can re-run it. Under the RP cell path Base does not hold the OP flow, so this needs a Visa-mediated
design (how Base learns the flow is pending, and how the selection reaches the OP flow) and a
decision on whether `auto_commit_single!`'s refusal for multiple candidates remains.
