# O-10 signup finalization lock-order trace

Date: 2026-11-04

## Scope

Read-only trace of the APP sign-up finalization and sign-in handoff lock order for the O-10
principal / OP inventory.

## Observed result

`SignUpSequenceControllerSupport#finalize_sign_up_from_checkpoint!` performs the source registration
side effect before its later `@sign_up_ticket.with_cycle_lock` block. For a bound
`ClientSignUpFlow`, that override acquires the Client row before the OP registration-parent and Flow
rows. The block's graph provisioning and sign-in handoff therefore run under actor-first ordering.
The sign-in handoff's `AuthenticationBase#with_actor_session_lock` reacquires the same Client within
the already held actor transaction before its OP sign-in writes. This direct path does not establish
an OP-Flow-to-Client reverse edge. Indirect callbacks and other callers remain outside this bounded
trace.

The reproducible lexical intersection still finds 88 candidate files. After adding full-path
dispositions to the inventory, 15 candidate paths are named and 73 remain unnamed. The unnamed count
is not a count of defects and the global call graph remains incomplete.

## Evidence and limits

- Inspected `app/controllers/concerns/sign_up_sequence_controller_support.rb:176–216,508–523`,
  `app/models/client_sign_up_flow.rb:182–205`, and
  `app/controllers/concerns/authentication_base.rb:405–425`.
- Recomputed candidate and named-path totals with the inventory's recorded `rg` intersection.
- No tests, application code, or databases were changed or accessed.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
read-only source trace was against the worktree content.
