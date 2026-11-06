# Signup Flow lock-order caller trace

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; inspected source files were in the existing worktree.
- Scope: trace production `ClientSignUpFlow#with_cycle_lock` callers for stale unbound-to-bound
  OP/principal lock edges.
- Evidence inspected: `app/models/client_sign_up_flow.rb`, `app/models/concerns/flow_base.rb`, all
  `with_cycle_lock` matches under `app/`, the OTP issuer entry points, Auth social pending-client
  support, explicit-step/passkey controllers, sign-up state machine, termination/cleanup, lifecycle
  job, registration committer, and sequence finalization.
- Finding: bound actor-mutating paths either enter the Client-first override or already hold Client
  before the Flow. The social binding path serializes an initially unbound Flow while creating a new
  Client and returns on a concurrent binding without mutating the existing actor. Other traced
  unbound entries perform Flow-only transitions or refuse before actor-dependent work. Cleanup has a
  separate tested stale-binding rollback/retry. No additional stale-blank-to-bound reverse edge was
  found in the inspected call sites.
- Limit: indirect callbacks, external callers with pre-held locks, and the full O-10 lock graph
  remain unverified.
- Verification: source inspection only; no tests or database operations were run.
