# Sign / Acme Connection — Corrected Audit & Remediation Plan

Status: inactive backlog as of 2026-06-14. The medium cleanup slice is complete: welcome route dedup
is already reflected in current routes, Acme preference helper compatibility is intentionally
preserved, and the stale Sign/Acme premise has been corrected. Remaining work is human-review-gated
residual Sign route retirement and should be reactivated only with explicit scope.

## Context

This continues in-flight surface-boundary work between the **Sign** and **Acme** surfaces
(app/com/org). The original task brief assigned identity/session/selector **authority to Sign** and
asked to strip those responsibilities out of Acme.

**That premise is inverted relative to the accepted architecture.** The canonical, most recent ADR
`adr/acme-sign-core-base-port-boundary.md` (Accepted **2026-06-12**) and its supporting ADRs
(`identity-authority-boundary.md`, `acme-session-and-token-authority.md`,
`sign-credential-gateway-surface.md`, `sign-residual-idp-surface-retirement.md`) all decide:

- **Acme is the only IdP / Authorization Server** and the authority for issuer/subject identity,
  OIDC/OAuth endpoints, JWKS, token issuance, sessions, refresh tokens, logout/session mutation,
  selector, identity settings, preference, dashboards, account lifecycle, authorization, and step-up
  **freshness**.
- **Sign is a special RP / credential-ceremony surface.** It may own only credential inventory and
  ceremony **execution** — WebAuthn/passkey + OTP/TOTP challenge/verification, social provider
  callbacks, and signed ceremony **result** issuance — pinned to `id.*` for WebAuthn URL binding.
  Sign must **not** be an IdP/issuer/token/session/refresh/logout/selector/identity-settings
  authority.

The user has confirmed (Direction **A**): resolve in favor of the accepted ADRs. **Do not move Acme
authority back to Sign. Do not delete Acme OIDC/selector/session/verification endpoints.** Instead,
audit and retire/redirect any residual **Sign-side** authority behavior, and proceed with the
direction-independent cleanups (welcome, preference, jump). No broad implementation yet — this slice
produces the corrected audit + a staged remediation plan with tests.

Evidence base (read this slice): `config/routes/sign.rb`, `config/routes/acme.rb`, the ADRs above,
GH issue #829, `plans/active/identity-authority-inversion-first-slice.md` (body superseded on
authority direction; its route-classification _vocabulary_ is reusable but its `SIGN_AUTHORITY`
assignments are NOT).

---

## 1. Stale task assumptions that conflict with the accepted ADR

| Task brief claim                                                | Reality (ADR + code)                                                                                                                                                                                                           |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Sign is authority for Session / Refresh Token / Logout          | Acme is. `acme-session-and-token-authority.md`. Sign has **no** refresh route (`config/routes/sign.rb` `edge/v0/token` = `check` + `dbsc` only) and **no** sign-out route — already retired.                                   |
| Sign is authority for Selector / Identity                       | Acme owns subject identity + selector. Selector/identity routes live under Acme.                                                                                                                                               |
| Sign owns Step-Up (authority)                                   | Sign **executes** the ceremony; Acme issues the grant and owns freshness. Acme `verifications_controller` is the correct Acme side, not a duplicate.                                                                           |
| "Acme acting as IdP endpoints are deletion candidates" (item 3) | Inverted. Acme IdP/OIDC endpoints are **retained**. Sign-side residual IdP endpoints are the deletion candidates — and `sign.rb` shows they are **already gone** (no `/oauth/*`, no `openid-configuration`, no `oidc/logout`). |
| "Remove Sign responsibilities from Acme" (item 1)               | Inverted. The migration direction is **Sign → Acme** (see explicit `# TODO: move settings to acme's identity entrypoints`, `config/routes/sign.rb:478`).                                                                       |

