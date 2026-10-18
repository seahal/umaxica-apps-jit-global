# Auth OTP consumption and receipt continuation

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. Uncommitted task changes affected the results.
Only local synthetic test records were used; no production changes were performed.

The APP/COM repeat-verification regressions reproduced two successful consumptions as reported by
the public result predicate: two cases, two failures, seed 20482. The result now distinguishes first
consumption from an existing immutable receipt. `success?` accepts only `verified`;
`verified_evidence?` accepts `verified` and `already_verified`. Both concrete sign-in controllers use
the evidence classification for continuation, preserving the fixed receipt deadline and existing
Root establishment checks. The receipt-expiry boundary assertions now independently check both
classifications, rather than treating a receipt as a second code consumption.

The actual two-connection race passed for APP and COM: two runs, eight assertions, seed 47553.
Each race produced exactly one `verified` and one `already_verified`, with no Source mutation.
The combined challenge/deadline/concurrency/mailer/APP HTTP/COM HTTP matrix passed 129 runs and
1,039 assertions, seed 13477, using 16 processes. Five-file focused RuboCop passed.

Separately, direct random six-digit generation replaced the admitted Auth challenge's ephemeral
HOTP generator. Its three-file model/deadline/mailer matrix passed 62 runs and 296 assertions,
seed 16644, and focused RuboCop passed. Auth verifier ownership and persisted shape stayed unchanged.

Source-backed signup, registration, recovery and withdrawal ownership migration remains open.
Neither this evidence nor the approvals certify the complete Definition of Done.
