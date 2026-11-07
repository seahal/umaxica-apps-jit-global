# Hands-On Review of Social Link and Unlink With Step-Up (After O-9)

Date: 2026-11-06

Status: Backlog. The owner wants to try this in development once `specs/op-mediated-step-up` O-9
(Base → Visa → Auth → Visa → Base) is connected; nothing here is a new requirement.

## Intended behavior (contract, not yet runtime-verified)

- Signing in or signing up with Google or Apple needs no step-up.
- After sign-in, starting a Google or Apple link needs a current step-up, including right after sign
  up. Base starts it from `/identity/social_identities`; Base checks step-up evidence before asking
  Visa for the admission; Auth runs the provider ceremony and writes the link.
- Unlinking happens on Base and needs a current step-up, checked at Base's own write boundary.
  Removing the last sign-in method is refused.
- If the user has no step-up method yet (for example signed up with Google only), Base verification
  sends them to the bootstrap choice (register a passkey or TOTP first,
  `Base::App::VerificationsController#redirect_to_bootstrap_choice`). Bootstrap under the RP cell path
  is out of scope of the step-up spec and is unverified
  (`2026-11-03-base-verification-setup-bootstrap-rp-cell.md`).
- Current code before O-9 (for comparison): Auth `AppSocialCeremonyEntry#require_social_link_step_up!`
  and `Auth::App::Settings::{Googles,Apples}Controller#require_step_up_for_mutation!`.
- After O-9, the APP identity hub keeps only the Base social identities link; the Auth
  `settings/google` and `settings/apple` show/edit pages and their hub links are removed.

## Try in development

1. Sign up with Google, register nothing else, then start an Apple link from
   `/identity/social_identities`. Expect the bootstrap choice.
2. Register a passkey, start the Apple link again. Expect step-up, then Visa, Auth, Apple, and a
   return to Base showing Apple as linked.
3. Unlink Apple from the same page with a current step-up. Expect it to be removed.
4. With Google as the only sign-in method, try to unlink Google. Expect a refusal.

Record what differs from the expectations above, with the development log, before deciding changes.
