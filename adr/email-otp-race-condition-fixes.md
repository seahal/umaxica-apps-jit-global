# ADR: Email OTP Race Condition Fixes

**Status:** Accepted

## Context

Two race conditions were identified in the `Email` concern (`app/models/concerns/email.rb`) and the
`EmailRegistrable` concern (`app/controllers/concerns/sign/email_registrable.rb`).

### Race condition 1: Non-atomic OTP attempt increment

`increment_attempts!` used a read-then-write pattern:

```ruby
record = self.class.find(id)
record.update!(otp_attempts_count: otp_attempts_count + 1, ...)
```

Two concurrent requests could both read the same `otp_attempts_count` value and write the same
incremented value, meaning two failed OTP attempts would only register as one. Under
`MAX_OTP_ATTEMPTS = 3`, an attacker could make more attempts than the lock threshold allows before
the lock fires.

A second non-atomic step followed: the lock check loaded matching rows into memory with `.to_a`,
then called `update!` on each — two threads could both pass the threshold check before either wrote
`locked_at`.

### Race condition 2: OTP cooldown check outside transaction

`initiate_email_verification!` checked `otp_cooldown_active?` before opening a transaction:

```ruby
if existing_email.otp_cooldown_active?
  return :cooldown
end

UserEmail.transaction do
  @user_email.otp_last_sent_at = Time.current
  @user_email.save!
  send_verification_email(num)
end
```

Two concurrent signup requests for the same address could both pass the cooldown check before either
set `otp_last_sent_at`, resulting in two OTP emails being sent within the cooldown window.

## Decision

### Fix 1: Atomic increment under a row lock

Replace the read-then-write pattern with a `with_lock` block (`SELECT ... FOR UPDATE` on the email
row) so concurrent increments are serialized. Inside the lock the method applies the attempt-window
reset, increments, and sets `locked_at` once the threshold is reached, then saves in the same
transaction:

```ruby
def increment_attempts!
  with_lock do
    next if lockout_active?

    unless attempt_window_active?
      self.otp_last_sent_at = Time.current
      self.otp_attempts_count = 0
    end

    self.otp_attempts_count = otp_attempts_count.to_i + 1
    self.locked_at = OTP_LOCKOUT_DURATION.from_now if otp_attempts_count >= MAX_OTP_ATTEMPTS
    save!
  end
  reload
end
```

Because the row lock is held for the whole read-modify-write, two concurrent attempts cannot both
read the same `otp_attempts_count`; the second waits for the first to commit. This uses the same
`SELECT ... FOR UPDATE` primitive as Fix 2, so both fixes share one locking strategy, and it
preserves model callbacks/validations and the windowed-reset / lockout-duration logic that a raw
`update_all` would bypass. The implementation wraps the block in `Prosopite.pause` so the
intentional `reload` is not flagged as an N+1 in development and test.

> Implementation note: an earlier draft of this ADR prescribed two `update_all` statements. The
> shipped implementation in `app/models/concerns/email.rb` (`increment_attempts!`) uses `with_lock`
> instead; this section documents the approach that is actually in the code.

### Fix 2: Cooldown check inside transaction with row lock

Move the definitive cooldown check inside the transaction, using `lock` (i.e.,
`SELECT ... FOR UPDATE`) to prevent concurrent requests from passing the check simultaneously:

```ruby
cooldown_active = false
UserEmail.transaction do
  if existing_email
    locked = UserEmail.lock.find_by(id: existing_email.id)
    if locked&.otp_cooldown_active?
      cooldown_active = true
      raise ActiveRecord::Rollback
    end
  end

  # ... save and send OTP ...
end

return :cooldown if cooldown_active
```

The pre-transaction check is retained as a fast path to avoid acquiring a lock on every request. The
in-transaction check is the authoritative gate.

### Sign-up ceremony application

`SignOtpCeremony#issue!` follows the same rule for the app and com sign-up email paths. Its initial
cooldown check is only a fast path; after the bound contact row is locked, the ceremony checks the
cooldown again before replacing the stored OTP or invoking the delivery adapter. This prevents two
concurrent resend requests from both issuing a code when the first request has already advanced the
send timestamp. The row lock also keeps the OTP replacement and the timestamp update in the same
serialized write boundary.

### One-time verification consumption

Record-backed callers must not verify an OTP in one request and clear it in a later, unlocked
operation. `CommonOtp#verify_otp_code_and_consume` locks the record before reading the OTP, clears a
successful code before releasing the lock, and increments a failed-attempt counter in the same
boundary. Callers may provide a pre-consumption authorization check; a rejected check does not
consume the code or count as a failed OTP attempt. This keeps login/account eligibility checks from
turning a valid but unauthorized record into a consumed code while still preventing two eligible
requests from accepting the same code.

The helper is used by the existing app/com/org email and telephone verification, sign-in,
enforcement-recovery, and withdrawal-reentry paths. It changes no OTP length, expiry, attempt
threshold, cooldown, or delivery-provider setting.

Malformed OTP input is rejected before the constant-time comparison. Every record-backed verifier
must keep the comparison operands at the generated code length; a short, oversized, non-numeric, or
nil value is invalid input and must not turn into a comparison exception or a successful consume.
The sign-up ceremony applies the same boundary to its direct verifier.

## Trade-offs

- `with_lock` holds `SELECT ... FOR UPDATE` on the email row for the whole read-modify-write, which
  serializes concurrent attempts on the same row. The per-row contention is negligible and, unlike a
  raw `update_all`, model callbacks/validations and the windowed-reset / lockout logic are
  preserved.
- `SELECT ... FOR UPDATE` on the email row serializes concurrent signup requests for the same
  address. This is the correct behavior and the performance impact is negligible for a per-user row.
- The pre-transaction cooldown check is a best-effort optimization only. The in-transaction check is
  the authoritative one.

## Affected Files

- `app/models/concerns/email.rb` — `increment_attempts!`
- `app/controllers/concerns/sign/email_registrable.rb` — `initiate_email_verification!`
- `app/services/sign_otp_ceremony.rb` — locked cooldown recheck for sign-up resend
- `app/controllers/concerns/common_otp.rb` — locked verification/consumption boundary and malformed
  input handling
