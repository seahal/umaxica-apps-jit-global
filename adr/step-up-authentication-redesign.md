# ADR: Step-Up Authentication Mechanism Redesign

**Status:** Accepted (2026-05-11)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

**Correction (2026-05-19):** The current route contract for `settings_mfa` is
`/settings/mfa/challenge` on every sign surface. WebAuthn challenge state remains in the Rails
session store; only email OTP step-up state uses the cache-backed `step_up_session:*` keys.

**URL boundary supersession (2026-06-02):** `adr/preference-setting-configurator-url-boundaries.md`
sets the target URL language. User self-service account settings belong under canonical `/setting`,
and existing plural `/settings` references in this ADR describe the implementation-era route
contract until a route migration plan replaces them.

## Context

The step-up authentication mechanism gates sensitive operations (social-login unlink, withdrawal,
session revoke-all, credential management) behind a freshness check: "did the actor complete step-up
authentication within the last 15 minutes for this scope?" The original design was started during
the Rails engine migration era, then abandoned mid-implementation when that migration stalled. The
result was a half-built system with multiple regressions:

- `StepUp::AvailableMethods` and `StepUp::ConfiguredMethods` (`app/services/step_up/*.rb`) are
  byte-for-byte identical, so the fork between "needs bootstrap (no credentials)" and "needs step_up
  (has credentials)" in `Verification::Base#enforce_step_up_prereqs!` cannot distinguish the two
  states.
- `Sign::*::Verification::SetupsController#new` is a three-line stub that echoes `rt` into an
  instance variable. It does not filter by what is already configured, does not auto-bounce when all
  methods are configured, and is identical across surfaces despite per-surface method differences
  (e.g., org supports passkey only).
- Configuration registration controllers (`Configuration::PasskeysController#new`, etc.) do not
  honor `params[:rt]`, so the "setup → register → return to the original sensitive action" loop is
  silently broken. The user lands on `/settings` instead of the action they were trying to do.
- `ClientStepUpSession` / `VisitorStepUpSession` / `OperatorStepUpSession` exist with full schemas
  (`status, attempt_count, verified_at, discarded_at, method`, `Retainable`) but no controllers wire
  them. Controllers store step-up state in cookie sessions instead. Two parallel mechanisms, only
  the cookie one is alive.
- Orphan views under `app/views/sign/{app,org}/step_up/` (8 files) reference `@step_up_session` /
  `@step_up_sessions` with no controller to render them.
- `ALLOWED_SCOPES` (in `Sign::AppVerificationBase` and equivalents) is missing `session_revoke_all`,
  which is used by all three surfaces' session controllers. Entering
  `/verification?scope=session_revoke_all&...` raises `ActionController::BadRequest`. The
  `settings_mfa` regex matches `/settings/mfa`, but the actual route is `/settings/challenge`.
- `Sign::App::Settings::GooglesController#destroy` does not exist and is not routed; Google
  identities cannot be unlinked (Apple can).

Because credentials cannot be cleanly removed and bootstrap users (social-login-only accounts with
zero step-up methods) hit an infinite redirect loop between `enforce_step_up_prereqs!` and the
registration controllers, the feature is effectively dark in production. This ADR records the
redesign decisions agreed in the 2026-05-11 design dialogue.

## Decision

### A. Persistence

- **A1.** The step-up ticket is stored in a temporary token-bound DB row, not in the session cookie
  store and not in actor profile state.
- **A2.** Each surface's step_up_session table is co-located with its current login/session token:
  - `ClientStepUpSession`: `mark` (`< AppTicketRecord`), keyed by `user_token_id`
  - `VisitorStepUpSession`: `symbol` (`< ComTicketRecord`), keyed by `visitor_token_id`
  - `OperatorStepUpSession`: `token` (`< OrgTicketRecord`), keyed by `staff_token_id`
- **A3.** The actor-side tables on `principal` / `guest` / `operator` are not created. StepUp rows
  are short-lived login/session tickets.

### B. Schema

- **B1.** One row per ticket. The `method` column becomes **nullable**. A ticket is created at
  gate-entry with `method = NULL, status = PENDING`, then updated when the user picks a method on
  `/verification`.
- **B2.** Per-token singleton with **upsert** semantics. At most one row per login/session token
  exists at any time. A new gate-entry overwrites the current token's row in place rather than
  inserting a new row and marking the old one `CANCELLED`.
- **B3.** `UNIQUE(<token>_id)` constraint enforces the singleton at the DB layer (replaces the
  previous non-unique `(<actor>_id, status)` index).
