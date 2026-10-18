# Security Audit — Authentication / Authorization / Session / Multi-Tenant Boundaries

> Date: 2026-06-13 Scope: Targeted audit of the app-surface authentication and authorization
> pipeline Findings promoted to: `adr/security-audit-findings-2026-06-13.md`

---

## Audit Methodology

Code review of the authentication and authorization pipeline: session cookies, JWT issuance and
validation, OAuth/OIDC account linking, multi-tenant boundary enforcement, token revocation chains,
and policy coverage. All findings were confirmed by reading code only — no external services were
called and no credentials were used.

---

## Confirmed Strengths

The following areas showed solid implementation and no material weaknesses:

| Area                          | Finding                                                                     |
| ----------------------------- | --------------------------------------------------------------------------- |
| Session cookies               | `__Host-session`, AES-256-GCM, SameSite=lax (intentional for OIDC callback) |
| Auth cookies                  | `__Host-access/refresh/dbsc`, SameSite=strict, HttpOnly                     |
| JWT algorithm                 | ES384 (ECDSA P-384); `alg=none` rejected; algorithm allowlisted in decoder  |
| JWT claims                    | iss, aud, typ, exp, sub, sid, act, jti, acr all validated                   |
| Refresh token storage         | SHA3-384 digest only; plaintext never stored                                |
| Refresh token reuse detection | Family-wide revocation + risk emission on reuse                             |
| DPoP                          | htm/htu/iat/jti/ath/jwk all validated                                       |
| DBSC                          | ES256/RS256, RSA 2048-bit minimum, challenge TTL 5 minutes                  |
| Session fixation              | `reset_session` on login and logout                                         |
| Access policy                 | `enforce_access_policy!` cannot be skipped                                  |
| Default auth mode             | `:deny_all` — unset actions are blocked by default                          |
| IDOR pattern                  | `current_user.resources.find()` scoped in all reviewed settings controllers |
| ActionPolicy default          | deny-all, relation scope returns `.none`                                    |
| TOTP replay                   | `last_otp_at` prevents same-window reuse (lock missing — see FINDING-06)    |
| SUSPEND/TERMINATE revocation  | `revoke_target_sessions!` called on SUSPEND and TERMINATE transitions       |

---

## Findings by Severity

### Critical

**FINDING-01 — organization_id from params with no org ownership check**

Root cause: `OperatorLifecycleRequestPolicy#operator?` shadowed `ApplicationPolicy#operator?`. The
base class method calls `has_role?` (undefined on Operator) and requires org context; the subclass
replaced it with a type-check only. Additionally, `authorize!(OperatorLifecycleRequest)` passes the
class, not a record, so `organization` in the policy was always `nil`.

Attack path (confirmed by code trace):

1. Authenticated Operator A posts lifecycle request with `organization_id` of Org B.
2. Policy checks `user.is_a?(Operator)` → true. Passes.
3. Service saves the request with Org B's id.
4. Any Operator C can approve → `different_operator?` → true. Passes.
5. Execute fires on Org B. Org B's operator membership is changed.

All lifecycle phases (create / approve / reject / execute) used the same shadowing method. The
4-eyes check (`different_operator?`) is intentional global design and was not changed.

**Status: Fixed** — see `adr/security-audit-findings-2026-06-13.md`.

---

### High

**FINDING-02 — Credential destroy does not revoke existing sessions**

`session_version` increment in `AuthenticationLogoutAllSessions` is a no-op for `Client` (column
does not exist). The real session cut-off relies on marking `ClientToken` records as `REVOKED`,
which was not called from `SecretCredentialsDestroy` or its controller.

Maximum attack window before fix: 14 days (refresh token TTL) if the attacker also held a refresh
token; 1 hour (access token TTL) with access token only.

**Status: Fixed** — see `adr/security-audit-findings-2026-06-13.md`.

---

**FINDING-03 — Social auth account linking does not reject email_verified=false**

`SocialAuthVerifiedProviderAssertion` did not check `email_verified`. Immediate risk is low because
the primary identity key is `uid + provider`, not email. Risk materializes if any future code path
matches accounts by email without re-checking email_verified at that point.

**Status: Fixed** — see `adr/security-audit-findings-2026-06-13.md`.

---

**FINDING-04 — No after_action :verify_authorized mechanism**

ActionPolicy 0.7.6 does not ship `after_action :verify_authorized`. A new action that forgets to
call `authorize!` passes authentication but skips authorization silently. No current CI or test
enforces `authorize!` coverage.

