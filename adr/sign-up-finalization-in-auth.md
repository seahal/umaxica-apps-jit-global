# Sign-up Finalization in Auth and Sign In First for Every Entry Method

## Status

**Accepted (2026-10-21, owner decisions D-69 U1–U6, D-105, D-128, D-131); written 2026-10-24 before
implementation (WU-05a); implemented 2026-10-24 (WU-05b … WU-05g and WU-06).**

## Context

APP email and telephone, and COM email and telephone, already create the pending principal in Auth
after a redeemed sign-up Admission. They finalize through the shared
`finalize_sign_up_from_checkpoint!` (Flow row lock, `SignUp::FinalizationPolicy`, principal writers,
`IdentityGraphProvisioner`, `SignUpStateMachine :finalize/:complete`). They then hand off to the
canonical Sign In flow.

APP Google and Apple do not. They have no pending principal in Auth, and the Base
`/social/authentication/completion` page commits the Client, External Identity and graph
(`IdentitySocialCeremonyFinalCommitter#commit_signup!`). It then issues the OIDC result directly
(`BaseAuthAdmissionCoordinator.register_result_and_issue!`) without the canonical Sign In policy.
That contradicts `adr/sign-in-first-and-sign-up-handoff.md`.

No ADR states that Auth may finalize a registration. The comment in `SignUpSocialBirthdateSupport`
and `adr/sign-up-authentication-handoff-and-social-rt.md` state the opposite for social sign-up.

## Decision

1. **Auth owns registration, never sessions.**
   - Auth may create pending principals and finalize sign-up through the shared operations on the
     principal writers.
   - It may not issue a Root or Browser Session, an OIDC code or a token. Root Session and OIDC
     authority stay with the authorization server (Base today, Visa after WU-02); RP Sessions stay
     with Base.
2. **One Finalization contract for the six paths:** APP email, telephone, Google and Apple; COM
   email and telephone. Google and Apple stay separate entry methods with their own requirements
   (`confirmation`, `birthdate`). They are never merged into one "social" method.
3. **Social pending Client (U1, P1–P5).**
   - It is created in Auth only:
     - under a redeemed Admission whose effective intent is sign-up (D-72);
     - after the provider evidence for that Admission's ceremony is verified;
     - after the confirmation POST passed the ceremony-bound Turnstile (`verify_for_ceremony`,
       action `social_signup_confirmation`).
   - It is one per Flow, recorded on the Flow under the Flow lock, in status
     `UNVERIFIED_WITH_SIGN_UP`.
   - It has no External Identity, contact or credential before Finalization.
   - It is never found by provider subject, email or browser.
4. **Candidate (U2, C1–C3).**
   - `IdentitySocialCeremonyCandidateStore` (PostgreSQL, OP database) holds only the verified
     provider principal.
   - `expires_at` is at most the attempt's curfew, the Flow lifetime and the provider-evidence
     lifetime.
   - Pages read it without consuming it. Finalization consumes it once, under the Flow lock.
   - An expired or mismatched Candidate is refused and never revived.
5. **Decisive commit (D-131) and deadline (D-105).**
   - Under the OP Flow/Binding lock, Finalization compares the Binding's `curfew_at` with the OP
     database clock (D-75).
   - At or after the deadline it fails closed: no authority, no session, no evidence.
   - Before the deadline, the principal database commits in one transaction:
     - the registered status (`VERIFIED_WITH_SIGN_UP` on APP, the same states on COM per D-128);
     - for social sign-up, the External Identity, after re-checking that `(issuer, subject)` is
       unregistered and not release-blocked under `ClientExternalIdentity.with_subject_lock`.
   - That commit decides "registered". After it, graph provisioning and OP Flow completion are
     completed idempotently later; they are never undone or deleted as compensation.
6. **Sign In First (U6, S1–S4).**
   - Every entry method ends in `handoff_to_sign_in_flow!` → canonical Sign In (eligibility,
     guardrail, checkpoint, MFA, selector, cooldown, session limit) → OIDC evidence → the
     authority's result receiver.
   - No sign-up path calls `register_result_and_issue!`.
   - A Sign In refusal after the decisive commit is a Sign In failure.
7. **Resume and re-registration (U5).**
   - Resuming an unfinished Flow requires authority over that Flow (its Admission and Ceremony), or
     a fresh provider authentication.
   - The same email or the same browser never grants ownership of a pending Client.
   - Completed identities, other people's Flows and other operations' data are never taken over.
8. **Removal (WU-05g).** The Base social completion keeps only the non-sign-up uses classified in
   two.md §5.H. Its sign-up branches, and `IdentitySocialCeremonyFinalCommitter#commit_signup!`, are
   removed after every caller is moved.

## Supersedes

- `adr/sign-up-authentication-handoff-and-social-rt.md`, where it places the social sign-up commit
  and its OIDC result at Base.
- The ownership statement in the `SignUpSocialBirthdateSupport` comment.

The checkpoint and Turnstile boundaries in `adr/sign-up-checkpoint-turnstile-boundary.md` and
`adr/turnstile-visible-placement-policy.md` are unchanged. The ceremony-bound social confirmation
Turnstile remains the documented stronger exception.

## Consequences

- A person who reaches Finalization seconds before the curfew may have to start again (D-105).
- A crash after the decisive commit leaves a registered principal with an unfinished Flow. The next
  access is an ordinary sign-in, and `SignUpAttemptDiagnosisInventory` (WU-26) classifies the state.
- The social sign-up gains the Sign In screens (MFA, checkpoint) that email and telephone sign-up
  already show.

## Verification

- **2026-10-24 (WU-05a … g, WU-06):** implemented, including the D-105 curfew comparison at
  Finalization. See `evidence/2026-10-24-wu05abc-finalization-adr-intent-entry-flow-W5AC.md`,
  `evidence/2026-10-24-wu05dg-social-sign-up-in-auth-W5DG.md`, and the WU-06 evidence record.
- The end-to-end Google sign-up test reaches exactly one Root at Base through canonical Sign In, and
  that Root keeps the provider ceremony's event time.
