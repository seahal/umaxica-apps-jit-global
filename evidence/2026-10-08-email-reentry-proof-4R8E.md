# Email reentry proof and delivery boundary

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The worktree had substantial uncommitted task changes affecting every result below.

- Operation-isolation regression initially failed creation in all twelve cases (seed 27048).
  Separate internal operation validation passed twelve cases / 48 assertions, seed 59679.
  Signed Email and Telephone permission allowlists were not expanded.
- The eleven-file primitive, signed-contract, issuance and worker matrix passed 84 runs /
  749 assertions, seed 60482. No skips.
- Admission denial initially consumed proof; three regressions failed, seed 8729. Admission
  expiry crossed during the callback then produced three failures, seed 30391. Both were fixed;
  the matrix above covers the microsecond neighbors and refusal without consumption.
- APP withdrawal HTTP initially enqueued no new bound worker, seed 41304. After switching its
  caller, the focused real HTTP journey passed one run / 19 assertions, seed 49465.
- Withdrawal HTTP plus issuance, verification, worker and admission files passed 29 runs /
  349 assertions, seed 61468. APP/COM routes retain generic unknown-recipient responses,
  candidate failures and absence of normal authentication cookies.
- Actual Mailer processing that crossed expiry initially still sent in all three realms
  (six runs, three failures, seed 14771). Concrete late-delivery hooks fixed that boundary.
  Worker, withdrawal HTTP, surface mailer, token-storage and Auth delivery files then passed
  51 runs / 382 assertions, seed 39674; no failures, errors or skips.

The initial dedicated worker was replaced by the repository's existing realm-specific Noticed
entry points, preserving all six delivery cases in
`test/notifiers/notify/email_reentry_otp_delivery_test.rb`. No compatibility worker remains.
The saved payload contains encrypted code, recipient GlobalID and transaction/generation
references, not plaintext code or address; the existing Noticed job disables argument logging.
Its Mailer performs current Source/transaction checks immediately before transport.
The older counter payload is not a fallback for this proof.

The six-file Noticed/issuance/verification/withdrawal/Auth-delivery matrix passed 52 runs /
419 assertions, seed 23653. The subsequent six-file recovery-entry/recovery-action/withdrawal/
reentry-Notifier/issuance/verification matrix passed 38 runs / 391 assertions, seed 59488.
The recovery action fixtures had only VERIFIED status, not the effective finalized binding
required by the unchanged lookup. Five failures (seed 631) were fixed by constructing actual
finalized contacts, not weakening lookup. Actual recovery HTTP now consumes its own ceremony proof
and issues no normal authentication cookies.

Noticed 3.1.0 was identified from Gemfile.lock and its installed Email delivery implementation.
The official [Email delivery documentation](https://github.com/excid3/noticed/blob/main/docs/delivery_methods/email.md)
confirms configured params and direct delivery within the Noticed job; the accepted repository
ADR remains authoritative for encrypted fields, argument redaction and concrete realm classes.

Signup, registration, Telephone transport and global HOTP removal remain incomplete.
Full Rails, full RuboCop, all harnesses and final architecture gates are not certified here.
The subsequent eleven-file reentry, HTTP, admission, operation-isolation, notifier and Auth-delivery
matrix passed 88 runs / 680 assertions, seed 22018, with no failures, errors or skips.
Focused RuboCop passed for the eighteen changed implementation/test files, followed by the three
UUID admission and delivery-binding files changed afterward. Full repository lint remains unverified.

No production database, role, secret or deployment was changed. No remote mutation occurred.
