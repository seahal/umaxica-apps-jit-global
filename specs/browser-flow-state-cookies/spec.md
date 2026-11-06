# Browser Flow State in Purpose-Specific Encrypted Cookies

Status: accepted by the owner on 2026-11-06. Nothing is implemented yet.

Predecessor: `plans/backlog/2026-11-04-rails-session-to-purpose-cookies.md`.

## Why

Sign-in and related flows keep browser-side flow state in the single Rails session cookie
(`config/initializers/session_store.rb`, `:cookie_store`, `JitSessionCookieConfig`, one host-only
cookie, `expire_after: 14.days`). Keys have no lifetime of their own, so state from an earlier flow
stays for up to 14 days and is read by a later, unrelated flow.

Observed on 2026-11-06 in development (`log/development.log`, `log/development.access.jsonl`):

1. A sign-in completed at 06:33 UTC.
2. A new sign-in began at 06:45 UTC through Base. The entry and ceremony binding succeeded and
   created a fresh Auth ceremony (id 57, no OTP, no evidence).
3. `GET /sign/in?ri=jp` then returned 409 "この画面は古くなっています。最初からやり直してください。"
   with `sign.refused` `reason_code: missing_binding`.

Cause (source reading): `SignInPhaseBindingControllerSupport#enforce_sign_in_phase_binding!` found a
current flow through `SignInCycleLocator`, which reads `session[:app_sign_in_flow_locator]` left by
the earlier flow. The new request carried no flow binding for it, so it was refused as stale. The
same class of failure is behind earlier "start over" refusals, OmniAuth `csrf_detected` that
disappeared after deleting cookies, and cross-tab interference.

## Owner decisions (2026-11-06)

- Move everything in one change; no interim "fresh entry supersedes leftover state" patch.
- One cookie per purpose. When two tabs run the same kind of flow, the newer one wins. The older tab
  gets the existing restart guidance, not an error page that requires deleting cookies.
- Earlier direction (2026-11-04): keep the Rails session for the CSRF token only; every other use
  gets its own Rails encrypted cookie, with only the lifetime its flow needs.

## Scope

In scope: every `session[...]` read or write in `app/` and `lib/` on Auth, Visa, Base, Warp, Core,
Palm, Tech and Edit, except the Rails CSRF token. A static count on 2026-11-06 found about 60
distinct keys. The largest groups are the sign-in flow locator (`SignInCycleLocator`), the sign-up
state (`SignUpSessionState`), the social OAuth group (`SOCIAL_*`), the session-limit gate, re-entry,
OIDC pending flows and logout, contact registration transaction references, step-up markers, the
browser nonce, sign-out notices and bulletins, `inertia_clear_history` and `timezone`.

Out of scope: DBSC; the Preference cookies; `__Host-auth_sid` and other cookies that are already
purpose-specific (they are listed in the inventory but not redesigned); changing what any flow
means.

## Design rules

- D-1 Owner per purpose. Each cookie purpose has exactly one owner (a concern or value object) that
  fixes the cookie name, lifetime, JSON schema, and the read, write and clear methods. Controllers
  do not call `cookies.encrypted` directly.
- D-2 Format. `cookies.encrypted` with a JSON value. With `config.load_defaults(8.2)`, Rails embeds
  the purpose `cookie.<name>` and the expiry (`expires_in` / `expires_at`) inside the encrypted
  message (verified in the vendored Rails source,
  `actionpack/lib/action_dispatch/middleware/cookies.rb`, `cookie_metadata` and
  `EncryptedKeyRotatingCookieJar#commit`). The server rejects a value past its embedded expiry or
  copied under another name even if the browser still sends it. Values are identifiers, references,
  nonces' digests and timestamps only: no secrets, OTPs, tokens or contact values. No YAML or
  Marshal.
- D-3 Attributes. `__Host-` prefix, `Secure`, `Path=/`, no `Domain`, `HttpOnly`. `SameSite=Lax`
  unless the inventory shows a purpose needs otherwise; record the reason per purpose.
- D-4 Lifetime. Each purpose's lifetime equals the server-side lifetime of the record it points to
  (for example the authorization transaction or OTP window), never longer. Purposes with no
  server-side record get the shortest lifetime that completes the step.
- D-5 Reference, not copy. Where server-side state exists, the cookie holds only a reference and a
  binding nonce; the server record stays the authority. The cookie never decides a state transition
  by itself.
- D-6 Newer wins at start. Starting a flow deletes and re-creates that purpose's cookie (O-3a). A
  request whose page binding or reference no longer matches the cookie gets the existing restart
  guidance and clears nothing else.
