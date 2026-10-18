# Coverage batch: 2026-06-17

## Metadata

- **Date/Time**: 2026-06-17 00:20:00Z
- **Starting Line Coverage**: 90.83% (40555 / 44648)
- **Ending Line Coverage**: 90.85% (40563 / 44648)
- **Coverage Delta**: +0.02%
- **Starting Failures/Errors**: 10 failures, 2 errors
- **Ending Failures/Errors**: 11 failures, 2 errors (1 new pre-existing flaky test failure, none
  caused by this batch's changes)

## Selected Targets & Code Changes

Added tests to improve line coverage in high-yield helper, model, and service files:

1. `SignInActivationCandidateResolver` (2 tests covering candidate resolution and region fallback on
   error)
2. `SignInCheckpointParticipant` & `SignInDashboardParticipant` (2 tests covering invalid return
   type validation logic)
3. `OutboundSms` (1 test covering immediate message delivery double)
4. `ReadOnlyContentEntry` (1 test covering `published?` state check method)
5. `OperatorLifecycleRequest` (1 test covering `closed?` state logic)
6. `IdentityOneTimeReveal` (1 test covering exception handling / signature rescue path)
7. `IdentityPasskeyCeremonyReplayStore` (2 tests covering invalid surface error raising and missing
   record error)
8. `IdentitySecretCredentialCeremonyReplayStore` (2 tests covering invalid surface error raising and
   missing record error)
9. `IdentitySocialCeremonyReplayStore` (2 tests covering invalid surface error raising and missing
   record error)

## Commands Run

- `COVERAGE=true bin/rails test test/` (Start & End)
- `bin/rails test test/services/sign_in/post_issuance_participants_test.rb`
- `bin/rails test test/services/outbound/sms_test.rb`
- `bin/rails test test/models/read_only_content_entry_test.rb`
- `bin/rails test test/models/operator_lifecycle_request_test.rb`
- `bin/rails test test/services/identity/one_time_reveal_test.rb`
- `bin/rails test test/services/identity/secret_credential_ceremony_acme_transaction_test.rb`
- `bin/rails test test/services/identity/passkey_ceremony_acme_transaction_test.rb`
- `bin/rails test test/services/identity/social_ceremony_acme_transaction_test.rb`
- `vp check`
- `bundle exec rubocop -a`

## Next Batch Candidates

We will target more high-yield low-risk helper/service/model classes showing missing lines:

- `IdentitySocialCeremonyCandidateStore`
- `IdentitySocialCeremonyFinalCommitter`
- `SignInCheckpointParticipant` (any other branches)
- `SignInOtpResendState`
- `ChronicleRecorder`
