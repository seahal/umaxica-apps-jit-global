# Telephone proof reference cutover precondition

HEAD: `4f0358c86a45e1eac43c73b5e81d9fb6df3c4b34`; application/test changes remain uncommitted. Rails
full public-link Gate 2 is running. This was a read-only source investigation and acceptance
clarification, not a data migration or executed cutover.

`TelephoneCeremonyOtp#telephone_otp_digest` includes telephone_candidate_ref in its keyed HMAC
input. Verification also compares that reference, actor, session, operation and purpose. Thus
rewriting an existing ceremony's numeric candidate reference without the original proof changes
verification semantics. The verifier cannot be recomputed from its stored digest alone. Terminal
proof fields are protected from mutation as well.

ID-3a now explicitly requires control/drain of old numeric-reference writers, still-valid issued
proof, queued delivery and bounded original-operation receipts before consumer cutover. Source
public-ID backfill is insufficient by itself. This preserves I/C05's already-issued proof contract
and E's no weak legacy-proof fallback; it grants no new runtime fallback or mutation authority.
Synthetic drain/cutover verification and operational implementation remain required/not yet
executed.

Oxfmt formatted the affected checklist; `git diff --check` passed. No secrets, contact data, actual
OTP, database rows or shared resources were read or modified. No new application edit occurred while
the full gate ran. The added checklist paragraph is owned by this task.
