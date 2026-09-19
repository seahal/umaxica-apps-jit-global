# `rt` Foundation Services And Bootstrap Acceptance

## Context

- Related plans / ADRs:
- Predecessor note:
  `notes/implementation/2026-05-23-authentication-rt-signed-token-compatibility.md`
- Concurrent constraint:
  - test DB still trips the application's 791-migration pending gate, so `bin/rails test` is
    unrunnable for ad-hoc focused suites. Functional verification used `bin/rails runner` instead.

## Decisions Made During Implementation

- Reintroduced `app/services/request_context/contract.rb` as the single source of truth for the
  `ri / rt / lx ct tz cu df tf mo dn pp` key table, internal names, and family classification.
  - Why: Phase 1 of public-request-context plan requires it; the previous attempt was discarded by
    the May 24 checkpoint commits and the surrounding code had no replacement.
  - Behavior is read-only; no callers were migrated.
- Reintroduced `app/services/return_target_token.rb` using
  `Rails.application.message_verifier(:return_target)`.
  - Why: matches the existing pattern from `app/services/oidc/logout_request.rb`. The plan's
    `key_generator.generate_key("return_target_token", 32)` recipe is functionally equivalent.
  - The service rejects absolute, protocol-relative, userinfo-bearing, and control-character paths
    at issue time, applying the same constraints as `Common::Redirect#safe_internal_path` without
    requiring a controller instance.
  - `Redirect::ReturnUrl.resolve` referenced by the original plan does not exist in this tree; the
    inline path validator above replaces it for now and stays consistent with controller behavior.
- Added `verified_return_to` as a non-raising convenience wrapper so callers can verify signed
  return targets without rescuing.

### Step-up bootstrap acceptance

- `Verification::Base#bootstrap_return_path` now tries `ReturnTargetToken.verified_return_to`.
  - Surface is inferred from the including controller class name (`/::App::/`, `/::Com::/`,
    `/::Org::/`). Flow is the literal `"step_up.bootstrap"`. Session nonce comes from
    `current_session_token&.public_id`.
  - Why: ADR's signed `rt` contract requires per-surface and per-session binding. Inferring surface
    from class avoids touching every concrete controller in this commit.
- Legacy Base64 fallback described in the original note is no longer approved guidance. Per
  `adr/signed-return-targets-only.md`, touched `rt` flows must use signed `ReturnTargetToken`
  issuance/verification and should delete `safe_path_from_encoded_rt` usage.

## Deviations From Plan

- Plan calls for `ReturnTargetToken` to delegate destination validation to
  `Redirect::ReturnUrl.resolve`.
  - Change: inline the same logic as `Common::Redirect#safe_internal_path`.
  - Why: `Redirect::ReturnUrl` does not exist in the current tree; introducing it is out of scope.
  - Risk: the service's view of "safe path" must stay in lockstep with `Common::Redirect`. The
    duplicated rules cover: blank rejection, control-character rejection, scheme/host rejection,
    userinfo rejection, leading-`/` requirement.
- Plan calls for issuing signed `rt` from existing call sites (verification/base
  `encoded_step_up_rt`, authentication redirects, etc.).
  - Change: not done in this commit.
  - Why: out of scope for the foundation pass. Verification side is now ready to accept signed
    tokens once issuers move.

## Files Touched

- `app/services/request_context/contract.rb` (new)
- `app/services/return_target_token.rb` (new)
- `app/controllers/concerns/verification/base.rb` — `bootstrap_return_path` moved toward signed
  return-target verification. Any legacy Base64 fallback mentioned by this historical note is stale
  and should be removed when encountered.
- `app/controllers/sign/{app,com,org}/verification/setups_controller.rb` — fixed `params(:rt)` →
  `params[:rt]` typo (would 500 at runtime).
- `test/services/request_context/contract_test.rb` (new)
- `test/services/return_target_token_test.rb` (new)
- `test/controllers/concerns/verification/base_bootstrap_return_path_test.rb` (new)

## Review Notes

- Tests run:
  - `ruby -c` on all modified/added Ruby files (syntax pass).
  - `bin/rails runner` round-trip: issue → verify happy path, surface mismatch, session nonce
    mismatch, tampered token, expired token, absolute URL rejection at issue time.
  - `bin/rails runner` end-to-end through `Verification::Base#bootstrap_return_path` using a harness
    in the `Sign::App` namespace: accepts signed token, rejects wrong-surface signed token, and
    returns default on garbage or blank input. Historical legacy Base64 acceptance is not current
    guidance.
- Tests not run:
  - `bin/rails test` on the new Minitest files — blocked by the 791-pending-migration gate. The test
    files are syntactically valid and should run once the migration backlog is resolved.
- Documentation or ADR promotion needed:
  - None for this note. Behavior belongs in the existing canonical plans and the predecessor ADRs .

## Follow-Up

- Migrate `encoded_step_up_rt`, `encoded_relative_return_to`, `safe_path_from_encoded_rt`, and other
  Base64 `rt` issuers/consumers under `app/controllers/concerns/authentication/*` and
  `app/controllers/concerns/sign/*` to `ReturnTargetToken.issue` / signed verification.
- Reject invalid signed tokens instead of falling back to Base64.
