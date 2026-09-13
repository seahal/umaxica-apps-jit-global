# Authenticated sign-in guard: test alignment

- Spec: a new sign-in must not replace an authenticated session (`409` plaintext, `Cache-Control: no-store`).
- `AuthenticationModeSwitchGuard` is the shared response. It must not live on `PasskeySignInFlow`: that concern is included by non-controller harnesses and is also the cryptographic core, not the session-availability gate.
- Guard remains on guest sign-in controllers and on the org Normal/Emergency passkey ceremonies.
- Social `link` while authenticated is account linking, not a new sign-in. `step_up` on the social session/callback is not the step-up surface and is refused with the same `409`.
- Org Normal passkey/secret ceremonies require the Entra transaction. Rate-limit callbacks must run before that refusal so unauthenticated hammering still receives `429`.
- Org secret rate-limit is actor-keyed (`secret_credential_create_actor`) because the browser no longer submits an identifier.
- Health assertions used `/x` regexes that discarded the spaces in `Health status`; that is a test bug, not a health payload change.
