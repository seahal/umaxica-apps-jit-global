# ADR: Email OTP Race Condition Fixes

**Status:** Accepted

The attempt-window-reset and shared-channel policy decisions are superseded by
[Realm-separated identifiers and dead history](realm-separated-identifiers-and-dead-history.md).
Row-lock atomicity remains required; issuance, expiry and cancellation do not erase failed attempts.

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

The helper remains used by enforcement-recovery and withdrawal-reentry paths. App/com email
sign-in uses the subordinate Auth challenge below; authenticated settings confirmation uses its
separate Source proof below rather than the generic consume-before-binding path.

Malformed OTP input is rejected before the constant-time comparison. Every record-backed verifier
must keep the comparison operands at the generated code length; a short, oversized, non-numeric, or
nil value is invalid input and must not turn into a comparison exception or a successful consume.
The sign-up ceremony applies the same boundary to its direct verifier.

### Resend does not reset the failed-attempt budget

Issuing a replacement OTP does not reset `otp_attempts_count`. The previous implementation cleared
the record before resend and then `store_otp` initialized the counter again, allowing an attacker to
obtain a fresh attempt budget by repeatedly requesting a new code. Resend now invalidates the old
code while preserving the server-side failed-attempt history; only successful consumption or the
existing bounded attempt-window policy may change that history.

The replacement code remains bound to the same record and is written under the record lock. A locked
record is not eligible for delivery, and the resend path does not alter the lockout state.

### Sign-up ticket binding

The app and com sign-up `SignOtpCeremony` requires the caller to present the `public_id` of the
same `ClientSignUpFlow` or `VisitorSignUpFlow` ticket that owns the contact record. The service
rejects a missing or mismatched `session_nonce` before contact lookup, OTP verification, or
consumption. This is a transaction binding check, not an account identity claim: the ticket and
its signed flow context remain the authority for progressing the sign-up ceremony.

### OTP lifetime and secret storage

Authentication OTPs and signup confirmation codes use the shared ten-minute policy. This keeps
authentication and SMS confirmation within the applicable finite lifetime bound; shorter lifetimes
remain valid for email confirmation. The HOTP private key is an encrypted Active Record attribute on
the Email and Telephone concerns, so the database value is not the plaintext secret while the model
continues to decrypt it for verification.

### App/com flow-specific email authentication evidence

The approved app/com Auth ceremony `email_otp_context` JSONB stores version, server UUID generation,
surface, authentication purpose, SID digest, parent kind/reference, real/dummy mode, original Contact
and owner references, destination digest, finalized-binding snapshot, code digest, issue/OTP expiry,
verification and result-expiry facts. It stores neither a plaintext code nor root/RP authority.
Verification resolves the original Contact, not a successor owner of the same destination. A dummy
challenge never authenticates. Resend changes only that ceremony's generation and does not rotate
the effective Contact's shared code. The OTP deadline is at most ten minutes and is capped by the
Auth and parent deadlines; the retained verified result has a separate maximum sixty-second deadline
with the same caps. Reissue after verification is refused, and retries retain the original proof.

New forward migrations add nullable storage, validate the JSON shape, and install owner-approved
PostgreSQL triggers refusing any change or clearing after `verified_at` is set. Historical migrations
and committed Contact binding facts are not rewritten.

Sign-in mailer and Noticed payloads add `auth_ceremony_session_ref` and
`auth_email_otp_generation` alongside the existing encrypted OTP. The reference is the canonical
ceremony `id.to_s` used by the admission/result contract; these models have no public_id column.
Other purposes omit both fields. Missing or malformed sign-in metadata is an explicit producer
error. Immediately before transport, each realm's mailer checks the original ceremony, generation,
destination, bound code, unverified state, active continuity, pending parent and effective Contact
under parent, Auth and Source owner/Contact locks. Delivery refuses stale evidence without reviving
it. Issuance and verification also reacquire the owning database clock after Source locking.
The delivery guard keeps the actual provider call inside these locks; provider latency therefore
affects contention and must be measured before making production throughput claims. Refusal emits
an allowlisted operational event without references or code; it is not an authoritative audit row.

### Shared verification failure budget

The destination counter is shared across candidates, not across channel policy implementations.
The former `OtpVerificationFailureBudget` class is superseded by independent
`EmailOtpVerificationFailureBudget` and `TelephoneOtpVerificationFailureBudget` classes under the
2026-10-07 current contract. Their existing Valkey key is
`otp-verification:<surface>:<purpose>:<channel>:<existing destination digest>`. Candidate, flow,
browser and owner are deliberately absent so recreating those objects cannot reset the shared
budget. Existing candidate attempt limits remain independent. Atomic verification counts five
failed comparisons and refuses further comparisons, including a correct code, until the fixed
fifteen-minute window from the first failure expires. Success, resend and refusal do not reset or
extend that window. Malformed input and stale binding refusal are not comparisons. Invalid stored
counter state or a dependency outage produces explicit failure, not an account-nonexistence response.

