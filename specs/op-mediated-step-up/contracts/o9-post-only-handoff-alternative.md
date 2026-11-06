# O-9 same-origin browser handoff: working analysis

Status: alternative for review; not an accepted change and not implemented. Revision 13 requires the
admission credential to reach Auth in a POST body, an Auth-bound browser ceremony and a Base
confirmation. The repository authentication-boundary rule requires Rails CSRF and same-origin checks
on unsafe browser requests and forbids overriding or skipping those checks. A browser POST initiated
by a Base document has Base's Origin. With `forgery_protection_origin_check` enabled, fetching an
Auth CSRF token with CORS does not make that Base-origin POST a valid Auth-origin POST. An
Origin-only exception is not compatible with the repository rules.

## Candidate server-to-server delivery

1. Base authenticates and authorizes its RP browser request as specified by O-9. Base's server sends
   the admission credential to a realm-matched Auth backend in an authenticated server-to-server
   POST body. The request is confidential, no-store, fixed-host, client-authenticated and scoped to
   this admission. Auth verifies the secret and stores only the state needed to associate a new
   random short-lived lookup handle with it. An ambiguous response fails closed; no automatic issue
   or attach retry.
2. The Base browser navigates to Auth with only that handle as a locator, never the admission
   secret, access token, browser nonce or provider state. The handle is a **bearer capability to
   attempt attachment**, although it is not authority to redeem or start a ceremony. It must be
   random, short-lived, single-use, purpose/realm bound and filtered from logs, traces, Referer and
   redirect Location. Treat URLs containing it as sensitive, including browser history, access logs,
   exceptions and external infrastructure. A server-side opaque POST relay or another no-URL
   transport would be preferable if it can preserve same-origin CSRF; none has been verified here.
3. Auth GET renders a representation only, using a host-only Rails session and an Auth-origin Rails
   CSRF token. It creates no attachment, Auth ceremony session, proof, grant or other persistent
   state. An Auth-origin POST consumes the handle atomically and attaches a fresh, independent Auth
   ceremony session. Rotation must not replace, authenticate or log out an unrelated Auth sign-in
   session. The Attach result establishes the Auth host-only O-9 cookie and a non-secret Base
   confirmation locator.
4. Auth sends the browser to the Base confirmation representation. Base confirms only on a
   Rails-CSRF-protected same-origin POST, after checking the authenticated RP session, its exact
   reference, its original browser nonce and the Auth-browser binding described below. Visa
   authenticates the Base server and rechecks OP grant/event and the attached admission under lock.
   Auth later redeems only from its matching host-only O-9 cookie in an Auth-origin CSRF-protected
   POST.

This candidate interprets the handle as a separate, non-authorizing presentation locator after the
admission secret has been delivered by backchannel POST. It is **not established** that a handle in
a GET URL is allowed by revision 13's prohibition on admission delivery in GET URLs. A decision on
that interpretation is required before implementation. The handle is still sensitive because it can
consume the attach opportunity.

## Browser-binding threat and necessary additional proof

Base nonce plus an attached Auth session alone does **not** prove that they belong to the same
browser. An attacker who steals the locator can attach using the attacker's Auth session, send the
resulting confirmation locator to the original Base browser, and wait for that browser to perform
Base confirmation. The attacker then has the Auth session needed to redeem. This is a cross-browser
session substitution even though the originating Base browser did confirm. The current O-9
implementation must not enable the browser flow on that basis alone.

A possible additional binding is an Auth-generated, one-use browser-confirmation proof created as
part of the state-changing attach POST and bound to its O-9 Auth session, admission, Base origin and
confirmation locator. The Base confirmation page retrieves the **already created** proof from Auth
using a credentialed CORS GET restricted to the exact configured Base origin; the Auth endpoint
checks the current host-only O-9 cookie and exact attached session before disclosing it. GET merely
reads an existing proof; it must not mint or persist one. The Base page then sends that proof only
in its own same-origin Rails-CSRF-protected confirmation POST. Visa verifies and consumes the proof
atomically with confirmation. The Base server must never adopt a proof from an incoming URL or
unprotected cross-origin POST. An attacker who attached on another browser cannot obtain the proof
through the victim's Auth cookie, and a third-party page cannot submit the attacker's proof as the
victim's Base confirmation without a Base CSRF token.

This remains a proposal, not established security. The exact storage and transport of the proof, how
Auth exposes a previously created proof without permitting unintended replay, OP verification, CORS
preflight/headers, `Vary: Origin`, frame policy, Fetch Metadata, cookie SameSite behavior, and
failure recovery require concrete implementation and tests. No Auth GET may create or refresh the
proof. Only exact HTTPS Base origins for the current realm are accepted; deny `Origin: null`,
missing and mismatched origins. Responses must be no-store/no-referrer and never readable by another
realm or an arbitrary origin. Test both current topologies: Base and Auth may be same-site but
cross-origin; cross-site cookie blocking must fail closed without falling back to a shared-domain
cookie. Do not expose admission secrets, Auth cookies, tokens or proof material in any URL or log.

## Denial, replay and recovery

A stolen handle can be redeemed for attachment by the wrong browser before the owner; this is a
denial of that attempt, not permission to start a provider redirect or passkey flow. Attachment and
the browser proof are fixed to the first Auth session, and neither a second attach nor a new browser
silently replaces it. The legitimate user may explicitly restart at Base after current RP
authentication and current step-up evidence are rechecked. Locking and unique constraints must make
two simultaneous attach attempts yield exactly one winner. Expired handles and ambiguous backend
outcomes fail closed; a timeout must not be retried as a fresh authorization.

Test a stolen handle in a second browser before and after attachment, and the stronger attack in
which that browser sends its confirmation locator to the original Base browser. Also test stolen
proof copied into a URL or cross-origin form, missing/wrong Auth cookie, changed Base nonce or RP
session, cross-realm/client/provider substitution, CORS origin variants, browser cookie
restrictions, CSRF and Fetch Metadata, replay, concurrent attach/confirmation/redemption, expiry,
lost responses, and secret-free logs. The only success case requires both origin browser bindings
and the current OP event; no intermediate handle or proof is independently an authorization to
perform the important operation.
