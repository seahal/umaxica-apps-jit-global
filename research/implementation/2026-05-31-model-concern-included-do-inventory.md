# Model Concern `included do` Inventory Notes

## Context

- Original plan/spec: Japanese maintenance request to inventory model concern `included do`, avoid
  banning Rails-idiomatic model concerns, and make at most one small safe improvement.
- Related ADR/docs/plans: `docs/index.md`, `adr/README.md`, `plans/README.md`,
  `.agents/harnesses/rules/generic/rails-concerns.mdc`.
- Implementation date: 2026-05-31.

## Decisions Made During Implementation

- Decision: Treat model concern `included do` as Rails-idiomatic when it registers focused
  validations, scopes, encryption, and lifecycle callbacks whose purpose matches the concern name.
  - Why: Model concerns differ from controller concerns that hide authentication or authorization
    callbacks; the model registrations are normal Rails composition points.
  - Alternatives considered: Removing `included do` or moving declarations to class methods. Both
    would be broader and less Rails-idiomatic than this task allows.
  - Follow-up needed: Promote a small model-concern guidance section if this inventory becomes a
    recurring review checklist.

- Decision: Classify `Email` as improvement-priority but do not alter behavior in this pass.
  - Why: It mixes normalization, digest, encryption, OTP defaults/state, lookup scope, and
    validations. It also uses `after_initialize` to populate OTP fields. Those are exactly the
    hidden requirements that should be made visible before any split.
  - Alternatives considered: Splitting `Email` into normalization/digest/encryption/OTP concerns.
    Deferred because it would touch authentication and OTP behavior with a larger blast radius.
  - Follow-up needed: Split only after tests cover all including models (`ClientEmail`,
    `OperatorEmail`, `VisitorEmail`) and callback order.

## Inventory Summary

- Classification A: `PublicId`, `SingleUseToken`, `ReferenceRecord`, `DpopProofStateable`,
  `OauthCallbackStateable`, `DeviceSessionable`, `BannerModel`, `Retainable`, `HasBirthdate`,
  `Occurrence`, `CollectiveUnit`, `CollectiveMembership`, `OidcConnectionRecord`,
  `MfaStatusTrackable`, `MfaStatusCredential`, `SecretCredential`, `Account`, `Identity`,
  `Withdrawable`, `Preference::Resettable`, `CoreRpBridge`, `PublisherPostMaster`,
  `NotificationOwnerRecord`.
- Classification B: `PublisherPostDocument`, `SignUpFlowTicket`, `TokenStatusManagement`, `Version`,
  flow namespace concerns (`Flow::Base`, `Flow::SignIn`, `Flow::SignOut`, `Flow::SignUp`,
  `Flow::Withdrawal`).
- Classification C: `Email`, `Telephone`, `SignFlow`, `SignOutFlow`, `WithdrawalFlow`,
  `RefreshTokenable`, `SessionOidcConnection`.

## Changes

- Added a requirements/registrations comment to `app/models/concerns/email.rb`.
- Added `ClientEmailTest` coverage for normalization-before-digest and OTP `after_initialize`
  defaults.

## Review Notes

- Tests run: `bundle exec rails test test/models/client_email_test.rb`; `bundle exec rails test`.
- Tests not run: none requested.
- Static checks: `bundle exec rubocop` failed on pre-existing offenses outside this change
  (`Rails/LexicallyScopedActionFilter`, `I18n/RailsI18n/DecorateString`, `Layout/LineLength`).
- Documentation or ADR promotion needed: none yet; this is a handoff note, not accepted policy.
