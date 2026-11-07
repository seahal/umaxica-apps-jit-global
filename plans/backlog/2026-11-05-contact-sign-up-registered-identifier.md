# Email and Telephone Sign-Up or Registration With an Already Registered Address

Date: 2026-11-05

Status: Backlog, to be handled in the current session (owner, 2026-11-05). Owner decisions recorded
below. Outside the OP-mediated step-up contract, except where the post-sign-in registration overlaps
its contact-registration redesign. No code changed by this note.

## Observed (development, 2026-11-05)

An APP email sign-up with an address that an existing Client already holds as an effective binding
(Client created 2026-11-03) issued and delivered a sign-up OTP, accepted the code, reached the
birthdate step, and then failed with HTTP 500 at the final commit: `ActiveRecord::RecordNotUnique`
on `client_emails_effective_digest` (`app/models/concerns/email_contact_binding.rb:90`,
`finalize_sign_up_binding!`). The new candidate Client and its `client_emails` row remained
unfinalized in the development database.

## Cause (source reading)

The only check against another account's address is the partial unique index
`client_emails_effective_digest`
(`binding_finalized_at IS NOT NULL AND binding_released_at IS NULL`), reached at final commit. The
entry (`Auth::App::Sign::Up::EmailsController`), OTP issuance (`EmailSignUpOtpIssuer`) and OTP
verification (`EmailSignUpOtpVerificationCommitter`) check only the candidate's own state. The same
behavior exists at HEAD `b30345216`; it was not introduced by the current worktree.

## Owner decision (2026-11-05)

- The screen is identical for registered and unregistered addresses: it says the OTP was sent and
  shows the OTP entry page. Nothing reveals whether the address is registered.
- For a registered address, send nothing: no sign-up OTP and no notice email.
- For a registered address, accept no code; respond exactly as for a wrong code, under the same
  attempt limits.
- Keep the unique index as the last defense for concurrent sign-ups; a violation at final commit
  becomes the same refusal, cleans up the candidate and ceremony, and is never a 500.
- Responses, timing and logs must not distinguish registered from unregistered addresses.

## Open points for implementation

- Where the registered check runs (entry, issuance, verification) and how it stays race-free with a
  concurrent registration or release.
- Equalizing response timing between the send and no-send paths.
- Whether ORG and COM email sign-up share the defect; check before implementation.
- Update `docs/security/sign-up-sequence.md` and the related ADRs.

## Tests required

1. Registered address: no OTP issued and no email sent; the screen matches the unregistered case.
2. Registered address: no code is accepted; the response matches a wrong code.
3. Two concurrent final commits for one address: exactly one succeeds; the other is the refusal,
   not 500.
4. Other accounts are unchanged in every refusal case.

## Related review of the other email OTP flows (2026-11-05, source reading only, nothing run)

- APP email sign-in: no defect of this kind found. The lookup reads only effective bindings
  (`EmailValidation#find_email_with_timing_protection`), an unknown address takes a dummy OTP path
  with a minimum response time, and cooldown responses are identical. One residual signal: when OTP
  enqueue fails, only a registered address can reach the 503 delivery-failure page
  (`Auth::App::Sign::In::EmailsController#process_email_authentication`); it requires an
  infrastructure failure to observe.
- APP email registration after sign-in (`Base::App::Identity::Emails::RegistrationsController`): the
  same gap as sign-up. No check against another account's effective address before the OTP is sent,
  so an OTP mail can be sent to an address another account owns. At completion,
  `EmailCredentialRegistrationOtpFinalizer` consumes the OP ticket and then writes the binding; a
  `client_emails_effective_digest` violation is an `ActiveRecord::StatementInvalid`, mapped to
  `DependencyFailure` and returned as 503 after the ticket was consumed. Under the shared RP path
  this flow currently refuses with 503 anyway (step-up unit 6b, contact registration pending).
- ORG: `operator_emails` has a unique index on every non-null `address_digest`, including
  candidates, so a duplicate fails when the candidate row is inserted, not at completion. How ORG
  sign-up and registration report that failure, and whether it reveals registration, was not
  checked.
- Owner decision (2026-11-05): apply the decision above (send nothing, accept no code, same
  response, no 500) to the APP post-sign-in email registration too. ORG is out of scope for now. The
  post-sign-in registration is owned by the step-up contact-registration redesign; coordinate with
  it rather than editing the finalizer separately.

## Telephone (APP), added 2026-11-05

Owner decision: handle the same way as email, in this session, for both sign-up and post-sign-in
registration. For a number another account holds as an effective binding: the screen is the same as
for any other number, no SMS is sent, no code is accepted (same response as a wrong code), and a
final-commit violation becomes the same refusal, never 500 or 503.

