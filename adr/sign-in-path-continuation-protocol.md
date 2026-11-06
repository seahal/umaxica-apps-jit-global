# Sign-in Path Continuation Protocol (Design D)

## Status

**Accepted (2026-10-23); amended for the Visa authorization result boundary on 2026-11-01.** Owner
decisions D-100, D-101, D-46, D-49, D-50, D-52 of the 2026-10 authentication cycle are implemented
by WU-12. The external Jump/Edge integration remains outside this repository.

## Context

Between the RP's sign-in start and the authentication page, and between authentication and the RP
callback, the browser crosses OP ↔ Auth relays (admission attach, Base/Visa confirmation,
redemption, result receipt). Today several of them are Continue pages that need a click, and some
are cross-origin POSTs that browsers send with `Origin: null` (observed 422s). The owner requires at
most three user steps, no relay page, no click and no JavaScript between them.

## Decision

1. **User actions are POSTs; system hops are GETs.** Every user decision (RP 続行, credential
   submission, Cancel, Switch) is a CSRF-protected POST. Every system hop after it is a `303` to a
   GET continuation endpoint, including the final OP result GET that creates the Root Session.
2. **The deviation from RFC 9110 §9.2.1 (safe methods) is accepted** under six conditions, all
   mandatory on every continuation endpoint:
   1. `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document` are required; HEAD is refused.
      `Sec-Fetch-Site` is not checked, because a Jump hop makes it `cross-site` for every request.
   2. The host-only cookie browser binding is verified before the one-time record is touched.
   3. Consumption is atomic (existing Valkey CAS, PostgreSQL row locks and state columns).
   4. A repeat from the same bound browser returns the same next redirect, decided from PostgreSQL
      state; anything else is refused without consuming. The repeat window is issuance + 10 s
      (D-101); redemption opens no new window. A consumed or expired next-hop reference is never
      re-minted. The final result GET is never repeated: a repeat after the Root Session exists is
      an error, and recovery is the RP 続行 through the SSO path.
   5. Responses carry `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
   6. The final URL is clean (no reference left in the address bar).
3. **Carried codes live 10 seconds** (the Admission acceptance code and the result code, counted
   from issuance) once the relays are automatic; until then the existing 60-second acceptance code
   stays.
4. **Outdated browsers** are refused by `allow_browser versions: :modern`; requests without the
   Fetch Metadata pair are refused by condition 1.
5. Cross-surface navigation keeps going through Jump (D-52).

This is a UMAXICA protocol that borrows named properties of RFC 6749, RFC 9126 and RFC 9700 (short
single-use codes bound to the client/browser); it is not a conformance claim to any of them.

## Consequences

- The 2026-09-21 rule "GET never consumes" and the 2026-09-20 rule "the result is POST-only" in
  [Base/Auth ceremony boundary](base-auth-ceremony-and-seven-rp-boundary.md) are amended for these
  continuation endpoints only. Every other GET still consumes nothing.
- `docs/checklists/authentication.md` AUTH-1/AUTH-2 and
  `.agents/harnesses/rules/generic/authentication-boundaries.mdc` name this exception.
- A stolen live admission reference can still be attached first by a thief (denial of the victim's
  attempt); it cannot be confirmed, redeemed or accepted by the thief (D-51, AUTH-19).

## Verification

Per continuation endpoint: Fetch Metadata required, HEAD refused, binding checked before
consumption, CAS, same-browser repeat at 9 s / 10 s / 11 s after issuance, `no-store` and
`no-referrer`, clean final URL, foreign browser refused without consuming.

## Amendment to the September boundary text (2026-10-24)

This decision amends the 2026-09-21 Base-to-Auth admission transport amendment and the 2026-09-20
OIDC result transport amendment in `adr/base-auth-ceremony-and-seven-rp-boundary.md`. Those records
remain historical descriptions of the original POST handoff. The current Rails path uses the Design
D GET continuation resources on the Visa and Auth hosts; a browser navigation is the system hop and
the continuation itself performs the transaction-bound atomic step. User actions remain
CSRF-protected POSTs.

`docs/checklists/authentication.md` AUTH-1 and AUTH-2 and
`.agents/harnesses/rules/generic/authentication-boundaries.mdc` are the normative short-form rules.
They must be read with this ADR: the six conditions above apply to every Sign-in path continuation,
while unrelated GET requests still do not consume or mutate authentication state.

## Visa authorization result amendment (2026-11-01)

This amendment supersedes the final-result-GET behavior in Decision 1 and condition 4 above for the
Visa APP/ORG OIDC result, cancellation, switch, and silent-SSO continuations. Their GET endpoints
validate the browser binding and transaction, read the relevant handoff, and render a purpose-bound,
short-lived same-origin POST form. They do not consume the result, finalize a Root Session, cancel
or switch a transaction, issue an authorization code, or write Preference state. The existing
`Visa::{App,Org}::Oauth::AuthorizationsController#create` POST is the commit boundary: it validates
the Rails CSRF token, Origin/Fetch Metadata, signed purpose and expiry, then revalidates the browser
binding and transaction before performing the requested result, cancellation, switch, or silent-SSO
operation. Successful sign-in applies Preference only after authentication finalization.

The earlier Design D rules remain in force for the explicitly state-consuming Auth admission and
handoff continuations. A Visa display GET is not one of those consumption boundaries. Retries after
the Visa POST continue to follow the transaction's existing idempotency and one-shot result rules.
The final URL remains clean, and the GET response remains non-cacheable and referrer-safe.
