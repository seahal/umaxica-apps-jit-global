# Enforcement Standing, Appeal, and Recovery Implementation

## Scope

This change removes the legacy Bulletin dependency from the sign-in checkpoint participant and
implements the first self-service operational layer for Unified Enforcement.

## Delivered behavior

- `app`, `com`, and `org` each expose Account Standing at `/identity/standing`; it derives the
  public status only from visible in-force Cases and Effects.
- Appeal records are realm-local, encrypted at rest, limited to one record per Case, and redact
  their statement without deleting the decision record.
- Org review is a step-up-protected noun resource. The model rejects an applying or approving
  operator as the reviewer and records submitted/approved/rejected audit events without appeal
  content.
- `app` and `com` have an open, generic, verified-email-OTP recovery entry. It creates a short-lived
  recovery ceremony only for a visible verification-required security lock and never creates a
  normal authentication session. Completion ends only the matching Case with
  `verification_completed`.
- The recovery ceremony also provides the currently implemented self-service appeal entry for that
  verified subject. Hidden Cases are never selected or rendered.

## Deliberate follow-ups

- Passkey and TOTP recovery proofs. Verified-telephone OTP is not a follow-up: SMS was rejected as
  an authentication proof, so telephone OTP stays limited to sign-up and telephone registration.
- App-in notification delivery and an inbox presentation.
- Self-service appeals for eligible visible Cases that do not have a verification-required security
  lock.
- Content moderation policy, content targets, and moderation-specific Standing explanations.

## Verification

Focused parallel coverage passed for checkpoint cleanup, Standing routes/value object, appeal state
transitions and org review, recovery ceremony records, and the relevant controller paths.
`zeitwerk:check` passed. The parallel database cloner now incorporates migration contents in its
staleness digest so new migrations rebuild worker databases without committing unrelated schema
dumps.
