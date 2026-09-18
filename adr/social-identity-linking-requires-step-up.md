# Social Identity Linking Requires Step-Up Authentication

## Status

Accepted (2026-09-14)

## Context

Adding a Google or Apple identity to an existing `app` account creates another AAL1 sign-in
credential. It is a credential-binding operation, not a profile-field update. Provider
authentication proves control of the Google or Apple identity; by itself, it does not prove that the
owner of the currently signed-in UMAXICA account approved binding that identity.

Without a fresh account-owner check, a party with temporary access to an existing session could bind
an identity it controls and retain a persistent sign-in path after that session is recovered.

This decision applies to post-enrollment linking on the existing-account settings path. Initial
Google or Apple enrollment is part of the sign-up transaction and follows that transaction's
authentication, state-machine, and provider-verification rules. It is not a post-login credential
link. Removing an existing social identity remains a sensitive credential-removal operation and
continues to require Step-Up and the existing no-lockout guard.

Base is the Identity Provider / Authorization Server authority. Auth performs credential ceremonies
and does not acquire account, session, token, authorization, or assurance authority through this
decision. See `adr/base-auth-ceremony-and-seven-rp-boundary.md` and
`adr/identity-authority-boundary.md`.

## Decision

Keep the existing fresh, scope-bound Step-Up requirement before an authenticated `app` account can
start linking a Google or Apple identity. Preserve the current `social_link` requirement, its
session/token/purpose/audience binding, and the existing one-time callback state and
account-consistency checks. Do not let provider authentication substitute for UMAXICA account-owner
approval.

Keep Step-Up on unlink/removal as well, together with the existing guard that prevents removing the
last eligible sign-in method.

The separate sign-up enrollment transaction does not acquire the post-enrollment link requirement.
It must continue to use its own validated sign-up state machine and provider-verification path.

Fresh primary sign-in is not automatically reusable as Step-Up evidence. This decision does not
change the Step-Up method set or freshness window.

## Security rationale

- A session alone cannot start a link transaction for an attacker-controlled long-lived social
  sign-in path; a fresh, account-bound Step-Up must authorize the link intent.
- Linking is the `1 -> N` credential transition described by the authentication-assurance contract.
- Initial enrollment is authorized by the sign-up transaction, while later linking modifies an
  already-established account's credential inventory. Those transitions have different owners and
  state machines.
- Google or Apple authentication proves control of the provider identity. It does not alone prove
  that the owner of the current UMAXICA account approved the binding.
- Unlinking removes a credential and therefore retains its separate Step-Up and no-lockout guards.

## Consequences

This makes a stolen or temporarily hijacked session insufficient on its own to add a persistent
Google or Apple sign-in path, and treats link and unlink consistently as sensitive credential
management. Linking from account settings retains the extra verification interaction. That UX cost
does not justify weakening this security boundary.

## Non-goals

This decision does not change:

- the Step-Up method set or freshness window;
- the Google or Apple OAuth/OIDC ceremony or callback architecture;
- the product AAL definition;
- the sign-up state machine;
- the Sign/Auth ceremony boundary or Base authority boundary;
- whether a fresh primary sign-in may satisfy Step-Up in a future design.
