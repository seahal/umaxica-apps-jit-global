# Independent Re-verification of the Open Issue Inventory

## Context

An inventory ("棚卸し") of 59 open issues in `seahal/umaxica-apps-jit-global` was produced against
`feature` @ `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`. This document records an independent
re-check of the inventory's code-level claims at that same SHA (`git log -1` confirms HEAD matches).

Scope of the original check: code reading only. No tests were run, no issues were edited, and no
external systems were inspected at that time. Issues whose classification rested on legal
applicability, external infrastructure, or product sequencing were not re-verified.

## Current-worktree correction (2026-09-17)

This document remains a historical inventory at `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`; it is
not the current source of truth. The current `feature` worktree has since added an explicit
`SignUpExpiryJob` recurring entry for both development and production, and the current recurring
sections are intentionally aligned. Current implementation and verification status belongs in
`plans/backlog/2026-09-17-integrated-hardening-plan.md` and
`docs/operations/solid-queue-runtime.md`.

## Confirmed claims

| Issue | Claim                                                                           | Evidence at this SHA                                                                                                                                                                                                                                                          |
| ----- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| #811  | 30s default and 30s ceiling; env override 1–30s                                 | `app/values/security_token_lifetimes.rb:18` (`JUMP_RT_TTL = 30.seconds`); `app/lib/jump_rt_issuer.rb:11-12` sets both `DEFAULT_TTL` and `MAX_TTL` from it; `lib/config_values_jump_gateway_values.rb:34-36` raises outside 1..MAX                                             |
| #765  | Session presenter has no region/IP data                                         | `app/presenters/base/identity/session_presenter.rb:14` hardcodes `device:` to the `unknown_device` translation; no IP/region prop is built                                                                                                                                    |
| #839  | `CREDENTIAL_PENDING` still live                                                 | `app/models/client_sign_up_flow_status.rb:16` plus `client_sign_up_flow.rb:70,92,99,105` (reachable in `TRANSITIONS` from `STARTED` and `CONTACT_PENDING`)                                                                                                                    |
| #840  | No sign-up flow expiry job scheduled at the historical reference                | `config/recurring.yml` at the reference SHA contained no sign-up entry in either environment; this is corrected in the current worktree by `SignUpExpiryJob`                                                                                                                  |
| #841  | Guardrail bypass at the historical reference                                    | Confirmed at the historical reference; current contact-verified email/telephone transitions now require `GUARDRAIL_PENDING` before checkpoint. The app social callback path remains separately explicit. See `docs/security/sign-up-sequence.md`.                             |
| #842  | Code exchange resurrects a revoked connection                                   | `app/operations/oidc_connection_recorder.rb:20` sets `connection.revoked_at = nil` unconditionally on `find_or_initialize_by`                                                                                                                                                 |
| #844  | Revocation falls back to the parent token                                       | `app/operations/oidc_token_revoker.rb:64-67` — `find_rp_session_by_sid(...)                                                                                                                                                                                                   |     | find_token_by_sid(...)`, the latter matching `oidc_sid` on the root token class |
| #846  | Auth still carries RP identity and drives Base registration                     | `app/controllers/auth/app/application_controller.rb:114` returns `"sign-rp"`; `app/controllers/concerns/authentication_sequence_gate.rb:576,597,610` call `bind_session_and_register_oidc!` → `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` after `log_in` |
| #872  | Side effects ran inside the state transaction at the historical inventory point | Confirmed at the historical reference; the current implementation commits appeal state first, then performs Case convergence/audit and rediscoverable reconciliation. See `plans/backlog/2026-09-17-integrated-hardening-plan.md` and `adr/unified-enforcement.md`.           |
| #873  | Toolchain migrated off pnpm                                                     | `package.json` uses `bun --bun vitest`, `vitest` 5.0.0, `packageManager: bun@1.4.0`; `.github/workflows/ci.yml:68-74` uses `oven-sh/setup-bun` + `bun install --frozen-lockfile`; `vitest.config.ts:120-125` sets all four thresholds to 99                                   |
| #830  | Lock service is complete in-service                                             | `app/services/administrative_access_lock.rb` has `lock!`/`unlock!`, `revoke_sessions!` (106-107), `create_event!` (110), `ensure_operator_can_be_locked!` (128)                                                                                                               |
| #832  | Suite still red                                                                 | `evidence/2026-09-13-auth-boundary-consolidation.md:128,151` — latest recorded run 18 failures / 18 errors / 2 skips; line 171 records P4 as incomplete, matching the #846 finding                                                                                            |

## Corrections and additions to the inventory

1. **#843 — the historical finding is corrected in the current worktree.** At the inventory SHA, all
   three surface controllers (`app/controllers/base/{app,com,org}/oauth/tokens_controller.rb`)
   included `BaseOauthTokenEndpoint`, but the coordinator accepted the stored payload's
   `resource_type` without a trusted endpoint realm. The current controller passes its fixed
   resource type and the coordinator requires an allowlisted realm, checks it before code
   consumption, and performs the equivalent check before refresh rotation. Not mentioned in the
   historical inventory: `prevalidate_payload` (`:148-153`) did call
   `OidcClientRegistry.valid_redirect_uri?(..., resource_type: payload["resource_type"])`, and
   `OidcRedirectUriPolicy` enforces that the redirect URI is registered _for that realm_
   (`app/values/oidc_client_registry.rb:83-90`). Because the payload's own realm drives both the
   check and the tokens issued at the inventory SHA, redeeming an app-surface code at the org token
   endpoint could still cross the endpoint boundary while minting app-realm tokens. This was a
   boundary-hygiene defect, not a demonstrated privilege escalation; current tests assert rejection
   before consumption and do not describe it as an escalation regression.

2. **#844 — the parent-token lookup is guarded more tightly than the inventory implies.** After the
   fallback, `:68-69` still require `token_record.oidc_client_id == client_id` and a constant-time
   `oidc_jti` match against the presented JWT. So the fallback cannot revoke another client's token;
   the open question is narrower: whether revoking the _root_ token (SSO-wide) is the intended blast
   radius when no RP session row is found. The inventory's refusal to call this an RFC 7009
   violation is correct.

3. **Historical finding, now corrected in the current worktree: recurring sections diverged.** At
   the reference SHA, development omitted `RetentionPurgeJob` and the seven ceremony purges that
   production scheduled. The current explicit configuration aligns the business task set and adds
   `SignUpExpiryJob` to both environments. The current configuration still requires `bin/jobs check`
   and an isolated worker run before runtime completion can be claimed.

4. **#830's remaining condition is real.** The service is complete, but nothing in this check
   covered the schema/dump consistency or the UI-scope question the issue itself leaves open, so the
   inventory's "close only after confirming" stance stands unmodified.

## Not re-verified

Everything resting on non-code evidence: legal applicability (#647–#657, #654), external
infrastructure (#845 Cloudflare limits, #849 domain migration), retention-year requirements
(#554–#556, #640), and product-sequencing calls (UGC/DM/billing gates). The inventory's own caveats
on these are appropriate and this check neither strengthens nor weakens them.

No test run was performed in this session; every "confirmed" row above is code reading, and the
#832/#846 rows cite a previously recorded evidence file rather than a fresh run.
