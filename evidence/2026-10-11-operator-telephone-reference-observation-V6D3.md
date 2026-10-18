# Operator Telephone cross-database reference observation

Observed on 2026-10-11 against HEAD `6007f0562fca205ce5b592aa82261b9836277814`, with uncommitted
implementation, migration, script and documentation changes. This is read-only P2/P6 preparation
while the fresh P3d full gate runs; no new feature edit was made.

A manifest-fenced Rails runner on `20261010p3d2` inspected actual columns and connection
configurations. Exit 0: OperatorTelephone has no physical `public_id` column, its PK SQL type is
bigint, and its source and ceremony models resolve to different physical databases. No values,
telephone numbers or keys were printed.

Current code in TelephoneCredentialRegistrationOtpIssuer,
TelephoneCredentialRegistrationOtpResendIssuer and
TelephoneCredentialRegistrationOtpVerificationCommitter selects `telephone.id.to_s` for
OperatorTelephone, whereas Client/Visitor use their public identifiers. The org principal base uses
org_zenith; the ceremony transaction uses org_ticket.

This is a concrete source-reference contract gap to reconcile under nine.md's internal-PK/cross-DB
identifier requirements. It is not evidence that every identifier is compliant, and passing OTP
verification tests do not establish that compliance. Map all caller/resolver/transport dependencies
and the permitted DB immutability mechanism before implementing the owning P6 slice. Do not weaken
the contract, silently fall back to the PK, or invent an external-provider exception. No broader
domain redesign or new trigger approval is implied by this observation.