A third party knowing a destination can exhaust its same-scope budget: this deliberate bounded
denial trade-off cannot be eliminated by changing browsers without restoring the brute-force bypass.
The fixed TTL prevents refused traffic from perpetually extending that denial. Surface, purpose and
channel separation prevents one scope from exhausting another, and caller/IP and dispatch controls
remain separate. These protections do not claim resistance to every distributed denial attack.

### Signup transport binding

APP/COM signup email retains the original Ticket public ID as `sign_up_flow_ref` and the issued
HOTP counter as the canonical decimal string `sign_up_otp_counter`. Signup SMS retains the fixed
tuple `[surface, "sign_up", flow_public_id, contact_public_id, counter_decimal]` inside a version 2
encrypted envelope. Other-purpose SMS retains version 1; the existing authenticated encryption
purpose is unchanged. Version, schema and tuple validation are explicit rather than an attempt to
recover missing authority from a destination.

Signup producers bind their candidate to the owning Ticket before enqueue. The final email/SMS
transport resolves only that Ticket and its original candidate, then checks current counter,
destination, candidate and owner eligibility under Ticket/Source locks. An overdue nonterminal
Ticket commits its existing expiry and cleanup transition before delivery refusal. Transport runs
inside those locks; this does not certify production contention or provider throughput.

OTP mail delivery jobs disable argument logging because ActiveJob argument logs do not apply
the request parameter filter. The new email references are also request-filtered. SMS binding
and message remain entirely inside authenticated ciphertext.

Legacy version 1 SMS does not identify purpose or original Ticket. Shared/production residual
OTP jobs require inspection and safe operational handling before enabling this rollout. That
prerequisite is unverified; destination-based reconstruction and silent fallback are prohibited.
Known old signup email lacking its binding fails explicitly rather than delivering unbound code.

### Signup committed verification result

Post-verification Ticket progression holds one original Ticket lock and transaction across
`verify_contact`, `enter_guardrail`, `enter_checkpoint` and OTP requirement clearing. A failed
Ticket write therefore leaves the original OTP phase retryable without reversing the independently
committed Source proof or admitting completed-step replay. Each named transition still owns its
guards and database-clock expiry decision.

The approved Source-owned nullable `sign_up_otp_context` has this shape on each APP/COM email or
telephone candidate (references and digests below are placeholders, not runtime credentials):

```json
{
  "version": 1,
  "surface": "app",
  "purpose": "sign_up",
  "flow_ref": "original-flow-id",
  "nonce_digest": "original-flow-nonce-digest",
  "owner_ref": "original-identity-id",
  "contact_ref": "original-candidate-id",
  "destination_digest": "existing-destination-digest",
  "counter": "1",
  "code_digest": "keyed-bound-code-digest",
  "issued_at": "2026-10-07T12:00:00.000000Z",
  "expires_at": "2026-10-07T12:10:00.000000Z",
  "verified_at": null,
  "result_expires_at": null
}
```

The owning server supplies all fields; channel is derived from the concrete candidate model and
is included in the keyed digest tuple. No raw code or OTP private key is persisted in this context.
Verification consumes the candidate OTP and establishes `verified_at` and `result_expires_at` in
the same Source transaction. The fixed result deadline is the earlier of Source verification plus
60 seconds and the original Ticket deadline. Original references, destination, owner eligibility,
release, parent terminal state and deadline are checked on every exact-input retry; shared and
candidate failure limits still apply to comparisons. Success and refusal do not extend the proof.

Forward shape/finite-time constraints and verified-proof immutability triggers protect direct SQL
writes as well. An initially implemented timestamp order CHECK admitted PostgreSQL infinity;
public direct-write regressions drove additional forward finite UTC timestamp checks rather than
editing an already applied migration. Missing old proof is refused rather than inferred from a
status or destination. Shared rollout remains unverified.

An OTP endpoint whose Source verification committed but whose first Ticket transition failed may
retry that original result while the Ticket still serves its OTP step. The controller's preliminary
session check admits only a matching live proof; the locked verifier remains mutation authority.
This does not exempt completed-step HTTP replay from the existing phase guard. Later Ticket
checkpoint progression and finalization remain separate effects; the proof is not a root login.

### Authenticated Contact confirmation

The approved nullable Source `credential_registration_otp_context` belongs to each APP/COM email
or telephone candidate. Its exact fifteen-key shape is:

```text
version, surface, purpose, flow_ref, browser_digest, session_ref, owner_ref, contact_ref,
destination_digest, counter, code_digest, issued_at, expires_at, verified_at, result_expires_at
```

Version is 1; purpose is `credential_registration`. The original Contact ceremony UUID, Base
browser nonce digest, server-resolved root public ID, owner/candidate public IDs and existing
destination digest bind issuance. The canonical unsigned decimal HOTP counter identifies the
issued generation; its code digest is keyed over the channel and complete issuance binding.
The context contains no plaintext code, private key, raw browser marker or root authority.