Cause (source reading and the development database's index definitions, not run): the only check
against another account's number is the partial unique index `client_telephones_effective_digest`
(`binding_finalized_at IS NOT NULL AND binding_released_at IS NULL`). The OTP issuer
(`TelephoneCredentialRegistrationOtpIssuer`) and the finalizers
(`TelephoneCredentialRegistrationOtpFinalizer`, `SignAppUpTelephoneRegistrationFinalizer`) check
only the candidate's own state. Expected effects, unverified at runtime: an SMS sent to another
account's number, and a 500 or 503 at final commit. SMS has a per-message cost and can be abused to
send unwanted messages, so suppressing the send matters more than for email.

Tests required: the same four as for email, for sign-up and for post-sign-in registration, plus a
check that no SMS adapter call happens for a registered number.

## Existing test coverage (review 2026-11-05, reading only)

Covered today:

- Entry only: sign-up beside an effective email or telephone creates a separate candidate Client and
  leaves the existing binding and owner unchanged
  (`test/controllers/auth/app/up/emails_controller_test.rb` "create beside an effective email ...",
  `test/controllers/auth/app/up/telephones_controller_test.rb` "create beside an effective telephone
  ..." and "sign-up beside an effective telephone ...").
- Entry enumeration parity between pending and registered destinations ("fresh sessions cannot
  distinguish pending and registered ... sign-up", email and telephone).
- Model level: one effective binding per destination and per owner, including concurrent
  finalization (`test/models/client_email_test.rb`, `test/models/client_telephone_test.rb`,
  `test/models/contact_binding_constraints_test.rb`).
- Unfinished-registration hold (`test/integration/sign_up_contact_hold_refusal_test.rb`); this
  covers only unfinished owners, not registered ones.

Missing, which is why the incident passed the suite:

- No test continues past entry with a registered destination: OTP entry, OTP acceptance, birthdate,
  final commit. The incident (500 at final commit) is not exercised for email or telephone.
- No test of a signed-in user registering an address or number that another account holds.

Contradicting the owner decision, to be changed in the same work:

- The email tests "create beside an effective email ..." and "create delivers only the independent
  candidate OTP ..." assert that an OTP email is enqueued for a registered address
  (`assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob`).
- The telephone test "create beside an effective telephone ..." asserts that an SMS is enqueued
  (`assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob`). These must assert zero deliveries for
  a registered destination while keeping their no-overwrite assertions.

Required integration tests (email and telephone each):

1. The incident path: sign in is abandoned, the browser switches to sign up, enters the registered
   destination, and submits a code and the birthdate. Assert: nothing delivered, no code accepted
   (an explicit raise is acceptable at verification or final commit, per the owner decision below),
   the existing Client and contact unchanged, no session for either account, and the candidate
   cleaned up.
2. Entry and issuance parity: registered and unregistered destinations give the same status, page
   and redirect through the OTP entry page. Do not compare OTP verification responses: the owner
   decision below requires an explicit incident failure when verification reaches a registered
   destination.
3. Race: a destination becomes registered by another flow after this sign-up's OTP was sent; the
   final commit gives the same refusal, not 500.
4. Signed-in registration of another account's destination: nothing delivered, no code accepted,
   other account unchanged, no 500 or 503 caused by the unique index.

## Owner decisions on check points and timing (2026-11-05)

Applies to email and telephone, sign-up and post-sign-in registration.

- Check at both points:
  1. Before issuing the OTP (primary). A destination another account holds as an effective binding
     gets no OTP. The response is the same "OTP sent" page as for any other destination.
  2. When verifying the OTP and at final commit (defense). Reaching either point with a registered
     destination means the first check failed or a race happened. The owner treats this as an
     incident: no code may be accepted, and the request may end by raising (an explicit, observable
     failure) instead of a crafted user response. It must still change nothing: no binding, no
     session, no change to the other account. This supersedes "the response matches a wrong code"
     and "never 500" above for these two points only; the entry and issuance responses keep full
     parity.
- Response timing: the owner wants the send and no-send paths to be indistinguishable by timing,
  using the simplest reliable method. Proposal: reuse the existing minimum-response-time floor
  (`EmailOtpResponseTiming#ensure_min_elapsed`, already used by email sign-in) around the whole
  create/resend action, and keep the actual delivery asynchronous (job enqueue) so the send path
  does no slow network I/O in the request. Set the floor above the observed slowest path, and add a
  test that both paths call the same floor rather than measuring wall-clock time.

## Follow-up after `specs/browser-flow-state-cookies` (owner, 2026-11-06)

Not yet started; the owner scheduled it after the browser flow cookie change. Suspected, not
verified: registered destinations now get no send, so they never accrue the per-candidate cooldown
that unregistered destinations accrue. Repeated sends could then reveal registration through the
cooldown response. Make cooldown and send-budget accounting identical for registered and
unregistered destinations, and connect it to the destination budgets in
`docs/backlog/2026-10-22-email-sign-up-delivery-limits.md`,
`docs/backlog/2026-10-22-telephone-sign-up-delivery-limits.md` and
`docs/backlog/2026-10-22-sign-up-confirmation-resend-limits.md`.
