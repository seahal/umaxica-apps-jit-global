# Model-to-Write-Operation Dependencies: What They Actually Are

Decision input for #869. **The characterization this series has been carrying is wrong, and the
correction changes the answer.**

## The claim that was wrong

#858, #860, and #862 all describe `ChronicleIntentWriter` as "fired from a model callback" and call
it the one true dependency inversion in the repository. #862 added `AdministrativeAccessLock.lock!`
as "the same shape".

Neither is a callback. `app/models/concerns/chronicle_capturable.rb` defines no `after_`, `before_`,
or `around_` hook of any kind, and neither does `app/models/concerns/enforcement_case_applicable.rb`
beyond a `before_validation :assign_public_id`. The claim came from seeing a write operation
referenced inside a model concern and assuming the mechanism.

Both are explicit method calls, and each is a different problem.

## `Chronicle.capture` — probably not a violation at all

`ChronicleCapturable.capture` is a class method taking a block:

```ruby
Chronicle.capture(action: ..., actor: ...) { ...the work... }
```

It writes an intent row, runs the block, then writes a result row or invalidates the intent. The
writers it calls — `ChronicleIntentWriter`, `ChronicleResultWriter`, `ChronicleInvalidator`,
`ChronicleFallbackRecorder` — all write **`Chronicle` rows**. `ChronicleIntentWriter` opens
`Chronicle.transaction` and calls `Chronicle.create!`.

So the model reaching for these operations is the audit model reaching for its own persistence
steps, extracted into named objects. That is not a Service orchestrating a Model. The dependency
rule exists to stop a domain model from pulling in a workflow that coordinates other aggregates;
`Chronicle` writing `Chronicle` rows is not that.

Two things are worth noting instead:

1. **`ChronicleCapturable` is included only by `Chronicle`.** A concern with exactly one includer
   that is also the only thing it writes is a namespace, not a shared behavior.
2. **`Chronicle.capture` has no production caller.** Every call site in the repository is in
   `test/models/concerns/chronicle/capturable_test.rb`.
   `app/controllers/concerns/authentication_audit_writer.rb` only mentions it in a comment. Before
   any refactor, establish whether this API is still wanted.

**Recommendation:** stop calling this a layering violation. Decide whether `capture` is live; if it
is, either move it to an operation that owns the audit transaction, or record in the rule that a
model may use extracted operations to write its own rows. If it is not live, delete it.

## `EnforcementCase#apply!` — a real problem, but not the one described

`AdministrativeAccessLock.lock!` is called from `perform_principal_access_effect!`, which is called
from `apply!`:

```ruby
def apply!
  self.class.transaction do
    close_superseded_effects!
    self.state = "active"
    save!
  end

  perform_principal_access_effect!
  revoke_method_sessions!
  write_audit_event!("applied")
end
```

`apply!` is a use case. It validates a state transition, commits a state change in a transaction,
then performs three side effects — locking an account, revoking sessions, writing an audit event —
two of which reach outside the aggregate. `end_case!` has the same shape.

This is the classic fat model: the use case is a method on the record it happens to start from. The
dependency on `app/operations` is a symptom; the cause is that `apply!` belongs in `app/operations`
itself.

That the side effects run **outside** the transaction is deliberate and documented in the code
(`adr/unified-enforcement.md`, the refcount rule, and a comment saying a committed security decision
must never be rolled back). Any extraction must preserve that ordering exactly, which is the main
risk.

**Recommendation:** extract `apply!` and `end_case!` into
`app/operations/enforcement_case_apply_operation.rb` and `..._end_operation.rb`, leaving the model
with its state predicates. This is a behavior-preserving refactor with a real blast radius, not a
file move, and it needs its own issue with tests written first around the ordering guarantee.

## Done in this issue

`ChronicleRecorder` → `ChronicleRecordPolicy`, moved to `app/policies`. It carried the `Recorder`
suffix and recorded nothing: `sanitize`, `sanitize_text`, `retention_policy_for`,
`retention_policy_code_for`, `erasable_at_for`, `log_payload`, `forbidden_key?` — the rules for what
may be written down and for how long, with no writes anywhere. `app/models/chronicle.rb` calls it,
which the dependency rule permits for `app/policies`.

Its `< ChronicleApplicationService` inheritance was dead: the class is used only through class
methods and never through `.new` or `.call`.
