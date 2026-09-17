# Independent Re-verification of the Open Issue Inventory

## Context

An inventory ("棚卸し") of 59 open issues in `seahal/umaxica-apps-jit-global` was produced against
`feature` @ `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`. This document records an independent
re-check of the inventory's code-level claims at that same SHA (`git log -1` confirms HEAD matches).

Scope of this check: code reading only. No tests were run, no issues were edited, no external
systems were inspected. Issues whose classification rests on legal applicability, external
infrastructure, or product sequencing were not re-verified.

## Confirmed claims

| Issue | Claim | Evidence at this SHA |
| --- | --- | --- |
| #811 | 30s default and 30s ceiling; env override 1–30s | `app/values/security_token_lifetimes.rb:18` (`JUMP_RT_TTL = 30.seconds`); `app/lib/jump_rt_issuer.rb:11-12` sets both `DEFAULT_TTL` and `MAX_TTL` from it; `lib/config_values_jump_gateway_values.rb:34-36` raises outside 1..MAX |
| #765 | Session presenter has no region/IP data | `app/presenters/base/identity/session_presenter.rb:14` hardcodes `device:` to the `unknown_device` translation; no IP/region prop is built |
| #839 | `CREDENTIAL_PENDING` still live | `app/models/client_sign_up_flow_status.rb:16` plus `client_sign_up_flow.rb:70,92,99,105` (reachable in `TRANSITIONS` from `STARTED` and `CONTACT_PENDING`) |
| #840 | No sign-up flow expiry job scheduled | `config/recurring.yml` contains no sign-up entry in either environment |
| #841 | Guardrail bypass permitted | `client_sign_up_flow.rb:111-113,118-121` — both `CONTACT_VERIFIED` and `SOCIAL_CALLBACK_PENDING` list `CHECKPOINT_PENDING` directly alongside `GUARDRAIL_PENDING` |
| #842 | Code exchange resurrects a revoked connection | `app/operations/oidc_connection_recorder.rb:20` sets `connection.revoked_at = nil` unconditionally on `find_or_initialize_by` |
| #844 | Revocation falls back to the parent token | `app/operations/oidc_token_revoker.rb:64-67` — `find_rp_session_by_sid(...) || find_token_by_sid(...)`, the latter matching `oidc_sid` on the root token class |
| #846 | Auth still carries RP identity and drives Base registration | `app/controllers/auth/app/application_controller.rb:114` returns `"sign-rp"`; `app/controllers/concerns/authentication_sequence_gate.rb:576,597,610` call `bind_session_and_register_oidc!` → `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` after `log_in` |
| #872 | Side effects run inside the state transaction | `app/models/concerns/enforcement_appeal.rb:48-57` — `EnforcementCaseEndOperation.call` and `write_audit_event!` both inside `resolve!`'s `transaction do`; `submit!` (33-36) likewise wraps the audit write |
| #873 | Toolchain migrated off pnpm | `package.json` uses `bun --bun vitest`, `vitest` 5.0.0, `packageManager: bun@1.4.0`; `.github/workflows/ci.yml:68-74` uses `oven-sh/setup-bun` + `bun install --frozen-lockfile`; `vitest.config.ts:120-125` sets all four thresholds to 99 |
| #830 | Lock service is complete in-service | `app/services/administrative_access_lock.rb` has `lock!`/`unlock!`, `revoke_sessions!` (106-107), `create_event!` (110), `ensure_operator_can_be_locked!` (128) |
| #832 | Suite still red | `evidence/2026-09-13-auth-boundary-consolidation.md:128,151` — latest recorded run 18 failures / 18 errors / 2 skips; line 171 records P4 as incomplete, matching the #846 finding |

## Corrections and additions to the inventory

1. **#843 — the inventory's finding holds, but it understates one control and overstates the
   reachable impact.** All three surface controllers (`app/controllers/base/{app,com,org}/oauth/tokens_controller.rb`)
   include `BaseOauthTokenEndpoint`, whose `create` (lines 7-20) forwards no surface identity, so
   `OidcTokenExchangeCoordinator` takes `resource_type` solely from the stored payload
   (`:113`, `:262`, `:282-300`). That is the missing contract the issue describes.
   Not mentioned in the inventory: `prevalidate_payload` (`:148-153`) does call
   `OidcClientRegistry.valid_redirect_uri?(..., resource_type: payload["resource_type"])`, and
   `OidcRedirectUriPolicy` enforces that the redirect URI is registered *for that realm*
   (`app/values/oidc_client_registry.rb:83-90`). Because the payload's own realm drives both the
   check and the tokens issued, redeeming an app-surface code at the org token endpoint still mints
   app-realm tokens — this is a boundary-hygiene defect, not a demonstrated privilege escalation.
   The acceptance test should assert the endpoint's own surface is compared against the payload,
   and should not be written as an escalation regression test.

2. **#844 — the parent-token lookup is guarded more tightly than the inventory implies.** After the
   fallback, `:68-69` still require `token_record.oidc_client_id == client_id` and a constant-time
   `oidc_jti` match against the presented JWT. So the fallback cannot revoke another client's
   token; the open question is narrower: whether revoking the *root* token (SSO-wide) is the
   intended blast radius when no RP session row is found. The inventory's refusal to call this an
   RFC 7009 violation is correct.

3. **New finding, relevant to #639 and #840: `config/recurring.yml` development and production
   sections have diverged.** Development schedules only `clear_solid_queue_finished_jobs`, the DPoP
   purge, the consumed-JTI purge, the one-time-reveal purge, and the two enforcement jobs. It omits
   `retention_purge` (`RetentionPurgeJob`) and all seven `*_ceremony_transaction_purge` jobs that
   production schedules (`:54-80`). Any retention or expiry work signed off by exercising the
   development schedule would not be exercising the production one. Worth confirming whether the
   omission is deliberate before closing anything retention-related.

4. **#830's remaining condition is real.** The service is complete, but nothing in this check
   covered the schema/dump consistency or the UI-scope question the issue itself leaves open, so
   the inventory's "close only after confirming" stance stands unmodified.

## Not re-verified

Everything resting on non-code evidence: legal applicability (#647–#657, #654), external
infrastructure (#845 Cloudflare limits, #849 domain migration), retention-year requirements
(#554–#556, #640), and product-sequencing calls (UGC/DM/billing gates). The inventory's own caveats
on these are appropriate and this check neither strengthens nor weakens them.

No test run was performed in this session; every "confirmed" row above is code reading, and the
#832/#846 rows cite a previously recorded evidence file rather than a fresh run.
