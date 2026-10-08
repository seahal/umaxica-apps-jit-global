# Identifier completion dependency inspection

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes were inspected. This is a code inspection, not a passed test gate.

## OTP ownership is not complete

`CommonOtp` still creates HOTP secrets and counters on Contact records. Signup delivery reconstructs
the code from `record.get_otp` and sends `sign_up_flow_ref/sign_up_otp_counter`.
Authenticated registration delivery also checks Source counter/private-key material. Auth sessions
still write `email_otp_context`. The new channel-specific ceremony primitive tests therefore do not
prove that the existing signup/signin/recovery/withdrawal/registration paths use ceremony-owned
verifiers. Source fields and serialized proofs cannot be removed before those consumers change.

The proposed transaction/generation Email payload and SMS v3 binding are the direct dependency
for migrating late-delivery guards without a legacy fallback. The user's additional-approval
message does not identify which outstanding proposal it accepts; no new payload was assumed.

## Irreversible identity deletion is not complete

`WithdrawalPersonalDataAnonymizer` still replaces original email/telephone PII with synthetic
values. Subsequent physical archive would fingerprint those synthetic values, not the dead original
identifier. `RetentionPurgeJob#purge_operators` still performs set-based parent deletion after
cross-database cleanup. History's restrictive identity FK and the pending legal/whole-Identity
erasure decision must be resolved together; neither cascade deletion nor invisible history loss
was introduced.

## Finalized HMAC maintenance remains refused

Generated APP/COM schema functions explicitly reject changes to finalized address/number digests.
The rotation operation still saves the recomputed digest and therefore cannot rotate these rows
under the ordinary role. The earlier real PostgreSQL test errors remain authoritative. The proposed
limited maintenance roles/connection and forward SQL DDL require explicit authorization; no
trigger-disable flag or weakened binding guard was added.

## Verification is incomplete

The ARE drill currently fails closed on two task-origin orphan COM Email rows, identified in
`2026-10-08-are-orphan-test-artifacts-3V7B.md`; targeted direct cleanup approval is pending.
The route inventory expects seven RPs despite the unchanged HEAD map containing ten, and the
architecture gate rejects existing increased visibility debt. Neither failed gate is accepted as
green. Full Rails tests, full RuboCop, remaining harnesses and final schema disposition have not
established the Definition of Done. The executable acceptance checkboxes remain incomplete.
