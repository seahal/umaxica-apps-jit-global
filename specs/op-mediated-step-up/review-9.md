# Review 9: revision-13 design proposal (O-9 to O-12)

Date: 2026-11-04. Reviewer: Claude Code. Disposition: changes required before acceptance. Input:
`contracts/revision-13-design.md`. Source reading only; nothing was run.

## R9-1 High — O-9 admission can be redeemed in an attacker's browser

Auth holds no session for a user signed in through the Base RP (observed in development:
`blank_access_token` on Auth `settings/google`). The proposal binds the admission to actor, `sid`,
RP session and purpose, but does not say how Auth proves the redeeming browser is the user's. A
leaked admission (URL history, Referer, logs) would let an attacker redeem it in their own browser
and link the attacker's provider identity to the victim's account. Required: deliver the admission
by POST, never in a GET URL; at redemption, run the existing ceremony binding confirmation round
trip (Auth binding confirmed by Base in the same browser) before any provider redirect or passkey
ceremony; tests for redemption from a second browser.

## R9-2 Medium — O-10 reverses the established lock order without need

The proposed order (OP first, Zenith principal second) contradicts
`adr/root-login-establishment-boundary.md` and the current actor-first code, and the proposal itself
lists more than seven paths to rework. The gap can be closed in the existing order: lock the Zenith
principal, open the OP transaction and take device, root and grant locks, recheck the event, perform
and commit the Zenith write, then end the read-only OP transaction. Redesign O-10 on that nesting;
list only paths that take OP locks before principal locks as violations to fix.

## R9-3 Accept with qualification — O-11

The move inventory is accepted in substance. Ordinary passkey registration moves to Auth
`settings/passkey` (O-9 admission required). Bootstrap keeps its current
`verification/registration/passkey` entry unchanged, per the owner's out-of-scope decision; the two
entries share ceremony code but have distinct purposes.

## R9-4 Owner decision applied — O-12 root-token dependencies

Q-1 (`identity/mfa/challenges`, Security Mode change) is part of this change and is in scope; the
proposal's "outside" classification is withdrawn. Owner decision 2026-11-04: session listing and
revocation (`identity/sessions`, `identity/revocations/others`, selectors), APP Secret (`secrets`,
`secret_issuances`, `secret_presentations`), ORG `identity/secret_credentials` and
`identity/removals` are out of scope. Under the RP cell path they must refuse explicitly with a
localized message and a logged reason code, never pass a nil root token or fail with an exception.
They are recorded in a backlog item.
