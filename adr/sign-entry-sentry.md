# Sign Entry Sentry: Flipper-Controlled Admission of New Sign In and Sign Up

## Status

**Accepted (2026-10-22), Owner decisions only; not implemented.** This ADR records only what the
Owner decided: the original decisions (items 1–16), the Sentry GET placement and paths (item 9),
and, later on 2026-10-22, enforcement points, names, callbacks, ORG scope, the transition, the OIDC
behavior and refusal classes (items 17–23; item 16 is amended by item 21). What remains open is
listed under [Not decided](#not-decided). The implementation plan is
[the backlog plan](../plans/backlog/2026-10-22-sign-entry-sentry-implementation.md); its remaining
proposals are not accepted by this record. The investigation behind it is
[research/2026-10-22-sign-entry-sentry-investigation.md](../research/2026-10-22-sign-entry-sentry-investigation.md).

"Sentry" in this record names the authentication entry control. It is unrelated to the Sentry error
monitoring SDK (`sentry-ruby`, `sentry-rails`, `config/initializers/sentry.rb`), whose top-level
`::Sentry` constant this application already loads.

## Context

Operators can currently close new registration per surface through `sign_up_suspended_{app,com,org}`
(`:suspension` polarity, fail-open, `SignUpSuspension` and `SignUpSuspensionGuard`). There is no
equivalent switch for Sign In, and the Sign Up switch has the opposite polarity from the
`:availability` flags that gate authentication ceremonies (`social_ceremony_*`, FQDN availability).

## Decision

1. **Name.** The mechanism is called **Sentry**. Breaker, Circuit Breaker, Gate (as the mechanism
   name), Daemon and Interlock are not used. Existing names such as `FqdnAvailabilityGate` are not
   renamed by this decision. `SignEntrySentry` is the concept name; the Ruby names are fixed by
   item 18.
2. **Responsibility.** Sentry decides only whether a new Sign In or Sign Up may begin or continue on
   a surface. It is not authentication, authorization, session issuance, or proof that an Admission
   is valid. Passing Sentry grants nothing.
3. **Separation.** Sentry, Guardrail (whether this person may sign in), Checkpoint (which further
   requirements apply) and the future Waiting Room / capacity admission
   ([capacity boundary](../docs/security/authentication-capacity-admission.md)) remain separate
   responsibilities. Sentry is not merged into `AuthCeremonyAdmission`, `SignUpSuspensionGuard`,
   Guardrail or Checkpoint, and it is not a Waiting Room.
4. **States.** Sentry has exactly two states, `ALLOWED` and `BLOCKED`. `OPEN`, `CLOSED`,
   `HALF_OPEN`, automatic recovery, load prediction and queue order are not part of Sentry.
5. **Source of truth.** Flipper is the only source of the state. No per-user persistent Sentry state
   record is created. A transient value object that carries one evaluated decision is allowed.
6. **Flags.** Six flags, one per surface and flow, all with `:availability` polarity in
   `FeatureFlags::REGISTRY`:

   | Surface | Sign In                 | Sign Up                 |
   | ------- | ----------------------- | ----------------------- |
   | APP     | `sign_in_available_app` | `sign_up_available_app` |
   | COM     | `sign_in_available_com` | `sign_up_available_com` |
   | ORG     | `sign_in_available_org` | `sign_up_available_org` |

7. **Fail closed.** Only an explicit `true` yields `ALLOWED`. `false`, a feature that was never
   written, and a flag-store read failure all yield `BLOCKED`.
8. **Explicit registration of names.** The flag for a (surface, flow) pair comes from an explicit
   server-side table. It is never built from request parameters, the `Host` header or any other
   request input.
9. **Independent GET controller and redirect.** Sentry has its own GET controller for Sign In and
   for Sign Up. Normal browser navigation passes through it first. `ALLOWED` redirects to the
   existing GET page; `BLOCKED` answers HTTP 503 with `Cache-Control: no-store`. The Sentry GET does
   not authenticate, issue sessions or create flows.

   **Placement (Owner decision, 2026-10-22).** The Sentry GET lives on the Auth host of each
   surface (APP, COM, ORG), not on Base. The paths are `GET /sign/in/sentry` and
   `GET /sign/up/sentry`. On `ALLOWED`, `/sign/in/sentry` redirects to `/sign/in` and
   `/sign/up/sentry` redirects to `/sign/up` on the same Auth host. The redirect target is fixed by
   the server for each Sentry and is never taken from the request.

   Consequence, from the current code: Auth `/sign/in` and `/sign/up` refuse a request without a
   Base-issued `entry_ref` or an already admitted ceremony. Base's ceremony start and Switch
   redirects, and Auth's local link from Sign In to Sign Up, therefore target the Sentry paths, and
   the Sentry forwards the Admission reference unchanged without consuming or interpreting it.
   Redemption stays in `AuthCeremonyAdmission`.

   **Request context (Owner decision, 2026-10-22).** The Sentry adds no forwarding logic of its own
   for request context. `ri` and the overlay keys such as `lx` are carried by the existing
   `PreferenceGlobal#default_url_options`, which every Auth surface `ApplicationController`
   includes. `pt` is carried by the existing `AuthenticationRedirects#signed_pt_param`, which passes
   only a verified signed target. The Admission reference is the only parameter the Sentry passes
   explicitly.
10. **Existing boundaries stay intact.** Sentry is added without merging, short-circuiting or
    bypassing Sign In First, Base's Session/OIDC/Token authority, Auth's ceremony-only role, the
    APP/COM/ORG separation, the independent Sign In and Sign Up state machines, the Base → Auth
    Admission and its browser/transaction binding, Guardrail, Checkpoint, MFA, Session Limit, or the
    Sign In First handoff.
11. **The Sentry GET is not the enforcement boundary by itself.** A direct request to an existing
    page, POST, callback or resume must not get past a `BLOCKED` Sentry. The enforcement points are
    chosen per path after investigation; adding one identical callback to every controller is not
    required.
12. **Scope of blocking.** Sentry stops new authentication and registration. Ordinary use by signed
    in people, Refresh, Sign Out, Step-Up, and OIDC requests that complete without a new
    authentication are outside Sentry. `prompt=none` is never sent to an interactive Sentry page; it
    keeps its OIDC success or standard error contract.
13. **Sign In First is preserved.** A durable registration is never deleted, rolled back or
    anonymized because Sentry blocks the subsequent Sign In.
14. **In-flight flows.** A `BLOCKED` Sentry refuses new authentication operations and session
    finalization. It does not by itself move a flow to `HALTED` or delete personal data or a
    registered Identity; flow expiry and resumability follow the existing lifecycle contracts. This
    matches [the lifecycle vocabulary](idp-flow-lifecycle-vocabulary.md): availability is not a flow
    lifecycle state.
15. **No overclaiming.** Flipper changes and in-flight database transactions are not atomic. No
    document or test may claim that turning a flag off stops every session issuance in every process
    at that instant.
16. **Migration discipline.** The existing `sign_up_suspended_*` flags are not silently
    reinterpreted. Before Sentry is enforced, all six availability flags are written as `true` and
    verified in each environment. *(Amended by item 21: the old flags are removed in the same change
    that introduces Sentry.)*
17. **Enforcement points** (2026-10-22). Sentry is checked, through one resolver, at: (1) the OP's
    ceremony-start and Switch redirects, which select `/sign/in/sentry` or `/sign/up/sentry` from the
    server-side effective intent (Switch target, else `prompt=create` → Sign Up, else Sign In); (2)
    Auth Admission redemption (`POST /sign/in`, `POST /sign/up`, `POST /ceremony_bindings`) and the
    admitted-entry `show`; (3) every Sign In and Sign Up evidence-recording and registration POST;
    (4) provider callbacks (item 19); (5) the OP root-login commit, for
    `log_in(establishment: :root_login)` only, returning a refusal before the commit and never
    raising inside a caller's transaction. `:rp_session`, Refresh, Sign Out, SSO code issuance,
    `prompt=none` and the ticket ceremonies (Step-Up, reauthentication, credential registration and
    change, bootstrap) are not checked. Each point only calls the resolver; Sentry is not merged into
    `AuthCeremonyAdmission`, Guardrail or Checkpoint. The Sign Up → Sign In First handoff is not
    checked inside the sign-up cycle lock; point (5) refuses its session and the Identity stays.
18. **Names** (2026-10-22). `SignEntrySentryResolver` in `app/resolvers/` holds the explicit
    six-entry (surface, flow) table, reads through `FeatureFlags`, raises `ArgumentError` for any
    other pair, and returns `SignEntrySentryStateValue` in `app/values/`. Controllers
    `Auth::{App,Com,Org}::Sign::{In,Up}::SentriesController`; routes `resource :sentry, only: :show`
    under `namespace :in` and `:up`. `ALLOWED` answers 303. No constant is named `Sentry`.
19. **Provider callbacks** (2026-10-22). Google, Apple and Entra callbacks are refused under
    `BLOCKED`: no new evidence, registration or flow. Unlike the provider switches, there is no
    draining.
20. **ORG** (2026-10-22). Emergency Access is outside `sign_in_available_org` (break-glass).
    `sign_up_available_org` gates invitation acceptance and the ORG recruit page. This does not
    decide D11 or D12 of the Sign In First ADR.
21. **Transition** (2026-10-22). Because the system has never been deployed, `sign_up_suspended_*`,
    `SignUpSuspension` and `SignUpSuspensionGuard` are replaced in one change: the six flags are
    registered, written `true` in every environment and recorded in `evidence/` first; the same
    change removes the old switch and its tests and moves every guard site to the resolver. No
    period reads both. Rollback is a code rollback.
22. **No OP pre-check** (2026-10-22). A blocked OIDC-initiated attempt stops at the Auth Sentry 503.
    The OP does not answer `temporarily_unavailable`; the RP's pending state ends at its own bounds.
23. **Refusal classes** (2026-10-22). `BLOCKED` is retryable: it does not end the attempt, which
    still ends at its absolute deadline. A flag-store error is a dependency failure: no authority is
    issued and nothing is consumed needlessly. With Flipper `preload = true`, a store failure
    surfaces as a 500 from the Flipper middleware before Sentry runs; this is accepted (the request
    is refused either way) and is the one exception to item 9's 503.

## Not decided

These items are open. The backlog plan holds proposals; none is accepted here.

- The in-flight user experience, response bodies, `Retry-After`, logging event names and i18n keys.
- Whether a Sentry decision is recorded as an audit or telemetry event.

## Consequences

- An operator gains a Sign In switch per surface. Because the polarity is fail-closed, a missing or
  unwritten flag closes Sign In for that surface; the rollout must write the flags first.
- `sign_up_suspended_*` disappears in the change that introduces Sentry; no period reads both.
- A blocked OIDC-initiated attempt leaves the RP waiting until its own pending bounds expire.
- Sentry does not replace `FqdnAvailabilityGate`, which closes a whole host, or the per-provider
  `social_ceremony_*` switches.

## Related

- [Sign In First](sign-in-first-and-sign-up-handoff.md)
- [Base/Auth ceremony boundary](base-auth-ceremony-and-seven-rp-boundary.md)
- [Neutral entry](sign-neutral-entry-and-logout-target-authorization.md)
- [Root login establishment](root-login-establishment-boundary.md)
- [Sign Up Flow Admission binding](sign-up-flow-admission-binding-and-cardinality.md)
- [Authentication capacity admission](../docs/security/authentication-capacity-admission.md)
