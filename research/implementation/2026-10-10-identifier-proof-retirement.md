# Identifier proof retirement inventory

Observed on 2026-10-10 at HEAD `2a1644f73238839ed7ed513bd4681ea393a86682`, with
uncommitted implementation changes. Authority: nine.md P3d and CONTACT-5 in
`docs/checklists/contact-identifiers.md`. This inventory is preparation, not completed acceptance.

## Source database observations

Read-only Rails column introspection used the owned isolated manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, run `20261010p8b`, host `primary`.
All six current tables retain `otp_private_key`, `otp_counter`, and `otp_expires_at`.
Client and Visitor Email/Telephone require all three, with empty-string or negative-infinity
defaults. Operator Email/Telephone require key and counter with no defaults; their expiry is
nullable. Consequently, removing empty initialization alone makes ordinary Operator creation
violate NOT NULL. This is a schema dependency to implement, not a new domain decision.

Keep `otp_attempts_count`, `locked_at`, and explicit `otp_last_sent_at`: these belong to the
independent channel failure/cooldown policies. Keep Step-Up fields under their separate owner.

## Current consumers and distinctions

- Six concrete identifier models still declare encryption of `otp_private_key`.
- EmailOtpPolicy and TelephoneOtpPolicy still initialize empty key/counter values solely for the
  old schema. Remove these assignments together with schema retirement, retaining failure counts.
- EmailCredentialRegistrationOtpIssuer and TelephoneCredentialRegistrationOtpIssuer read the
  APP/COM `credential_registration_otp_context` to reject legacy candidates. Removing this guard
  before rejecting or retiring legacy persisted proof could admit previously excluded candidates.
- Four APP/COM identifiers retain both serialized context columns and filter-attribute names.
  The legacy contexts have shape/finite-time CHECK constraints and eight UPDATE triggers across
  app/com. Reconcile their constraints, attached functions and exact trigger inventories before
  removing columns. Applied migrations remain untouched; forward migrations own retirement.
- Ceremony transaction `otp_expires_at`, terminal-fact triggers, receipt deadlines, and controller
  expiry reads are current proof authority and MUST remain.
- Forbidden claim names in IdentityEmailCeremonyContract, IdentityTelephoneCeremonyContract,
  and IdentityStepUpCeremonyContract remain security guards, even after source-column removal.
- OtpTelephoneAdapter rejects legacy counter arguments. Preserve explicit rejection; it is not
  an active identifier-owned proof generator.
- A text search found 231 Ruby test files and 1,080 matching lines for the three names. This is
  a mixed lexical count, not 231 obsolete consumers: many refer to current ceremony deadlines or
  forbidden payloads. Classify each change by receiver and purpose rather than bulk replacement.

## Execution order

1. Add public creation/issuance regressions demonstrating six identifiers work without source
   proof fields and that legacy serialized proof cannot authorize a new ceremony.
2. Inventory fixture attributes and source-schema dependencies, including old context checks,
   functions and triggers. Keep current ceremony and forbidden-claim tests.
3. Prepare forward schema retirement using the authorized disposable scope; inspect exact current
   objects before applying. Do not execute destructive operations on shared or retained databases.
4. Remove source encryption/initialization and retire classified obsolete test attributes at the
   same slice boundary. Preserve counter-argument rejection and current ceremony verification.
5. Execute focused six-model/issuer/withdrawal/rotation/trigger checks, then both full gates before
   dependent P3e work. Rebuild verification is separately required; source inspection is insufficient.

No schema mutation or new application change was performed during this inventory. The latest full
Rails result is recorded separately in `evidence/2026-10-10-public-id-update-boundary-R7N2.md`;
it does not certify the future retirement slice.
