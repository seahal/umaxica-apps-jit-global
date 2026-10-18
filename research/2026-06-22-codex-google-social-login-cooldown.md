# Google Social Login Cooldown Log Note

## Context

Google social sign-in appeared intermittent during local verification on 2026-06-22. The observed
sequence mixed successful Google provider callbacks with user-visible failures after the callback.

## Observed

- The Google provider callback reached `/social/google/callback` and completed on the Sign callback
  side.
- The callback state was consumed, the social ceremony candidate was stored, and Acme completion
  found the existing `ClientGoogleIdentity`.
- Acme completion then attempted to establish the signed-in session through
  `Acme::App::Social::AuthenticationsController#complete_social_login!`.
- When the same user already had a freshly created `ClientToken` inside the 30-second
  `AuthenticationBase::LOGIN_COOLDOWN` window, `check_login_cooldown!` raised
  `AuthenticationBase::LoginCooldownError` and the response was `429 Too Many Requests`.
- A browser retry of the same `social_ceremony_result` then failed closed because the ceremony
  transaction and candidate are one-shot and had already been consumed.

## Why It Matters

This is expected behavior, not evidence that Google OAuth itself failed. Future debugging should
separate these cases:

- provider/callback failure before Sign stores ceremony evidence;
- successful provider callback followed by Acme login cooldown;
- retry or refresh of an already consumed social ceremony result.

For the second and third cases, the correct classification is cooldown or replay-safe fail-closed,
not provider instability.

## Open Questions

- The current user decision is that the login cooldown behavior is desired and should remain in
  force.
- If the user experience needs clearer copy later, handle that as presentation work without
  weakening the cooldown or one-shot ceremony guarantees.

## Promotion Candidate

The accepted security decision is captured in
`adr/social-login-cooldown-and-one-shot-completion.md`.