`ContactRegistrationOtpIssuer` snapshots these facts under Source owner/Contact and Ticket
device/root locks. `ContactRegistrationOtpVerificationCommitter` reacquires owning DB clocks under
the original Ticket and Contact locks, checks the shared and candidate budgets, then consumes OTP
and establishes verified proof in one Source transaction. The fixed result deadline is
`min(verification + 60 seconds, original Ticket expiry)`, distinct from the OTP deadline. Exact
input retries check the original flow, browser, root, owner and candidate; success/refusal never
extend the result. Auth and signup contexts are not reused for this purpose.

Each concrete Contact Action Policy supplies the complete protected-operation requirement.
`ContactRegistrationOtpFinalizer` checks that current policy and the still-live credential/root
immediately before replacement, after acquiring previous-binding and credential locks. The
named Source model writer finalizes the candidate; previous binding release and both audit intents
share its Source transaction. Only after Source commits does the original Contact Ticket receive
its server-issued receipt. Source failure preserves the verified proof and pending Ticket. Receipt
failure preserves committed Source binding/audit facts and the pending Ticket; original-operation
reconciliation neither creates another candidate nor repeats release or audit. This is ordered
cross-database recovery, not a claim of one cross-database atomic transaction.

First-email bootstrap passes its explicit original Step-Up parent separately. The finalizer locks
the matching Session, parent and durable admission binding before the Contact ceremony; it checks
the original browser nonce, Root, owner and email-only registration permission. No latest-parent
lookup or missing-freshness fallback supplies permission. Source commits before the original
bootstrap and Contact receipts. The model consumes the bootstrap with its own locked DB clock,
without issuing Step-Up freshness. The primary ten-minute check remains an issuance prerequisite,
not a completion deadline. Actual HTTP receipt recovery after committed Source remains unverified.

Email and Noticed payloads add `contact_ceremony_transaction_ref` and `contact_otp_counter` to the
existing encrypted OTP fields. SMS uses encrypted version 2 with the fixed tuple
`[surface, "credential_registration", transaction_uuid, contact_public_id, counter_decimal]`.
`ContactRegistrationOtpDeliveryIssuer` resolves only those original records and holds Source and
Ticket locks through actual transport. Verified, reissued, expired, released or root-revoked
evidence refuses delivery. The SMS worker validates the decrypted body against the existing
default or localized message template and current HOTP; it does not guess a code or reconstruct
missing legacy authority from a destination.

`ContactRegistrationOtpResendIssuer` locks the original pending flow, root, owner and Contact,
rechecks the existing thirty-second email cooldown, then replaces only the pending generation.
The original challenge and Ticket deadlines, browser/root bindings and both failure budgets remain
unchanged. APP email HTTP resend uses that issuer and bound delivery payload; verified proof refuses
reissue while retaining the original verification retry. No COM email resend route is introduced.

New forward migrations add nullable storage, exact shape and finite-time checks, and owner-approved
verified-proof immutability triggers. They neither change historical migrations nor backfill old
OTP authority. Direct SQL cannot clear or replace a verified proof. Root revocation clears the
Step-Up Session's challenge secret while preserving its original reference, RP, Origin, deadline
and existing burn timestamp; this preserves the challenge binding CHECK during early discard.
Session revocation uses its own locked DB clock and never extends an existing deadline.

All four real signed-Passkey HTTP Source-failure/retry journeys and independent-connection delivery
lock tests, APP email HTTP resend and APP/COM first-email bootstrap passed locally.
Bootstrap HTTP receipt-fault recovery and settings cancellation closure remain incomplete;
this record does not certify rollout. Shared/production legacy OTP job inspection and safe handling
remain required before enabling version-two delivery. Live-provider throughput remains unmeasured.

## Trade-offs

- `with_lock` holds `SELECT ... FOR UPDATE` on the email row for the whole read-modify-write, which
  serializes concurrent attempts on the same row. Production contention is not certified here; unlike a
  raw `update_all`, model callbacks/validations and the windowed-reset / lockout logic are
  preserved.
- `SELECT ... FOR UPDATE` on the email row serializes concurrent signup requests for the same
  address. Provider calls held inside delivery locks also affect contention; production impact must
  be measured before making throughput claims.
- The pre-transaction cooldown check is a best-effort optimization only. The in-transaction check is
  the authoritative one.

## Affected Files

- `app/models/concerns/email.rb` — `increment_attempts!`
- `app/controllers/concerns/sign/email_registrable.rb` — `initiate_email_verification!`
- `app/services/sign_otp_ceremony.rb` — locked cooldown recheck for sign-up resend
- `app/services/sign_in_otp_resender.rb` — resend invalidation without failed-attempt reset
- `app/controllers/concerns/common_otp.rb` — locked verification/consumption boundary and malformed
  input handling
- `app/models/concerns/otp_lockable.rb` — bounded attempt history and resend invalidation
- `app/models/concerns/email.rb` / `app/models/concerns/telephone.rb` — encrypted OTP secret storage