- **B4.** `STATUSES` reduced to `%w(PENDING VERIFIED)`. `CANCELLED` is unnecessary because overwrite
  replaces the old ticket; `EXPIRED` is unnecessary because `discarded_at < Time.current` is
  computed at read time.
- **B5.** Email OTP secret/counter state lives in cache, keyed by
  `step_up_session:{step_up_session_id}:email_otp`, with TTL ≤ `STEP_UP_TTL`. WebAuthn challenge
  bytes remain in the Rails session store and continue to use the existing one-time-use / TTL
  challenge lifecycle.

### C. Judgement logic

- **C1. `ConfiguredMethods(actor)`** — existence of a credential record in counting status,
  surface-aware:
  - app: `email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`, `totp ACTIVE`
  - com: `email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`
  - org: `passkey ACTIVE`
- **C2. `AvailableMethods(actor, ticket: nil) ⊆ ConfiguredMethods(actor)`**. Subtract:
  - Methods currently in cooldown (per-method last attempt within window).
  - **All** methods, if `ticket && ticket.attempt_count >= 5` (ticket-scoped lockout).
- **C3.** Cooldown windows:

  | method      | window | rationale                                             |
  | ----------- | ------ | ----------------------------------------------------- |
  | `email_otp` | 60 s   | SES rate-limit / anti-spam / delivery-cost protection |
  | `passkey`   | 5 s    | WebAuthn assertion replay / double-click protection   |
  | `totp`      | 5 s    | TOTP code reuse / double-submit protection            |

  All three cooldowns are required as defense-in-depth. The 5 s windows are below normal human
  interaction speed, so they are invisible to users in practice.

- **C4.** Lockout is **ticket-scoped only**. `attempt_count` is a monotonic counter on the ticket
  spanning all method switches. At `attempt_count >= 5` the ticket refuses further step-up attempts;
  a new ticket via overwrite is required. Account-wide lockout is intentionally out of scope and may
  be layered on later if abuse is observed.
- **C5.** TTL is unified at **15 minutes** for `STEP_UP_TTL` (token freshness for repeat operations)
  and `STEP_UP_TTL` (`step_up_session.discarded_at` window). The previous
  `VERIFICATION_POST_TTL = 30.minutes` and `VERIFICATION_GET_TTL = 15.minutes` distinction is
  dropped in favor of one value.
- **C6.** `ConfiguredMethods` and `AvailableMethods` results are recomputed every request and not
  cached across the request lifecycle. This bounds the TOCTOU window to a single request.
- **C7.** Runtime bootstrap gating is driven by the persisted actor MFA status column, not by each
  controller independently recomputing credential presence. The credential records still determine
  the cached status, but controllers read the cache:
  - `multi_factor_status_id = 5` (`UNCONFIGURED`) means the actor has no surface-counting step-up
    method and may enter only the configured bootstrap-exempt registration actions without step-up.
  - `multi_factor_status_id = 1` (`ACTIVE`) means the actor has at least one surface-counting
    step-up method and sensitive configuration pages require step-up.
  - `multi_factor_status_id = 0` (`NOTHING`) is a placeholder only. Runtime checks must raise if it
    appears, because it indicates an implementation or data synchronization bug.

### D. Scope catalog (nine scopes)

| scope                  | path regex                  |
| ---------------------- | --------------------------- |
| `social_unlink`        | `\A/social/`                |
| `session_revoke_all`   | `\A/settings/sessions`      |
| `withdrawal`           | `\A/settings/withdrawal`    |
| `settings_email`       | `\A/settings/emails`        |
| `settings_telephone`   | `\A/settings/telephones`    |
| `settings_passkey`     | `\A/settings/passkeys`      |
| `settings_mfa`         | `\A/settings/mfa/challenge` |
| `configuration_secret` | `\A/settings/secrets`       |
| `settings_totp`        | `\A/settings/totps`         |

`session_revoke_all` is newly added (fixes the missing-scope `BadRequest` bug). `settings_mfa`'s
regex is corrected to match the actual route. `manage_totp` is renamed `settings_totp` for naming
consistency. Each `verification_scope` in the registration controllers must be updated to match.

The scope catalog is an allowed vocabulary, not the source of truth for a sensitive action's
requirement. Authorization policy owns the required AAL, method set, and scope for a concrete
actor/action/resource. Controller or action metadata may reference this catalog for inventory and CI
assertions, but runtime enforcement must not use metadata as a second source of truth.

### E. Per-surface configuration

