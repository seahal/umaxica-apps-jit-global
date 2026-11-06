# Let Browser DBSC Registration Reach the Visa Endpoint

Status: backlog. The owner decided on 2026-11-02 to defer this because the change is too broad for
the current cycle. Nothing below is started.

## Problem

After sign-in, Visa advertises DBSC with `Secure-Session-Registration`. The browser then sends
`POST /edge/v0/token/dbsc` itself, without a CSRF token.
`Visa::App::Edge::V0::Token::DbscController` inherits
`Base::App::AuthorityController#require_authenticity_token_for_unsafe_request!`, which requires a
session-bound token on every unsafe request, so the registration always answers 422. The development
log shows:

```
Processing by Visa::App::Edge::V0::Token::DbscController#create
{"event":"security.csrf.request_blocked", ... "sec_fetch_site":"same-origin"}
Completed 422 Unprocessable Content
```

DBSC on Visa therefore never binds a session in a real browser. Sign-in still completes.

## Why Tests Did Not Catch It

`config/environments/test.rb` enables forgery protection only for browser E2E runs, so Minitest
posts to the endpoint without the token check.

Auth had the same check, but Auth never advertised DBSC, so no browser registration reached it.

## Proposed Change

- For the DBSC `create` action on Visa APP and ORG only, skip the session-token requirement while
  keeping Rails' Origin and Fetch Metadata check (`same-origin`). This is narrower than
  `skip_forgery_protection`.
- Rationale: `DbscRegistrationService` already requires a proof signed by the device key, bound to
  the challenge the server stored on the session record, with this endpoint as audience. A
  cross-site forged POST cannot produce it.
- Register the exception in `test/unit/security/skip_forgery_protection_usage_test.rb` or the
  equivalent invariant, with that reason.
- Add tests that run with forgery protection enabled: a same-origin registration without a token
  succeeds, and a cross-site one is refused.

## Decide Before Starting

- Whether the same-origin header check alone is acceptable for this endpoint (security review).
- Whether the bound-cookie refresh path (`Sec-Session-Id` present) needs the same treatment.
- Whether ORG Visa advertises DBSC too; confirm against the code before changing it.

## Owner hands-on evaluation (2026-11-04)

The owner will judge the DBSC behavior by hand on a Windows virtual machine running on Proxmox VE
before any change is decided here. Results belong in an `evidence/` record (browser and version,
whether the VM exposes a TPM to the guest, the observed registration and refresh requests and their
statuses). The step-up contract's DBSC requirement (AC-22: the binding survives the next
device-session refresh after step-up) can be observed in the same session.

## Owner hands-on result (2026-11-05, Windows VM on Proxmox VE)

Environment: Windows guest with a TPM available to the guest (owner-confirmed), Chrome. Three APP
email sign-ins (one with an intentional OTP resend) completed normally.

Observed in `log/development.log`: on each sign-in, Visa's `POST /oauth/authorize` response logged
`dbsc.registration.advertised` (from `AuthenticationBase#apply_committed_login!`), and the browser
then sent `POST /edge/v0/token/dbsc` by itself (`sec_fetch_site: same-origin`). Every one returned
**422** with `security.csrf.request_blocked`. The browser side therefore works; the server refuses
registration as described above, so no session was bound. Sign-in itself succeeded without DBSC.

Limits: the log does not identify the client machine; attribution to the Windows guest is by time.
Server-side registration, binding and refresh have never run, so they remain unverified. The
DevTools Network panel did not clearly show the browser-initiated registration request.

## Add DBSC to the RP local sessions (owner request 2026-11-05)

Only Visa (OP) advertises DBSC today (`AuthenticationBase#issue_dbsc_registration_header_for`, at
committed login and at each refresh, for `BROWSER_WEB` token kinds). The Base RP local sessions (APP
and ORG, `www` access and refresh cookies, step-up revision 13 O-12) have no DBSC advertisement or
endpoint. The DPoP binding of the RP's OP grant uses a key held by the Base server; it protects
Base-to-OP calls, not the browser-to-Base cookies. A stolen Base cookie is usable without the OP.
DBSC binding is per host, so Visa's binding does not protect Base. No ADR decides DBSC for RP
sessions (`adr/device-session-dbsc-device-id-boundary.md` covers the OP device session only).

Decide before starting:

- Bind each RP's cookies per RP, with the binding state stored in that RP cell's database.
- Behavior when registration or refresh fails: block sign-in or continue without DBSC, and how this
  is observable.
- The same CSRF question as above for the RP registration endpoint.
- Record the decision in an ADR; keep it separate from the step-up work.

## Owner direction (2026-11-05)

1. The CSRF exception for the DBSC registration endpoint needs documented grounds before it is made.
   Verify them first, against the DBSC specification and Chrome's actual request (under
   `generic/source-policy.mdc`), and record the result in an ADR. Points to establish:
   - what the browser sends (method, headers, body, Origin and Fetch Metadata, which cookies);
   - that the server challenge reaches only the victim's browser in a response header, so a
     cross-site page cannot read it and cannot produce a proof bound to it;
   - that a cross-site forged registration cannot attach an attacker key to the victim's session
     (cookie SameSite behavior for the `__Host-` cookies, challenge single use and expiry, audience
     check);
   - the refresh path (`Sec-Session-Id` present) under the same analysis.
2. For OP and RP: wherever a refresh token is used and the session is DBSC-bound, always verify the
   DBSC proof and refuse (and revoke) on failure. A session, once bound, must never fall back to
   unbound refresh; "DBSC available" is decided by the session's recorded binding, not by what the
   request claims. Unbound sessions (browsers without DBSC) stay on the existing weaker path and
   must be visible as such.

## Endpoint path (owner decision 2026-11-05)

Use `/dbsc/session` for DBSC registration and refresh on the Visa APP and ORG hosts, replacing
`/edge/v0/token/dbsc`, and the same path when RP sessions get DBSC. Reason: it is a browser protocol
endpoint like `/oauth/token`, which `adr/api-route-vocabulary-consolidation.md` keeps out of a
blanket `/api/v0` move; no de facto standard path exists (Chrome's documentation uses
`/StartSession` and `/RefreshEndpoint` only as examples; the specification text was not read). The
final route form follows `adr/rails-routing-resourceful-policy.md`.

Changing it later is free only while no session is bound: a bound browser keeps the `refresh_url` it
received at registration, so a later rename must keep the old route serving refresh until those
sessions end. Rename together with the CSRF fix, before any registration succeeds.

## Scope (owner, 2026-11-05)

APP and ORG are fixed together in one change: the CSRF grounds and handling, the path rename, the
refresh-time enforcement, and later the RP sessions. ORG Visa has its own
`Visa::Org::Edge::V0::Token::DbscController`, and
`AuthenticationBase#dbsc_registration_eligible_kind?` covers `OperatorTokenKind::BROWSER_WEB`, so
ORG is expected to advertise DBSC the same way (source reading; ORG was not exercised in a browser).
