# App and Com Withdrawal Timing

Client and Visitor withdrawal confirmation snapshots three deadlines: recovery after one hour, early
irreversible termination after seven days, and normal retention purge eligibility after 31 days.
Recovery and early-termination timestamps are persisted on the principal; the existing
`purge_eligible_at` remains the retention deadline. Previously confirmed rows are never shortened by
a later configuration change.

`Umaxica::Withdrawal::TimingPolicyValue` accepts positive integer seconds and requires the strict
ordering recovery < early termination < retention. Development and test may override any subset of
the values; omitted values use their accepted standards before the complete policy is validated.
Production rejects any override variable, including an empty or standard-valued variable, during
process boot. Unknown environments reject overrides as well. The initializer runs for Web, Solid
Queue Worker, and Scheduler processes.

Ruby lifecycle tests use Rails time helpers for application-side boundaries. Production transitions
and retention jobs use the PostgreSQL database clock; advancing Ruby time does not advance that
clock. Operator withdrawal intentionally remains on its existing timing contract.

This timing contract does not settle termination ceremony assurance, Avatar restoration or final
deletion, legal holds, or external storage retention. Those operations remain fail-closed when the
required policy is not decided.

See [the timing ADR](../../adr/app-com-withdrawal-deadline-snapshot.md) and
[`WithdrawalLifecycle`](../../app/services/withdrawal_lifecycle.rb).
