# Restore `locked_at` Timestamp When OTP Attempts Reach Threshold

Status: ALREADY_SATISFIED (verified 2026-09-22) Severity: Low (audit / diagnostic completeness)
Origin: Security review follow-up; verified working tree on 2026-05-05.

## Summary

`Email#increment_attempts!` and the matching `Telephone#increment_attempts!` were simplified to a
plain `increment!` call:

```ruby
def increment_attempts!
  increment!(:otp_attempts_count)
end
```

`increment!` translates to atomic `UPDATE … SET col = col + 1` at the SQL level, so there is no
read-modify-write race. The `locked?` check at `app/models/concerns/email.rb:80-89` returns true on
either `locked_at` being a real timestamp OR `otp_attempts_count >= MAX_OTP_ATTEMPTS`, so
count-based lockout still works.

What was lost (commit `d98718b01`, vs. `main`): the second SQL step that set
`locked_at = Time.current` once the row crossed `MAX_OTP_ATTEMPTS`. Today `locked_at` stays at the
"infinity" / "-infinity" / NULL sentinel until the next `store_otp` or `clear_otp` call, even when
the row is locked by attempts count.

Impact:

- Lockout itself works (count-based).
- Anything that reads `locked_at` for diagnostic, audit, or UI ("locked at HH:MM, retry later")
  purposes sees a sentinel instead of a real time.
- Audit log / observability for "when did this OTP series get locked" is weaker than `main`.

This is a Low-severity completeness gap, not a lockout bypass.

## Required Change

After `increment!`, conditionally set `locked_at` if the row crossed the threshold and `locked_at`
is still a sentinel. Single SQL statement, e.g.:

```ruby
def increment_attempts!
  increment!(:otp_attempts_count)
  self.class
    .where(id: id)
    .where(otp_attempts_count: MAX_OTP_ATTEMPTS..)
    .where("locked_at IS NULL OR locked_at = '-infinity'::timestamp OR locked_at = 'infinity'::timestamp")
    .update_all(locked_at: Time.current)
  reload
end
```

Apply the identical change in `app/models/concerns/telephone.rb` (verified to share the same
simplified shape around l.88).

## Verification

1. Test: increment attempts to threshold and assert `locked_at` is now a real timestamp (not a
   sentinel).
2. Test: increment attempts beyond threshold a second time and assert `locked_at` does not move
   (idempotent — the conditional `WHERE` keeps the first lock-time stable).
3. Test: row already locked-by-time keeps its existing `locked_at`.
4. Existing OTP brute-force / lockout tests should still pass.

## Affected Files

- `app/models/concerns/email.rb` (l.104-106).
- `app/models/concerns/telephone.rb` (matching method).
- `test/models/concerns/email_test.rb`, `test/models/concerns/telephone_test.rb`.

## How to Apply

Single small PR. No callers change; this is purely the `locked_at` write at threshold.

## Current verification

The implementation is already present in the shared `OtpLockable` concern, so no additional code
slice is required. `increment_attempts!` increments under the record lock, uses the writer database
clock, sets a finite lockout expiry only when the threshold is reached, and leaves the first expiry
unchanged on later attempts. The concrete Client Email and Client Telephone models exercise the
same concern; no parallel second implementation is needed.

The Compose-backed focused run on 2026-09-22 passed with 153 runs / 459 assertions / 0 failures /
0 errors / 0 skips. Evidence:
`evidence/2026-09-22-otp-lockout-timestamp-revalidation-J4K5.md`.

## Why this is no longer a "race condition" plan

The original draft of this plan claimed `update!(otp_attempts_count: otp_attempts_count + 1)` was
non-atomic. That is no longer the code on disk — `increment!` IS atomic. Re-classify accordingly and
do not introduce optimistic locking or retries.