| surface | step-up methods                  | bootstrap-exempt registration actions                                                                                                                                                 |
| ------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| app     | `email_otp` / `passkey` / `totp` | `Configuration::Emails::RegistrationsController` `{new, create, edit, update}`, `Configuration::PasskeysController` `{new, create}`, `Configuration::TotpsController` `{new, create}` |
| com     | `email_otp` / `passkey`          | `Configuration::Emails::RegistrationsController` `{new, create, edit, update}`, `Configuration::PasskeysController` `{new, create}`                                                   |
| org     | `passkey`                        | `Configuration::PasskeysController` `{new, create}`                                                                                                                                   |

`step_up_supported_methods` returns the corresponding set per surface.

For com: the `namespace :verification` `resource :totp` route, the `namespace :settings`
`resources :totps` route, `Sign::Com::Verification::TotpsController`, and any com TOTP views are
removed.

For org: the email registration routes remain (for credential management) but are **not**
bootstrap-exempt. Org users must register a passkey as their first method.

Telephone registration and passcode-management controllers are not bootstrap-exempt on any surface
because they are not step-up methods.

### F. Bootstrap

- **F1.** Trigger: the actor's persisted `multi_factor_status_id` is `UNCONFIGURED` (`5`). The
  status is calculated from the same narrow surface-aware credential definition as
  `ConfiguredMethods(actor)`: only step-up-eligible credentials count. Social-login identities,
  telephones, and passcodes do not satisfy this check.
- **F2.** Exemption helper:

  ```ruby
  def require_step_up_unless_bootstrap!(scope:)
    return true if step_up_bootstrap_unconfigured?
    require_step_up!(scope: scope)
  end
  ```

  applied as `before_action` on the actions listed in E. Both `new` and `create` (and `edit` /
  `update` for email/telephone OTP confirmation) re-evaluate the persisted MFA status to bound the
  TOCTOU window to a single request. The status is refreshed by credential lifecycle callbacks.

- **F3.** Re-bootstrap is permitted. If credential lifecycle changes recalculate
  `multi_factor_status_id` back to `UNCONFIGURED` for any reason (admin revocation, status downgrade
  due to email bounce, data fix), the actor re-enters bootstrap mode. Operational ratchet-locks are
  intentionally not enforced; recovery via fresh registration is the fallback.
- **F4.** No audit event or notification is emitted specifically for bootstrap completion. Standard
  credential-registration audit events continue to fire.
- **F5.** Sign-up flow stays separate. `Sign::App::Up::TelephonesController#passkey_registration`
  continues to handle the pstep-up "create account + first passkey" wizard. Bootstrap covers the
  post-auth case where an existing account (e.g., social-login-only) reaches zero configured
  methods. Future sign-up paths (additional social providers, invitations, SAML) can evolve
  independently.

### G. Setup-after-registration return flow (X')

After a bootstrap registration completes successfully, the registration controller:

1. Validates `params[:rt]` as a return-target token bound to the current session, surface, and flow.
2. Calls
   `safe_redirect_to(return_target.path, fallback: <surface>_configuration_path(ri: params[:ri]))`.

The destination page names the next operation inline (the page the user is bounced to already shows
what to do next). This application does not use `flash`; do not carry a one-time notice across the
redirect. See `.agents/harnesses/rules/generic/no-flash-messages.mdc`.

At the original sensitive endpoint, `require_step_up!` fires again. This time
`ConfiguredMethods.empty?` is false, so the user is sent to `/verification` (not setup) and
completes step_up with the freshly-registered credential. The original action then proceeds.

The return-target token is a navigation primitive only. It must not authorize the action and must
not decide the step-up requirement. On return, the policy is evaluated again for the current
actor/action/resource, and the step-up gate compares the current session's proof to that policy
requirement.

Signed return or step-up tokens must still be replay-hardened. A valid signature proves only that
the server issued the token and that the payload was not modified. It does not prove that the token
is fresh, unused, intended for this flow, intended for this surface, or bound to this browser
session. Return-target and step-up continuation tokens must therefore be:

- one-shot, using a server-side `jti` or challenge/ticket id that is rejected after consumption;
- bound to the current login/session token;
- bound to the host-derived surface;
- bound to the expected flow;
- short-lived;
- rejected if the token scope, flow, surface, session, actor, or target resource does not match the
  policy requirement and current request context.

POST requests must not be automatically replayed after step-up. Return targets after step-up should
land on a safe confirmation or re-submit page, not silently repeat the original state-changing
request.

### H. Removals

- com `verification.totp` route and `configuration.totps` route
- `app/controllers/sign/com/verification/totps_controller.rb`
- com TOTP views, if any
- `app/views/sign/app/step_up/*.html.erb` (4 files) — orphan
- `app/views/sign/org/step_up/*.html.erb` (4 files) — orphan
- `STATUSES` literal members `CANCELLED` and `EXPIRED` in the three step_up_session models
- The `(<actor>_id, status)` non-unique index, replaced by `UNIQUE(<token>_id)`