- D-7 Fresh entry. A new Base-issued admission (`entry_ref`) starts a fresh flow and replaces any
  leftover cookie of the same purpose; a leftover cookie can never block a fresh entry.
- D-8 Clear on finish. Completion, cancellation and refusal that ends a flow delete that purpose's
  cookie. Sign-out deletes all flow cookies of the host.
- D-9 Missing or invalid cookie. Missing, expired, undecryptable or wrong-schema values are treated
  as "no state" and lead to the restart guidance (`adr/invalid-browser-credential-recovery.md`),
  not 500. Log a fixed reason code, never the value.
- D-10 Rails session. After migration it holds only the CSRF token, the OmniAuth `state` (O-1) and
  `inertia_clear_history` (O-2). A static guard test fails on any new `session[...]` use outside the
  allowlist.
- D-11 No compatibility layer. Existing session values are not migrated; an in-flight flow at
  deployment restarts once (`generic/no-compatibility-layer.mdc`). Record this in the release notes.

## Owner decisions on the former open points (2026-11-06)

- O-1 OmniAuth `state`: follow the gem. OmniAuth keeps its `state` in the Rails session as the gem
  does; this is a documented exception to D-10. Our own social keys (`SOCIAL_*`) still move to
  purpose cookies.
- O-2 `inertia_clear_history`: documented exception to D-10; it stays in the Rails session.
- O-3 Granularity: one encrypted cookie per purpose, even when a host ends up with many cookies. Do
  not group purposes into one cookie to save space. The inventory still reports the count and size
  per host so that a real browser limit is found before release, not after.
- O-3a New flow means a new cookie: starting a new flow of a purpose deletes that purpose's cookie
  and sets a new one. A cookie is never updated in place to represent a different flow.
- O-3b Flow identifier: every purpose cookie carries the identifier of the flow it belongs to (a
  random, single-use flow ID that also exists on the server-side record). Each request compares the
  cookie's flow ID, the page's binding and the server record; any mismatch is the restart guidance.
- O-3c Race between tabs: when two tabs run the same purpose concurrently, the server, not the
  cookie, decides. The first flow to reach its checkpoint (the first server-side commit that moves
  the flow past its entry phase) wins, under a lock on the server-side record that serializes the
  two. The other flow is refused with the restart guidance and changes nothing. This refines D-6:
  "newer wins" applies to starting a flow; once both have started, "first to the checkpoint wins".
- O-4 `secret_key_base` rotation: no rotation support for flow cookies. Rotation invalidates them
  and in-flight flows restart.

## Work order

1. Inventory (no behavior change): for every key, its writer, readers, flow, host, server-side
   record, current lifetime, intended lifetime, failure behavior and target purpose cookie. Record
   it in `specs/browser-flow-state-cookies/inventory.md`, including the cookie count and size per
   host (O-3).
2. Purpose owners and tests first: write the request tests for AC-1 to AC-8 against the current code
   and confirm the incident tests fail.
3. Migrate flow by flow (sign-in, sign-up, social, OIDC, contact registration, step-up, others),
   each with its tests green, then remove the session keys.
4. Add the static guard (D-10) and update the owning docs and ADRs.

## Acceptance

- AC-1 Incident: after a completed sign-in in one browser, a new sign-in started from Base reaches
  the method selection page; no 409.
- AC-2 Abandoned flow: a sign-in or sign-up abandoned at any step does not block a new one started
  from Base, for APP and ORG.
- AC-3 Two tabs: starting the same flow in a second tab makes the first tab's next request show the
  restart guidance; the second tab completes normally.
- AC-4 Expiry: a purpose cookie presented after its embedded expiry is ignored by the server even
  when the browser sends it (test by replaying the old cookie value).
- AC-5 Integrity: a value copied under another purpose's name, altered, or encrypted with another
  key is ignored and leads to restart guidance; no 500.
- AC-6 Isolation: cookies are host-only with the `__Host-` prefix; no flow cookie is readable or
  writable by another surface host.
- AC-7 Sign-out removes every flow cookie on that host.
- AC-8 Google and Apple social sign-in complete repeatedly in one browser without deleting cookies,
  including after an abandoned social attempt (the earlier intermittent `csrf_detected`).
- AC-9 The Rails session contains only the CSRF token, the OmniAuth `state` and
  `inertia_clear_history`; the static guard enforces it.
- AC-11 Race: two tabs submit the same purpose's step concurrently (independent connections);
  exactly one reaches the checkpoint and proceeds, the other gets the restart guidance, and the
  server record shows one winning flow.
- AC-12 New flow: starting a new flow of a purpose replaces the cookie (old flow ID no longer
  accepted), even when the old flow was mid-step.
- AC-10 No cookie value contains an OTP, token, secret or contact value; logs contain reason codes
  only.
