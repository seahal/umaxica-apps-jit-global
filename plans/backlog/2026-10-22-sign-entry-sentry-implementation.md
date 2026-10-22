# Sign Entry Sentry: Proposals and Implementation Plan

Recorded 2026-10-22. **Plan; not started.** The Owner-approved decisions are those in
[adr/sign-entry-sentry.md](../../adr/sign-entry-sentry.md), which on 2026-10-22 accepted P1–P4 and
P7 as proposed, refused draining for callbacks (P4.5), rejected the OP pre-check alternative of P6,
and replaced the staged transition below with a one-change replacement (ADR items 17–23). Where this
plan and the ADR differ, the ADR wins. P8, P9 and the user-facing details remain proposals. Facts and the adversarial review are in
[the investigation](../../research/2026-10-22-sign-entry-sentry-investigation.md). No application
code, route, flag, migration or test has been changed for Sentry.

## Proposals for the open decisions

Each proposal names a recommendation and the alternative it was weighed against.

- **P1. Where the Sentry GET lives — decided by the Owner on 2026-10-22** (ADR item 9): on the
  Auth host of each surface, `GET /sign/in/sentry` → `/sign/in` and `GET /sign/up/sentry` →
  `/sign/up`. Remaining proposal for the details: Base's `start_authorization_ceremony!` and Switch
  redirect to `/sign/in/sentry?entry_ref=…` (or `/sign/up/sentry` for `prompt=create` and a Switch
  to Sign Up) instead of the entry page; the Sentry answers `ALLOWED` with a 303 that passes only
  `entry_ref` explicitly (`ri` and `lx` come from `PreferenceGlobal#default_url_options`, `pt` from
  `signed_pt_param`, per the ADR), and `BLOCKED` with 503, `Cache-Control: no-store`,
  `Referrer-Policy: no-referrer` and `Retry-After`. The local registration link on the Sign In page
  points to `/sign/up/sentry` only if it survives (see P1a). The Base-hosted alternative was not
  chosen.
- **P2. Routes and classes.** Proposal, following the existing resourceful style in
  `config/routes/auth.rb`: `namespace :in { resource :sentry, only: :show }` and the same under
  `namespace :up`, giving `/sign/in/sentry`, `/sign/up/sentry` and helpers such as
  `auth_app_sign_in_sentry_path`. Controllers:
  `Auth::{App,Com,Org}::Sign::In::SentriesController` and
  `Auth::{App,Com,Org}::Sign::Up::SentriesController`, each inheriting its surface's
  `ApplicationController` and declaring its surface and flow as constants, as
  `SignUpSuspensionGuard` callers declare `sign_up_surface`. No constant may be named `Sentry`
  (shadowing `::Sentry`).
- **P3. Decision object placement.** Proposal: `app/resolvers/sign_entry_sentry_resolver.rb`
  (`SignEntrySentryResolver`) derives the state from Flipper and returns
  `app/values/sign_entry_sentry_state_value.rb` (`ALLOWED` or `BLOCKED`, plus surface and flow). The
  resolver holds the explicit six-entry table keyed by `(surface, flow)` and raises `ArgumentError`
  for any other pair. It rescues only the flag-store error class (as `FqdnAvailabilityGate` does)
  and returns `BLOCKED`. Alternative: `SignEntrySentryPolicy` in `app/policies`, which would sit
  among ActionPolicy classes without being one. The Owner's name `SignEntrySentry` stays the
  concept name in prose.
