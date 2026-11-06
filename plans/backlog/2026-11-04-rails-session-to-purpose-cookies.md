# Replace Rails Session State With Purpose-Specific Encrypted Cookies

Date: 2026-11-04

Status: Backlog. Owner direction recorded; not scheduled. No code changed.

## Why

Sign-in, sign-up, social and Visa flows sometimes fail until the user deletes cookies (for example
"this screen is out of date", OmniAuth `csrf_detected`). One cause is that many unrelated flows
share one Rails session cookie per host:

- `config/initializers/session_store.rb` uses `:cookie_store`; `JitSessionCookieConfig` sets one
  host-only cookie (`__Host-session` when secure), `expire_after: 14.days`.
- Keys have no individual lifetime, so values written by an earlier flow or an earlier code version
  stay for up to 14 days and trip later checks.
- One cookie is last-write-wins: two tabs running different flows overwrite each other's keys.
- One cookie has a size limit of about 4 KB that grows with every flow added.

Other causes are separate and not covered here (an old service worker on the Auth hosts, DBSC,
ceremony binding cookies).

## Owner direction

- Keep the Rails session for the CSRF token only.
- Give every other use its own Rails encrypted cookie, one per purpose, holding a structured value.
- Give each cookie only the lifetime its flow needs, and have it disappear automatically after that.

## Mechanism in Rails (from framework knowledge; confirm against the Rails 8.2 guides and source

under `generic/source-policy.mdc` before design)

- `cookies.encrypted[:name] = { value: {...}, expires: 10.minutes, httponly: true, secure: ..., same_site: ... }`
  encrypts and authenticates the value with keys derived from `secret_key_base`.
- With `config.load_defaults(8.2)` (`config/application.rb`), the cookie serializer is JSON and
  cookies carry metadata (`use_cookies_with_metadata`): the cookie name is embedded as the purpose
  and `expires` is embedded as an expiry inside the encrypted message. The server then rejects an
  expired value or a value copied into another cookie name even if the browser still sends it, so
  expiry does not depend on the browser alone. Verify both settings are in effect in this
  application.
- Use JSON values, not YAML: YAML (and Marshal) deserialization of cookie data is a known code
  execution risk, and JSON is already the framework default. Keep values to identifiers, codes and
  timestamps; no secrets or raw tokens in cookies, even encrypted.
- Use the `__Host-` prefix (Secure, Path=/, no Domain) like the session cookie, so each FQDN owns
  its cookies.

## Design points to decide

1. Naming: one cookie per purpose (for example social OAuth state, OIDC pending flow, sign-up
   sequence, telephone registration, return-path nonce, gates). Fixed names collide across tabs of
   the same flow; decide per flow whether that is acceptable or whether a flow reference (such as
   the existing `entry_ref`) selects the state instead.
2. Lifetime per purpose, aligned with the server-side expiry of the same flow (for example the 15
   minute authorization transaction, OTP lifetimes).
3. Recovery: an expired, missing or undecryptable cookie restarts the flow with guidance instead of
   failing (`adr/invalid-browser-credential-recovery.md`).
4. Where server-side state already exists (ceremony transactions, opaque admission store), keep only
   the reference in the cookie, not a copy of the state.
5. Count and size: browsers cap cookies per domain and total header size; inventory the result per
   host.
6. Ownership: one concern or value object per cookie purpose, with a fixed name, lifetime and
   schema; no ad-hoc `cookies.encrypted` calls in controllers.
7. `secret_key_base` rotation invalidates all of them at once; decide whether rotation support
   (`config.action_dispatch.cookies_rotations`) is needed.

## Current Rails session use (static count, 2026-11-04)

