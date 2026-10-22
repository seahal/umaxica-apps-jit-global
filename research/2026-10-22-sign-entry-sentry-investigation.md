# Sign Entry Sentry Investigation

Non-normative. Facts were read from the working tree at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`
on the `feature` branch, which had uncommitted changes in some of the files read (for example
`app/controllers/base/*/oauth/authorizations_controller.rb`,
`app/controllers/concerns/oidc_authorization_result_post.rb` and several Auth COM controllers).
Statements below describe that working tree. Nothing was executed except reading code; no test was
run. Revalidate before use.

Decision record: [adr/sign-entry-sentry.md](../adr/sign-entry-sentry.md). Proposals and the
implementation plan: [the backlog plan](../plans/backlog/2026-10-22-sign-entry-sentry-implementation.md).

## 1. Confirmed facts

### 1.1 Flags and their readers

- `FeatureFlags::REGISTRY` (`app/values/feature_flags.rb`) is the only reader of Flipper; the
  registry invariant test forbids direct `Flipper.enabled?` elsewhere. Polarities are `:suspension`
  (unset = normal operation) and `:availability` (unset = closed).
- `sign_up_suspended_{app,com,org}` are `:suspension`. Reader: `SignUpSuspension.suspended?`, used
  only by `SignUpSuspensionGuard#reject_suspended_sign_up!`, which skips logged-in requests and
  renders the surface's sign-up page with 503.
- `reject_suspended_sign_up!` is installed on: `Auth::{App,Com,Org}::Sign::UpsController`,
  `Auth::{App,Com}::Sign::Up::{Emails,Telephones}Controller`,
  `Auth::Org::Sign::Up::InvitationsController`, and the APP social start when
  `social_auth_entry == "sign_up"` (`AppSocialCeremonyEntry#prepare_surface_ceremony_state!`).
- It is **not** installed on the `sign/up/check/**` and `sign/up/guard/**` controllers (OTP,
  Passkey, Secret, birthdate, social confirmation) or on the OmniAuth callback.
- Flipper is configured with `memoize = true` and `preload = true`
  (`config/initializers/flipper.rb`). The Flipper engine (`flipper` 1.4.2, `lib/flipper/engine.rb`)
  then inserts `Flipper::Middleware::Memoizer`, which calls `preload_all` at the start of every
  request and serves later reads in that request from memory.
- `FqdnAvailabilityGate` rescues `ActiveRecord::ActiveRecordError` around its own read and fails
  closed. With preload enabled, a flag-store failure is likely to raise earlier, inside the
  middleware, before any controller rescue runs (code reading only; not executed).
- The Flipper UI is mounted on its own host behind HTTP Basic authentication
  (`config/routes/flipper.rb`), independent of ORG Sign In. `feature_flags:register` creates missing
  features without enabling them; `feature_flags:status` prints state. There is no rake task that
  enables an availability flag in bulk (`social_ceremony:enable[...]` covers providers only).

### 1.2 Entry inventory

Auth (`config/routes/auth.rb`), per surface host:

| Surface | Sign In entry | Sign In continuations | Sign Up entry | Sign Up continuations |
| --- | --- | --- | --- | --- |
| APP | `GET/POST /sign/in` (`Sign::InsController`) | `sign/in/email` (new, create, edit, update, destroy), `sign/in/passkey` (new; `options`, `verification` POST), `sign/in/secret` (new, create), `sign/in/guard`, `sign/in/check`, `sign/in/challenge` (+ `totp`, `passkey`); social `google`/`apple` `session` POST; OmniAuth callbacks | `GET/POST /sign/up` (`Sign::UpsController`) | `sign/up/email`, `sign/up/telephone`, `sign/up/guard/{apple,google,email,telephone}`, `sign/up/check/**`; social `registration` POST |
| COM | `GET/POST /sign/in` | `sign/in/email`, `sign/in/passkey` (+ `options`, `verification`), `sign/in/guard`, `sign/in/check`, `sign/in/challenge` (+ `passkey`) | `GET/POST /sign/up` | `sign/up/email`, `sign/up/telephone`, `sign/up/guard/{email,telephone}`, `sign/up/check/**` |
| ORG | `GET/POST /sign/in` | `social/entra/session` (new, create), Entra callback and failure, `sign/in/passkey` (+ `options`, `verification`), `sign/in/emergency/passkey` (+ `options`, `verification`), `sign/in/guard`, `sign/in/check` | `GET/POST /sign/up` (recruit page only) | `sign/up/invitations` (new, create) |

All three surfaces also expose `sign/oidc/handoff`, `sign/handoff`, `sign/cancellation`,
`sign/switch` (APP, COM only), `sign/out`, and `POST /ceremony_bindings`.

Base (`config/routes/base.rb`), per surface host: neutral self-RP `GET/POST /sign`
(`OidcRpSignEntry`), `GET/POST /oauth/authorize`, `sign/completion`, `sign/in/limitation`,
`ceremony_bindings/:binding_ref/confirmation`, and on APP the social `authentication/continuation`
and `authentication/completion`.

### 1.3 Actual Base → Auth transition

1. An RP (or Base's own self-RP) serves `GET /sign` (display) and `POST /sign`, which creates the
   OIDC authorization request and 303-redirects to Base `/oauth/authorize`.
2. Base `GET /oauth/authorize`: with a sufficient Base session it issues a code (SSO); with
   `prompt=none` and no session it returns `login_required` to the RP; otherwise it renders
   `base/shared/authorization_ceremony_start`, whose POST (`ceremony_action=start`) calls
   `start_authorization_ceremony!`.
3. `start_authorization_ceremony!` creates the OIDC transaction and an Admission handoff
   (`OidcAuthorizationTransactionCoordinator.issue_with_handoff!`) and 303-redirects through Jump to
   Auth `/sign/up?entry_ref=…` when the intent is `sign_up`, otherwise to `/sign/in?entry_ref=…`.
4. The intent is `sign_up` only for `prompt=create` (APP, COM); `authentication` for every
   first-party browser RP; `sign_in` otherwise. ORG never yields `sign_up`. An `authentication`
   admission matches both Sign In and Sign Up (`auth_ceremony_intent_matches?`), so for first-party
   RPs **Base does not know whether the person will sign in or register**.
5. Auth `GET /sign/in?entry_ref=…` renders an auto-continuation page that POSTs the reference to
   `POST /ceremony_bindings` or `POST /sign/in`; the POST redeems it under the binding lock, rotates
   `__Host-auth_sid`, and 303-redirects to the clean `/sign/in` (or `/sign/up`).
6. Auth `GET /sign/in` or `/sign/up` without `entry_ref` renders only for an already admitted
   ceremony with a matching intent; a context-free request gets 400 (`render_invalid_admission_request!`).
7. From the Sign In page, a locally entered (not parent-bound) ceremony links to `/sign/up` with no
   `entry_ref`, reusing the admitted ceremony. A parent-bound page moves only through Switch, which
   goes back to Base and returns with a fresh `entry_ref`.
8. Auth records credential evidence only (`validate_login_establishment!` raises in Auth). Base
   commits the root login through `AuthenticationBase#log_in(establishment: :root_login)` from:
   `Base::{App,Com,Org}::Oauth::AuthorizationsController#login_for_oidc`,
   `LocalAuthenticationSessionCommitter`, `Base::App::Social::Authentication::CompletionsController`,
   `Base::App::Sign::In::LimitationsController`, `BaseSignInLimitations`, and
   `AuthenticationSequenceGate` (session-limit promotion, selector). `OidcCallback` uses
   `:rp_session`, which derives from an existing root login.
9. `BaseAuthAdmissionCoordinator.issue_local_entry!` has no production caller in this tree; only
   tests call it.

### 1.4 Sign Up → Sign In First handoff

`SignUpSequenceControllerSupport#finalize_sign_up_from_checkpoint!` runs `:finalize`, identity
graph provisioning, `:complete` and `handoff_to_sign_in_flow!` inside
`@sign_up_ticket.with_cycle_lock`. The handoff calls `establish_signed_in_session!`, which in Auth
records evidence and leaves session issuance to Base. Anything that raises inside that block
participates in the cycle lock's transaction.

### 1.5 Precedents

- `FlipperProviderAvailabilityAdapter#callback_decision` returns `:draining` for a provider
  callback when the provider switch is off, so a ceremony issued before the switch completes. This
  is the existing in-flight policy for provider switches.
- `docs/security/idp-flow-lifecycle.md` classifies `SignUpSuspension` as "surface availability, not
  lifecycle; a `start` precondition".

### 1.6 Edge repository

`seahal/umaxica-apps-edge` `main` at `185dd076404011ed391b2b550091be3fd7939ba0` (2026-09-10) was
read from a shallow clone. Its Core dispatch forwards only `/sign/out`, `/sign/out/complete`,
`/oidc/`, `/api/v0/`, `/web/v0/` and `/edge/v0/` to Rails and has no Auth or Base FQDN worker. Edge
therefore does not route Sign In or Sign Up entries; Sentry is a Rails concern. This `main` may lag
other branches; no other branch was present in the clone.

## 2. Conflicts with existing contracts and the Owner's diagram

- **C1. Auth entry pages cannot be opened without an Admission.** The Owner's diagram has
  `GET /sign/in/sentry` redirect to `GET /sign/in`. In the current code a plain `GET /sign/in` is
  400 unless the browser carries `entry_ref` or an admitted ceremony. A Sentry GET placed in front
  of `/sign/in` must forward the opaque `entry_ref` unchanged, or Base must check Sentry before
  issuing the Admission. Either changes Base's redirect target, which
  [the neutral entry ADR](../adr/sign-neutral-entry-and-logout-target-authorization.md) and the
  Base/Auth ADR govern.
- **C2. `authentication` intent.** For first-party RPs the Admission does not say Sign In or Sign
  Up. A Base-side check can apply only the Sign In flag; the Sign Up flag must be enforced in Auth
  (and at the Sign Up continuations) regardless of where the Sentry GET lives.
- **C3. Placement rule.** `SignEntrySentry` has no allowed suffix under
  `project/value-object-boundaries.mdc`.
- **C4. Namespace hazard.** The `sentry-ruby` gem defines `::Sentry`. A constant named exactly
  `Sentry` inside an application namespace would shadow it for code in that namespace.
  `SignEntrySentry` and `SentriesController` do not shadow it.
- **C5. ORG "no public Sign Up".** The ORG routes comment says Org has no public Sign Up, yet
  `Auth::Org::Sign::UpsController` and the invitation acceptance exist and are gated by
  `sign_up_suspended_org`. ADR Sign In First keeps D11 (ORG registration guidance) and D12 (ORG
  invitation admission) unresolved, so the meaning of `sign_up_available_org` depends on them.

## 3. Bypass inventory against Sentry (current code)

Paths that reach new authentication or registration work without passing an entry GET:

- **Social "login" creates a registration.** An APP Google or Apple ceremony started from the Sign
  In page has intent `login`; when the callback finds neither a user nor an identity it calls
  `handle_pending_social_sign_up_intent` and creates a `ClientSignUpFlow` in
  `SOCIAL_CALLBACK_PENDING`. No sign-up suspension check runs on that path today, so
  `sign_up_suspended_app` does not stop this registration route. A Sign Up Sentry must cover it.
- **Sign Up continuations without the guard.** `sign/up/check/**` and `sign/up/guard/**` (OTP
  create/update, Passkey, Secret, birthdate, provider confirmation) and the finalize handoff carry
  no suspension check; only the entry and the `email`/`telephone` `new`/`create` are gated.
- **Sign In continuations.** Email OTP, Passkey options/verification, Secret, challenge, ORG Entra
  session and callback, ORG Emergency Passkey, and Base root-login commits have no availability
  check of any kind.
- **Admission POSTs.** `POST /sign/in`, `POST /sign/up` and `POST /ceremony_bindings` redeem
  Admissions without passing any entry GET.
- **Resume and session limit.** `sign/in/limitation` (Base) and the selector and session-limit
  promotion paths commit root logins from a previously recorded flow.

## 4. Adversarial review

Confirmed facts are marked **Fact**; concerns about the design are marked **Concern**.

1. **Bypass of the Sentry GET.** **Fact:** every path in section 3 is reachable without the Sentry
   GET. **Concern:** a GET-only Sentry is decoration; enforcement must be repeated at the Auth
   Admission redemption, at every evidence-recording POST, at provider callbacks, and at the Base
   root-login commit.
2. **Unset flags stopping all sign-ins.** **Fact:** `feature_flags:register` creates features
   disabled, and availability reads them as closed; deploying the reader before writing `true`
   closes Sign In on that surface, ORG staff included. **Fact:** the Flipper UI is behind its own
   Basic-auth host, so recovery does not need ORG Sign In. **Concern:** the deploy must be gated by
   a verified `feature_flags:status` showing all six as on.
3. **Inconsistent Sign In / Sign Up state.** **Concern:** when `sign_up_available_*` is on and
   `sign_in_available_*` is off, a person can register but receives no session; Sign In First says
   this is a Sign In failure, not a reason to undo the Identity. **Concern:** a Sentry check placed
   inside `with_cycle_lock` that raises would roll back `:complete`; the handoff check must not
   raise inside that block.
4. **Redirect loops.** **Concern:** if Base redirects to the Sentry GET and the Sentry GET, on
   `ALLOWED`, redirects to an entry page that sends a missing-admission browser back to Base, a loop
   follows. The Sentry GET must redirect only to a fixed, server-built path and never to a
   request-supplied URL, and `BLOCKED` must be terminal (503), not a redirect.
5. **Admission damage.** **Concern:** forwarding `entry_ref` through an extra hop adds a URL that
   carries it. `entry_ref` is in `filter_parameters`; whether the redirect `Location` in the
   request log is filtered was not verified. The hop must not consume, decode or re-issue the
   reference; redemption stays in `AuthCeremonyAdmission`.
6. **Provider callbacks.** **Fact:** provider switches already use a draining callback decision.
   **Concern:** blocking a callback after the provider redirect wastes a completed provider
   assertion; whether a callback drains or is refused under `BLOCKED` is a product decision.
7. **OIDC protocol.** **Fact:** `prompt=none` never starts a ceremony and returns `login_required`;
   SSO code issuance does not call `log_in(:root_login)`. **Concern:** if Base, rather than Auth,
   refuses a blocked ceremony start, it should use an OIDC error response to the registered
   `redirect_uri` with `state`, not an HTML 503 that strands the RP transaction.
8. **DB or Flipper failure.** **Fact (code reading):** with `preload = true`, a flag-store error is
   likely raised by the Flipper middleware before any controller rescue, giving a 500 rather than a
   Sentry 503. Both refuse the request, but the status and the monitoring signal differ, and the
   same failure takes down every request on Base and Auth, not only sign entry. Not executed.
9. **Existing sessions and Sign Out.** **Concern:** gating `log_in(:root_login)` is safe for
   Refresh, Sign Out and `:rp_session`, which do not use it. Step-Up uses ticket ceremony purposes
   (`TICKET_CEREMONY_PURPOSES`) through the same `AuthCeremonyAdmission`; a Sentry check at
   Admission redemption must exclude them explicitly.
10. **Sign In First.** **Concern:** Sentry must never trigger sign-up compensation
    ([sign-up compensation](../docs/security/sign-up-compensation.md)) or move a completed Sign Up
    to a failure state. A blocked handoff ends with a durable Identity and no session.
11. **Race with in-flight transactions.** **Fact:** the flags live in `primary`, sessions and flows
    in other databases, and reads are memoized per request. A request that read `ALLOWED` at its
    start can commit a session after the flag is switched off. Re-reading at the Base commit in a
    separate request narrows the window to one request's duration; it does not close it.
12. **Emergency Access.** **Concern:** `sign_in_available_org = false` that also closes ORG
    Emergency Access removes the break-glass path during an incident.