`enforce_access_policy!` enforces authentication; it does NOT enforce that object-level `authorize!`
was called in the action.

**Status: Documented, not structurally fixed.** Long-term track in backlog. Near-term: policy test
coverage (owner-allows / non-owner-denies) is the primary regression guard.

---

**FINDING-05 — Role downgrade after-effect (revised to Medium)**

Initially suspected: downgraded Operator could use old access token for up to 1 hour. After
investigation: JWT access tokens do NOT embed role or permission claims. Every `authorize!` call
reads current DB state via `load_current_resource`. Role downgrade takes effect on the next request.
**Revised from High to Medium; no fix needed.**

---

### Medium

**FINDING-06 — TOTP same-window replay via last_otp_at without DB lock**

`totp_record.update!(last_otp_at: ...)` is called without `with_lock`. Concurrent requests using the
same code in the same 30-second window may both succeed. Not fixed in this round.

**FINDING-07 — Argon2id parameters are gem defaults, unmeasured in production**

`has_secure_password algorithm: :argon2` uses RFC_9106_LOW_MEMORY defaults (t=3, m=64MiB, p=4).
Parameters are not pinned in an initializer; production hash time is not documented. Not fixed in
this round.

---

### Low / Info

**FINDING-08** — WebAuthn rpId falls back to `request.host` if `WEBAUTHN_APP_RP_ID` env is unset.
Mitigated by `validate_webauthn_origin!` trusted-origins check. Recommend: raise on startup if env
var is absent.

**FINDING-09** — Browser JS has no DPoP implementation. Web sessions use plain Bearer. Intentional
design; DBSC provides binding for supported browsers.

**FINDING-10** — No `config/environments/staging.rb`; env isolation relies on `AUTH_JWT_ISSUER` env
var. JWT `verify_iss: true` is active. Risk is ENV misconfiguration.

---

## Key Implementation Details Discovered

### `session_version` is a ghost feature for Client

`AuthenticationLogoutAllSessions#increment_session_version_if_present!` checks
`resource.respond_to?(:session_version)` and increments it. `Client` does NOT have this column. The
method silently no-ops. Token revocation (marking `ClientToken` as REVOKED) IS the real revocation
mechanism for Client sessions.

### AuthenticationLogoutAllSessions exception safety

`AuthenticationLogoutCurrentSession#call` has
`rescue StandardError; fail_sign_out_flow(cycle); raise`. It can re-raise.
`AuthenticationLogoutAllSessions#revoke_one!` rescues `ActiveRecord::ActiveRecordError` (which is
`StatementInvalid`'s superclass). If a `StandardError` that is NOT an `ActiveRecordError` propagates
from `revoke_one!`, it will surface to the controller. The controller's
`rescue_from ApplicationError` may not catch it. This is acceptable: a failed revocation should be
visible as a 500, not silently swallowed.

### Why the FINDING-02 fix is in the controller, not in ClientSecretCredentialsDestroy

`ClientSecretCredentialsDestroy` is a domain service for credential state. Session revocation is an
authentication lifecycle concern. Mixing them would create a dependency on the authentication layer
inside a domain service, and would duplicate logic already owned by
`AuthenticationLogoutAllSessions`.

### Pre-existing test bug fixed as a side effect

`test_secret_credential_removal_is_allowed_when_another_aal1_method_remains` used
`assert_difference("ClientSecretCredential.count", -1)`. `ClientSecretCredentialsDestroy` uses
`discard_now!` (soft delete via `update!`). No default scope on `ClientSecretCredential` excludes
soft-deleted records. `fixtures :all` in test_helper loads `client_secret_credentials.yml` (3
records) even when the test class declares an explicit fixture list. The count was always 4 and
never changed. The assertion was replaced with
`assert_predicate secret_credential.reload, :lapsed?`.

---

## Open Questions Not Resolved

1. **FINDING-06 TOTP lock**: `totps_controller.rb` update path should use `with_lock`. Not done in
   this audit round.

2. **FINDING-04 structural enforcement**: `after_action :verify_authorized` requires a sweep of all
   controller actions before it can be safely enabled. Deferred.

3. **FINDING-07 Argon2id**: Production hash timing needs to be measured and parameters pinned in
   `config/initializers/`. Not done in this audit round.

4. **FINDING-08 WebAuthn rpId startup check**: `raise` on missing `WEBAUTHN_APP_RP_ID` env var
   should be added at startup. Not done.
