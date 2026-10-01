# Integrated Auth/Avatar/Warp remaining-work ledger

Status: active. This is the single execution ledger for the open items of
`plans/backlog/2026-09-24-integrated-auth-avatar-warp-plan.md`. It does not rewrite that plan's
history. Evidence for the 2026-09-26 pass: `evidence/2026-09-26-integrated-auth-remaining-pass-Q4T8.md`.

States: **done** (implemented and verified in the 2026-09-26 tree), **code-ready** (needs data
application), **external** (needs outside input, registration, keys, deployment, or a real service),
**open** (spec or implementation still missing), **deferred** (approved deferral).

## Items A–F

| Item | Original request | State | What remains | Needs |
| --- | --- | --- | --- | --- |
| A. Dashboard Avatar image | 14 | done, except browser render | Render check in a real browser: no Chromium in the 2026-09-26 environment. HTTP check against the dev server with a fakecloud-stored image passed. | A machine with a browser; load `/dashboard?ri=jp` and confirm the image paints. |
| B1. Emergency commit-acknowledgement contract | 07 | done | — | — |
| B2. Emergency issuance | 07 | open | Authenticated app session + Step-Up issuance of a `temporary_access`/`single_use` credential with `max_failures: 5` and `discard_at = issued_at + 5 minutes`; show the public ID with the secret once. | Decision below on the credential kind id. |
| B3. Emergency sign-in endpoint | 07 | open | `GET /sign/in/emergency` placeholder entrypoint exists, but Emergency Credential issuance/sign-in behavior remains unimplemented. Future behavior: call `ClientEmergencySecretCredentialSignInOperation.claim!`, create the session through `log_in` inside `issue_session!`, then `consume!`; keep the operation id in the ceremony so a retry only reconciles. Then verify end to end from the real entry point to a committed session. | B2. |
| B4. Retention purge of claimed-but-unconsumed Emergency rows | 07 | open | Confirm `RetentionPurgeJob` covers them once `discard_at` passes; add a test. | B2. |
| C1. Owner-family cutover | 02, 06 | code-ready | `bin/rails authority:cutover_guard` is read-only and fail-closed. On the dev DB it reports `ready: false` (app `client_persona` and `enterprise` have one unresolved row each; com/org families are empty). Run it on the target database, resolve each unresolved row through an authorized decision, then establish the marker. | Target-DB read access, owner decisions for unresolved rows, persistent-write approval and a recovery plan. |
| C2. Avatar moniker data | 06 | code-ready | The current schema has no `avatars.moniker` column; monikers live in `avatar_monikers`. Whether the target database went through the same migration and has conflicting history was not checked. | Target-DB read access. |
| C3. Legacy App LOGIN rows | 07 | code-ready | `bin/rails secret_credentials:legacy_login_inventory` is read-only. Select rows only by `user_secret_kind_id = LOGIN AND secret_kind IS NULL`: new-axis rows share the LOGIN kind id. Write a bounded logical-revocation operation (set `revoked_at`, move `discard_at` to now) with a dry run. | Persistent-write approval, recovery method, target-DB inventory. |
| D. Regional RP values | 05, 11 | external | `bin/rails auth:regional_rp_contract` (2026-09-26): `complete: false`. Missing canonical audience for `core-{app,com,org}-{jp,us}` and `side-{app,com,org}-jp`; missing canonical host for `side-{app,com,org}-us`; `edit-org` complete. | Official audience/host values, OIDC registrations, production keys, deployment. |
| E1. Turnstile real service | 10 | done for test keys | `JitSecurityTurnstileVerifier.verify` against real Cloudflare Siteverify with Cloudflare's public test secrets: pass → success; always-fail → `invalid-input-response`; spent → `timeout-or-duplicate`. | Site-specific non-production keys to verify hostname/action binding (`verify_for_ceremony`). |
| E2. Vite HMR | — | open (finding) | The page loads `/vite-dev/@vite/client` through Rails; the client's primary socket targets the page host/port, where Rails answers 404 to a WebSocket upgrade. The fallback `localhost:3036` upgrades (101), so HMR works only when the browser runs on the Vite host. Not browser-verified. | Decide whether dev should proxy WebSockets or set `server.hmr`; verify in a browser. |
| E3. Production logs | 09 | external | Not started. | Log access. |
| F1. Whole-tree regression | all | see evidence | Full-suite result on the 2026-09-26 tree is recorded in the evidence file. Another agent was editing the same worktree during this pass. | — |
| F2. GET/HEAD Set-Cookie guarantee | 04 | open | DB non-mutation is covered by tests. "No Set-Cookie on every HTML GET/HEAD" is not guaranteed and not claimed. The new image endpoint emits no application cookie (dev check showed only the development profiler cookie). | A design that keeps CSRF sessions and `header_or_legacy_token`. |

## Decision needed: Emergency credential kind id

- Undecided: which `user_secret_kind_id` an Emergency credential stores. The model default is
  `LOGIN`, the retired permanent kind.
- Why the code cannot decide: the reference table has `LOGIN`, `TOTP`, `RECOVERY`, `API`; none
  describes an Emergency credential, and adding an id changes reference data.
- Options: (1) add a new reference id `EMERGENCY` (recommended: explicit, keeps LOGIN revocation
  safe); (2) keep `LOGIN` and rely on `secret_kind` (every LOGIN query must then filter
  `secret_kind IS NULL`).
- Impact of (1): reference-data migration in `app_zenith`, kind constants, fixtures.
- Acceptance: issuance writes the chosen id; the legacy inventory and any revocation never select
  Emergency rows.

## Open: Cancel behavior on five Auth entry pages

Added 2026-10-01. Cancel functionality still needs implementation at these five entry points;
its detailed behavior and acceptance criteria have not been defined:

| Surface | Entry page | Current Cancel behavior |
| --- | --- | --- |
| app | Sign-in | Plain text only |
| app | Sign-up | Plain text only |
| com | Sign-in | Plain text only |
| com | Sign-up | Plain text only |
| org | Sign-in | Plain text only |

The labels reserve the UI choice; they do not implement cancellation. Define the behavior before
implementation, including the destination, affected ceremony/state, and applicable security
contract. This entry records open work and does not decide those details.

Org Sign-up is excluded: its informational page already uses a Cancel link to the former back-link
destination (`auth_org_root_path`), without a cancellation mutation.

## Deferred (approved)

- F10 billing/billings route naming.
- F15 redirect-only shims.
- Phase 4 F1 `session_nonce` and pre-reveal App top-up activation design.