Direction-independent (premise-agnostic): welcome dedup (item 5), preference simplification (item
6), cross-surface jump repair (item 2), verification investigation (item 4 — answer is "keep Acme
side").

---

## 2. Sign-side residual authority endpoints — remove / redirect / mark legacy

These are Acme-authority concerns still routed under Sign hosts in `config/routes/sign.rb`. For
each, the implementation step is: confirm controller is already a redirect-only shell to Acme; if it
mutates durable state, convert to redirect/JumpRT-delegate; if fully replaced and test-covered,
remove the route. **Audit controller behavior before changing routes** (many are reportedly already
`Sign::RedirectOnlyController` via `SignAcmeAuthorityRedirect` / `SignSettingsAuthorityRedirect`).

Targets (paths in `config/routes/sign.rb`):

- `resource :dashboard` (lines 25, 219, 390) — dashboard is Acme authority.
- Org top-level `configuration`, `accounts`, `iam`, `system`, `audit`, `support`, `billing` (lines
  393–399) — account/org/authorization/audit = Acme authority.
- `settings` namespace: `sessions` + `revocation_attempt` + `session_revocations` (lines 199–205,
  370–376, 496–502); `activities` (208, 379, 518); `withdrawal` (209, 380, 519 — account lifecycle);
  `connections` for com/org (378, 504 — social link/unlink is app-only Sign concern; com/org should
  delegate to Acme); org `accounts`/`operator_lifecycle_requests` (521–525 — Acme authority).
- `settings/emails`, `settings/telephones` index/update/destroy where they edit durable identity
  state rather than run a verification ceremony — confirm they are redirect shells (the `index`
  destroy variants already route to `telephones/redirects`, lines 189/361/515).

**Keep on Sign (credential ceremony execution — explicit WebAuthn URL-binding exception):**
`sign/in/*` (email/passkey/secret_credential challenge), `sign/up/*`, `verification` +
`verification/{passkey,totp,emails}`, `settings/{passkeys,totps,secret_credentials,mfa}` ceremony
actions, `social/{apple,google}` connection ceremonies (app), `auth/*` omniauth callbacks,
`web/v0/in/*` OTP delivery, `.well-known/jwks.json` (jump-RT/redirect signing keys — retained per
`sign-residual-idp-surface-retirement.md` item 1, **not** an OIDC OP surface).

**Already retired (verify, then drop any dead controllers/views/tests):** Sign OIDC provider
endpoints, Sign refresh endpoint, Sign session-mutating sign-out. `sign.rb` no longer routes them.

---

## 3. Acme-side endpoints that MUST be preserved

Do not delete based on the stale premise:

- Acme OIDC/OAuth provider: `oauth/{authorize,token,userinfo,revoke,jwks}`, `sso/*`, `oidc/logout`,
  `.well-known/openid-configuration`, `.well-known/jwks.json` (`config/routes/acme.rb`).
- Acme `selector`, `identity`, `sessions` + revoke/others, `withdrawal`, `dashboard`, `welcome`,
  `preference`, `edge/v0/token/refresh` (refresh authority), `sign_out`/`oidc/logouts` (session
  mutation authority).
- Acme `verification` (`resource :verification, only: :show do post :completion end`) — this is the
  **Acme grant-issuer / result-consumer / freshness-committer** side of delegated step-up
  (`AcmeStepUpIntent`, `AcmeStepUpCompletion`, `IdentityStepUpCeremonyFreshnessCommitter`).
  **Keep.** Item 4's "duplication with Step-Up" concern is resolved: it is the counterpart, not a
  duplicate.

---

## 4. Items safe to implement regardless of authority direction

These do not move authority and can proceed in this slice once the plan is approved.

**4a. Welcome route dedup (item 5).** Current Acme routes now expose only the
`get :welcome, to: "welcomes#show", as: :welcome_entry` shape for app/com/org; the previously noted
`resources :welcomes, only: :show` duplicate is no longer present. Keep the `welcome_entry` helper
because cross-surface redirect logic still calls `*_welcome_entry_url`.

**4b. Preference routing simplification (item 6).** Current Acme preference routes intentionally
keep named screen helpers because views, mailers, and integration tests still depend on helpers such
as `edit_acme_app_preference_theme_url` and `acme_org_preference_region_url`. Do not collapse these
routes unless the implementation also preserves helper compatibility. The active boundary guard is
`AcmePreferenceScreenDispatch`, which enforces the screen allowlist and keeps preference authority
on Acme.

**4c. Cross-surface jump app/com/org (item 2).** The "jump" mechanism is a signed return-token
protocol (not Hono/edge): `JumpRtIssuer`, `JumpRtReturnVerifier`, `JumpRtReturnPolicy`,
`JumpRtSurface`, concerns `jump_rt_return_verification.rb` / `jump_to_redirector.rb`. Surface
resolution is fail-closed (controller-name regex → nil; host constraints → 404). Cross-surface URL
builders (`sign_acme_authority_redirect.rb`, `authentication_redirects.rb`) already branch
app/com/org. **Action:** add/repair coverage proving `Acme → Sign → Acme` round-trips for all three
surfaces with matching host/issuer/audience/return_to/redirect_uri/token scope, and assert unknown
surface fails closed. Fix any builder that falls back to app defaults for com/org (audit
`ENV.fetch("ACME_SERVICE_URL", ...)` branches and `JumpRtReturnPolicy` source/destination pairs).

---

## 5. Human-review items (boundary still ambiguous)

1. **`sign/in/session` (`resource :session, only: %i(show update destroy)`, lines 106, 313, 458)** —
   does Sign sign-in establish/mutate a session (forbidden) or only hand a ceremony result to Acme
   which then mints the session? `sessions_controller` reportedly does session-limit/promotion
   logic. Needs explicit confirmation against `acme-session-and-token-authority.md` before any
   change.
2. **`settings/mfa/reset` (line 167)** — MFA reset / account recovery: ceremony (Sign) vs account
   lifecycle (Acme)? Cross-check `adr/mfa-reset-account-recovery.md`.
3. **`settings/connections` for com/org (lines 378, 504)** — social link/unlink is an app-only Sign
   concern per first-slice notes; confirm com/org should redirect to Acme or be removed.
4. **Org `operator_lifecycle_requests` under Sign settings (521–525)** — almost certainly Acme/Base
   authority; confirm target surface.
5. **`abolish-fat-engines` / Base/Port introduction** — the canonical ADR introduces Core/Base/Port.
   Some "Acme authority" may ultimately land in **Base**, not Acme. Confirm whether this slice
   targets Acme or Base for the residual Sign→authority migration, to avoid a second move.

---

## Implementation staging (after approval)

Stage 1 (safe, this slice): 4a welcome dedup, 4b preference simplification, 4c jump round-trip
tests. Stage 2: classify + test §2 residual Sign endpoints (audit controllers; convert mutators to
redirect/delegate; drop dead routes only when replaced and covered). Stage 3 (separate slice):
remove confirmed-dead retired-IdP controllers/views/tests. §5 items gated on human review.

Follow `plans/active/identity-authority-inversion-first-slice.md` first-slice rules: do not change
DB placement, preserve old URLs via redirect where practical, no open redirects, preserve CSRF on
destructive actions, keep surfaces local, no hardcoded absolute URLs. Leave a
`notes/implementation/` entry recording the inverted-premise resolution and the residual-endpoint
classification.

## Verification

```bash
# Route shape before/after
bin/rails routes | grep -E "welcome|preference|sign|acme|oauth|oidc|selector|session|verification"

# Narrow first, then broaden
bin/rails test test/controllers/acme test/controllers/sign
bin/rails test test/controllers/controller_inheritance_invariant_test.rb   # untracked invariant test already in tree

# Authority guardrails (negative): Sign must not mutate Acme-owned state
rg -n "logout_current_session!|refresh_access_token|last_step_up_at|create_session" app/controllers/sign

# Jump round-trip: add request/integration tests asserting Acme->Sign->Acme for app/com/org
#   and unknown-surface fail-closed; assert helpers keep welcome_entry + preference screen routes.
```

End-to-end check: drive an app `Acme → Sign(step-up ceremony) → Acme(completion)` flow and the same
for com/org, confirming host/issuer/audience/return_to alignment and that welcome/preference routes
still resolve via their helpers. Run `bin/rails db:verify_no_schema_drift` only if a migration is
introduced (none expected — this is routing/controller work).

## Open items / risks

- §5 human-review items block their respective endpoint changes.
- Base/Port target ambiguity (§5.5) may redirect Stage 2's destination from Acme to Base.
- Welcome/preference helper renames risk breaking cross-surface redirect call sites — enumerate
  `*_welcome_entry_url` and preference screen helper usages before deleting routes.