- **P4. Enforcement points.** Proposal (one shared, non-raising check through the resolver):
  1. Auth Sentry GET (entry, user-facing 503).
  2. Auth Admission redemption (`AuthCeremonyAdmission#create` and `ceremony_bindings`) for the
     `sign_in`, `sign_up` and `authentication` purposes only; `TICKET_CEREMONY_PURPOSES` are
     excluded explicitly. `authentication` is checked against `sign_in_available_*`.
  3. Auth entry `show` for an already admitted ceremony (closes the direct GET without the hop).
  4. Every Sign In and Sign Up evidence or registration POST, including Email OTP, Passkey options
     and verification, Secret, challenge, `sign/up/check/**`, `sign/up/guard/**`, social start,
     ORG Entra session start and invitations. Implemented as one concern per flow that only calls
     the resolver, not by extending `SignUpSuspensionGuard` or `AuthCeremonyAdmission`.
  5. Provider callbacks: the Sign Up flag before `handle_pending_social_sign_up_intent` and the
     social sign-up branch; the Sign In flag before recording login evidence. Whether a callback
     drains like the provider switch is decision D-CB below.
  6. Base root-login commit: a check in `AuthenticationBase#log_in` for `establishment: :root_login`
     only, evaluated before the session commit and returning a refusal status (never success,
     never a raise inside a caller's transaction). `:rp_session`, Refresh, Sign Out and Step-Up
     are untouched. This is the backstop that also covers resume, session limit and selector.
- **P5. Sign Up → Sign In First handoff.** Proposal: do not check inside `with_cycle_lock`. The
  registration completes; the Base commit (P4.6) refuses the session when Sign In is blocked; the
  person sees a "sign in unavailable" result and the Identity stays.
- **P6. OIDC-initiated block.** Proposal: when the Auth Sentry blocks an OIDC-bound ceremony, it
  answers 503 and leaves the OIDC transaction to expire. Alternative for decision: Base checks
  `sign_in_available_*` before issuing the Admission and returns `temporarily_unavailable` to the
  registered `redirect_uri` with `state`.
- **P7. ORG.** Proposal for decision: ORG Emergency Access is exempt from `sign_in_available_org`
  (break-glass), with its own switch if one is ever needed; `sign_up_available_org` gates invitation
  acceptance (`sign/up/invitations`) and the recruit page.
- **P8. Observability.** Proposal: one structured log event per refusal (`sign_entry_sentry.blocked`
  with surface, flow and enforcement point only; never `entry_ref`, `pt`, cookies or identifiers),
  following `adr/application-logging-boundary.md`. No audit record, because no person or account
  state changes.
- **P1a. Redirect sites that change target (code, not state machines).** Base ceremony start:
  `Base::{App,Com,Org}::Oauth::AuthorizationsController#start_authorization_ceremony!` (3). Base
  Switch: `authorization_switch_url` in `Base::{App,Com}::Oauth::AuthorizationsController` (2; ORG
  raises). These five move with the OP if the planned OP host separation and Switch relocation
  land first; Sentry changes the target of the five wherever they live. The Auth local links
  (`registration_link` in `Auth::{App,Com,Org}::Sign::InsController`, the Sign In footer link in
  `Auth::Com::Sign::UpsController`) become sites only if a sign-up page can still be entered from a
  sign-in admission; under an explicit effective-intent rule they cannot. Not changed: the return from Base
  binding confirmation (`BaseCeremonyBindingConfirmation#auth_binding_entry_url`), which continues
  a ceremony that already passed the Sentry and is covered by the redemption check (P4.2); and
  `AuthCeremonyAdmission#auth_ceremony_clean_url`, the post-redemption redirect.
- **P9. Lifecycle diagrams.** Sentry state is not persisted and is not a flow lifecycle state, so no
  new axis is added to `docs/mermaid/idp-state-machine-transition-inventory.md`. The Sentry GET
  forwards `entry_ref` without touching the binding, so the `issued → attached → confirmed →
  redeemed` transitions in `idp-*-auth-admission-binding.mmd` are unchanged; a refusal leaves the
  binding in its current state until expiry, which those diagrams already show as `retired`. If an in-flight
  refusal is later recorded on a flow, that becomes a new decision with a diagram update.

## Decisions the Owner needs to make

- Decided (ADR items 9, 17–23): host, paths and parameter forwarding; names and 303; enforcement
  set; callbacks refused; ORG Emergency outside and invitations gated; one-change transition; no OP
  pre-check; refusal classes and the accepted preload 500.
- D-UX (open): response bodies, i18n keys, `Retry-After` value.
- D-OBS (open): P8 logging and whether any audit or telemetry record is kept.

## Transition from `sign_up_suspended_*`

Current readers: `SignUpSuspension` (`app/services/sign_up_suspension.rb`),
`SignUpSuspensionGuard` and its eight call sites (see the investigation, section 1.1),
`test/integration/sign_up_suspension_test.rb`, `test/services/sign_up_suspension_test.rb`, the
registry invariant test, and the `errors.messages.sign_up_suspended` locale key.

**Superseded by ADR item 21 (one-change replacement; never deployed).** The staged order below is
kept as the rejected alternative. The accepted order is: register the six rows and write them `true`
in every environment, record `feature_flags:status` in `evidence/`, then one change that adds the
Sentry, moves every current guard site to the resolver and removes `SignUpSuspension`,
`SignUpSuspensionGuard`, the old registry rows and their tests.

Rejected staged order:

1. **Register.** Add the six availability rows to `FeatureFlags::REGISTRY` with no reader. Deploy.
   Run `feature_flags:register`; the six appear disabled and have no effect yet.
2. **Write and verify.** In every environment, set the six flags to `true`, except that
   `sign_up_available_<surface>` is set to `false` where `sign_up_suspended_<surface>` is currently
   on. Record `feature_flags:status` output in `evidence/`. This is the gate for step 3.
3. **Read both (bounded transition).** Deploy Sentry. While both exist, Sign Up is allowed only when
   `sign_up_available_* == true` **and** `sign_up_suspended_* != true` (the stricter of the two). An
   unexpected state can only close registration, never open it. Exit condition: step 4.
4. **Retire.** After a stated observation period with no use of `sign_up_suspended_*`, remove
   `SignUpSuspension`, the old rows and their tests in one change, per
   `generic/no-compatibility-layer.mdc`. Leave the Flipper records in place until an operator
   removes them; the registry no longer reads them.

Rollback:

- Before step 4, rolling the code back restores the old reader; the new flags are inert.
- If Sign In stops unexpectedly after step 3, enable the affected flag in the Flipper UI on its
  Basic-auth host (it does not depend on ORG Sign In), or with a bounded one-off console call.
  Proposal: add a rake task `feature_flags:enable[name]` restricted to `:availability` flags so the
  recovery is a reviewed command, not a console session.
- A flag-store outage cannot be fixed by flag writes; it closes Sentry (and, with preload, likely
  every request). Recovery is restoring `primary`.

## Implementation sequence (after the decisions)

1. Resolver and value (P3), registry rows (step 1).
2. Base root-login backstop (P4.6), because it covers every path at once.
3. Auth Admission redemption and admitted-entry checks (P4.2, P4.3).
4. Sentry controllers and routes (P1, P2); point Base redirects and the local links at them.
5. Sign In continuation POSTs; Sign Up continuation POSTs; provider callbacks (P4.4, P4.5).
6. ORG Entra, Emergency (per D-ORG) and invitations.
7. Transition step 3; later step 4.
8. Current documentation: `docs/security/sign-in-sequence.md`, `docs/security/sign-up-sequence.md`,
   `docs/security/authentication-capacity-admission.md` (control table), `docs/security/idp-flow-lifecycle.md`
   (availability row), and `docs/checklists/authentication.md`.

Likely files touched: `app/values/feature_flags.rb`, new resolver/value/concern/controller files,
`config/routes/auth.rb`, `app/controllers/concerns/auth_ceremony_admission.rb` (one call, no
merge), `app/controllers/concerns/authentication_base.rb` (`log_in`), the three Base
`oauth/authorizations_controller.rb` redirect targets, the Auth Sign In and Sign Up continuation
controllers, `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb`, ORG social and
Emergency controllers, `lib/tasks/feature_flags.rake`, locale bundles, and their tests.

## TDD plan (Red → Green → Refactor)

Unit (resolver, public method only):

- Each of the six pairs × `true` / `false` / unwritten → `ALLOWED` / `BLOCKED` / `BLOCKED`.
- Flag-store error → `BLOCKED`; an unrelated `StandardError` is not swallowed.
- Unknown surface or flow → `ArgumentError`; a surface string from the request is never accepted.
- APP Sign In blocked leaves COM and ORG Sign In and APP Sign Up unchanged (surface and flow
  separation, one representative per partition).

Integration (public HTTP boundary):

- Sentry GET `ALLOWED` → 303 to the fixed entry path with the forwarded reference; the entry page
  then renders through the existing Admission (Sentry GET → redirect → existing GET).
- Sentry GET `BLOCKED` → 503, `no-store`, no `Location`, no flow or ceremony row created.
- Direct `GET /sign/in` with an admitted ceremony, `POST /sign/in`, `POST /ceremony_bindings`,
  and one representative continuation POST per method (Email OTP, Passkey verification, Secret,
  APP social start, ORG Entra start) are refused while blocked.
- Social "login" callback for an unknown identity creates no `ClientSignUpFlow` while Sign Up is
  blocked; the existing-identity login follows D-CB.
- Base root-login commit refused while Sign In is blocked: no token row, no cookie, no login audit;
  the flow is not `HALTED`.
- Sign Up completes while Sign In is blocked: the Identity persists, no session, and Sign In First
  tests stay green.
- Flag switched between two requests of one flow: the second request observes the new state
  (in-flight switching), with no claim about the same request.
- Not affected while blocked: an authenticated page, Refresh, Sign Out, Step-Up ticket ceremony,
  `prompt=none` (`login_required` or code), and SSO code issuance.
- No loop: the Sentry response never redirects to itself or to Base, and `BLOCKED` is terminal.
- Transition step 3: each combination of old and new Sign Up flag yields the stricter result.

Keep `test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb`,
`test/controllers/concerns/auth/login_cooldown_surfaces_test.rb` and
`test/integration/root_login_establishment_flow_test.rb` green. Do not enumerate every route ×
flag combination; the resolver unit tests carry the state space and the integration tests carry one
representative per enforcement point. Flag setup and registration are environment construction and
are recorded in `evidence/`, not tested (`project/no-environment-tests.mdc`).

## Implementation blockers

- None of the design decisions blocks implementation any more; D-UX and D-OBS can be settled with
  the controllers.
- Enforcement must start only after the six flags are written `true` and recorded (ADR item 21).
- The OP redirect sites move if the planned OP host separation and Switch relocation land first;
  implement against whichever controllers own them at that time.