`session[...]` appears in controllers and services across Auth APP/ORG, Base APP/ORG/COM, Visa APP,
Warp and shared concerns. Most frequent keys: `inertia_clear_history` (36), surface-specific
`SESSION_KEY` / `session_key` (21), `user_telephone_registration` (9), `REENTRY_SESSION_KEY` (8),
`GATE_SESSION_KEY` (8), registration keys (10), the social OAuth group (`SOCIAL_STATE_*`,
`SOCIAL_FLOW_ID_*`, `SOCIAL_INTENT_*`, `SOCIAL_PROVIDER_*`, `SOCIAL_ENTRY_*`, `SOCIAL_RI_*`,
`SOCIAL_CEREMONY_GRANT_*`, about 40 uses), `OIDC_PENDING_FLOWS_SESSION_KEY`, OIDC logout keys,
`BROWSER_NONCE_SESSION_KEY`, `authentication_pt_nonce`, `auth_app_up_sequence_id`,
`staff_secret_credential_raw`, `client_secret_operation`, `timezone`, sign-out notice and bulletin
keys. OmniAuth itself also stores its `state` in the Rails session; moving it needs a decision on
the OmniAuth state store. `inertia_clear_history` is written by inertia_rails; check whether the gem
requires the Rails session. A full inventory (key, writer, reader, flow, lifetime, failure behavior)
is the first task.

## Not verified

- The Rails behavior above was not checked against Rails 8.2 documentation or source in this note.
- Which observed failures came from session state rather than other causes.
- The count is a text search; dynamic keys may be missing.

## Addendum (2026-11-05): owner intent

Added by the owner's request; the text above is unchanged.

- Scope of the problem: the Auth and Visa subdomains used by the APP and ORG surfaces repeatedly hit
  these failures. To resolve them, the owner decided to stop storing flow state in the Rails session
  on those hosts; the Rails session keeps the CSRF token only.
- Intent of the change: reduce user frustration (being sent back, or having to delete cookies to
  continue).
- Lifetime: the owner intended the purpose-specific encrypted cookies to have lifetimes aligned with
  the login (sign-in) lifetime. Design point 2 above instead aligns each cookie with its own flow's
  server-side expiry. Reconcile the two when this item is designed, per cookie purpose: which
  cookies follow the login lifetime and which keep a shorter flow lifetime.

## Reproduction observed 2026-11-05 (development, APP, Windows Chrome)

Steps: sign in with email on `auth.umaxica.app` and complete it; sign out from Base (Visa logout
confirmation, then `Base::App::SignOutsController`); from the Base sign-in entry, start sign-in
again.

Observed: Auth shows "この画面は古くなっています。最初からやり直してください。"
(`phase_violation_refused`). Request chain in `log/development.log`: `/sign/in/sentry` →
`/sign/in?entry_ref=...` → `/ceremony_bindings` → Visa `/ceremony_bindings/<id>/confirmation` →
`/sign/in?entry_ref=...` → `/sign/in?ri=jp` returns **409** with `sign.refused`
`reason_code: "missing_binding"`.

Cause (source reading): `SignInPhaseBindingControllerSupport#enforce_sign_in_phase_binding!` refuses
when a current sign-in flow exists but the request carries no flow binding. The current flow comes
from `SignInCycleLocator#current(include_terminal: true)`, which reads the Auth Rails session
(`session[session_key]`). The previous, completed sign-in flow is still referenced there after
sign-out, because sign-out runs on Visa and Base and does not clear Auth's session key; the new
entry's final redirect to `/sign/in?ri=jp` carries no flow binding. Deleting the Auth cookies works
around it. This is one concrete case of the "earlier flow state stays in the shared Rails session"
problem above; the purpose-specific cookie with a flow-bounded lifetime should make a new entry
independent of a finished flow.

Acceptance for that work: after a completed sign-in and a sign-out, a new sign-in from the Base
entry reaches the sign-in page without the refusal and without deleting cookies. Not yet checked:
whether this reproduces on every sign-out (an earlier sign-in after sign-out on 2026-11-05 did not
show it), and whether ORG behaves the same.