Out of scope for this ADR (tracked separately):

- `Sign::App::Settings::GooglesController#destroy` is missing and `resource :google` does not
  include `destroy`. Adding Google unlink symmetric to Apple is a follow-up.

## Rationale

**Why DB-backed.** Cookie-based step-up state cannot participate in revoke-all-sessions, cannot be
observed across devices for audit, and cannot persist `attempt_count` for ticket-scoped lockout. The
existing schemas (with `Retainable`, `attempt_count`, `verified_at`) already encode these
capabilities; reviving them is cheaper than designing a parallel mechanism on top of the cookie
store.

**Why co-located with the token.** A pending step-up ticket is login/session state: it must be
consumable only by the browser session that started it, and it must not let another session for the
same actor view, overwrite, or consume the ticket. Keeping the ticket beside the token also avoids
cross-DB logical references.

**Why upsert with `UNIQUE(<token>_id)`.** Carrying multiple PENDING tickets per token adds
implementation complexity (when to cancel which, how to choose which ticket to verify against)
without a clear UX win. Separate tokens for the same actor can still run independent step-up flows.
Upsert also lets us drop `CANCELLED` from the status enum entirely.

**Why narrow Configured definition.** Bootstrap exists because the user has nothing to step_up
**with**. Social-login identities cannot issue a step-up challenge; passcodes are AAL1 sign-in
methods, not session-elevation methods. Counting them in `Configured` would force a
social-login-only user to "step_up with their Google identity" — there is no such flow.

**Why ticket-scoped lockout only.** Account-scoped lockout is harsher on legitimate users (one stray
child / cat at the keyboard locks the whole account) and adds another piece of state
(`User.step_up_locked_until` or equivalent). Ticket-scoped is the minimum that prevents unbounded
brute-force within a single sensitive operation. If session-theft brute-force across scopes becomes
an observed pattern, account-scoped can be layered on later.

**Why 15 minutes uniformly.** Splitting GET vs POST windows complicates the spec without a clear
operational benefit. 15 minutes is long enough for ordinary form-completion latency and short enough
to keep step-up meaningful.

**Why re-bootstrap allowed.** A strict ratchet (`bootstrap_completed_at` flag) protects against a
credential-downgrade-then-rebootstrap attack vector, but the downgrade itself requires either
operator action or a slow natural process. The safety benefit is small, and the cost of a strict
ratchet — users losing all access after operator-led revocation must go through a manual support
path — is large. The implementer-mistake recovery argument carried decisive weight in the dialogue.

**Why X' (auto-bounce) for setup return.** Z (drop to `/settings`) makes the user re-navigate to the
action they were already trying to do — a UX regression from the intended "one credential and you
can proceed" experience. Y (explicit confirmation page) adds a click and a "no" branch to design. X'
auto-bounces to the return target, where the destination page names the next operation inline. (An
earlier draft carried this hint in `flash[:notice]`; flash has since been removed application-wide,
so the destination page owns the inline messaging — see
`.agents/harnesses/rules/generic/no-flash-messages.mdc`.)

## Consequences

- Implementation will be carried out by a separate AI agent in phases.
- Schema migrations keep the step-up tables on the three token databases (`mark`, `symbol`, `token`)
  and key them by token id.
- Controllers in `settings/` namespaces gain a new `before_action` helper and now honor
  `params[:rt]` on `create` through the return-target token primitive. Existing tests that assert
  post-create redirect destination must be updated.
- `ALLOWED_SCOPES` and the per-controller `verification_scope` values must be kept in lockstep with
  the table in section D for inventory purposes. Policy remains the runtime source of truth for
  which scope a sensitive action requires. A test asserting the cross-reference is recommended.
- The `manage_totp` → `settings_totp` rename requires updating one constant and one
  `verification_scope` return value. No external URL changes.
- com no longer has TOTP routes or controllers. Any external bookmarks pointing to `/settings/totps`
  on the com host break with 404. Acceptable because the feature was never advertised on com.
- The `/verification/setup/new?ri=...&rt=...` URL shape is unchanged. The `rt` value is now an
  opaque return-target token; old Base64-only values are not a compatibility contract.

## Related

- `adr/sign-configuration-sprint-spec.md` — earlier sprint that introduced
  `AuthMethodGuard.last_method?` (the unlink-side guard complementary to step-up).
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — refresh-path AAL guarantees that this
  ADR's `step_up_satisfied?` depends on.
