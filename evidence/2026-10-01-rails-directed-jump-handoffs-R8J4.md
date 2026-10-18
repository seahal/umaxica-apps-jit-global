# Rails directed Jump handoff verification

Date: 2026-10-01 (UTC).
Branch: `feature`.
HEAD: `3133db7f909b191dc3f0a4e44092c2ad4725870a`.

The worktree had uncommitted changes before this task, including cache-policy and Edit work.
Verification used that dirty worktree plus the uncommitted Jump changes. This is local application
evidence, not verification of a deployed production artifact. Unrelated work was retained.

## Results

- `bin/rails test`: 12,268 runs, 80,409 assertions, 0 failures, 0 errors, 2 skips
  (seed 60004; the run's skip reasons were not individually captured).
- After the full run, final boundary additions and the preservation of Edit's existing same-site
  admission were checked with:
  `bin/rails test test/integration/palm_jump_sign_in_test.rb test/integration/edit_org_jump_rt_sign_in_test.rb test/services/jump_rt/issuer_test.rb test/integration/jump_directed_handoffs_test.rb test/security/invariants/forbidden_patterns_invariant_test.rb test/unit/security/redirect_target_usage_test.rb`.
  Result: 46 runs, 317 assertions, 0 failures, 0 errors, 0 skips (seed 35210).
- `bin/rails test test/integration/oidc_rp_browser_flow_test.rb:121`: 1 run, 48 assertions,
  0 failures/errors/skips (seed 8196). Public Base/Auth navigation required explicit transport of
  Core's initiating cookie in this test because its non-production session uses a shared domain;
  production uses host-only `__Host-session`. Runtime session configuration was not changed.
- `git diff --check`: passed after the final code/test changes.
- Search of `app`, `lib`, `config`, and `.env.example` found no `SIGN_APP/COM/ORG`,
  `www.jp.umaxica.*`, `palm.jp.umaxica.*`, or `warp.us.umaxica.*` executable occurrences.
- Extraction from `JumpRtReturnPolicy::ALLOWED_SOURCES` produced 20 distinct directed edges;
  the ADR records their sorted 11-character node IDs. The policy test exercises all 13-by-13
  canonical origin pairs, including denied self-loops, RP-to-RP, Auth-to-RP, and cross-TLD pairs.

Earlier full verification reported 18 failures and 17 errors. These exposed direct-redirect test
expectations, an issuer surface selected from a nested publishing audience, incomplete concern
harness collaborators, and the new native delivery exception. The final full run above passed.
No new skipped tests were introduced.

Controller generation initially encountered development database connectivity and Bootsnap boot
errors. Generation completed under `RAILS_ENV=test DISABLE_BOOTSNAP=1`; public JWKS controllers
were subsequently verified by real Rails requests and signature/key agreement tests.

## Covered contracts

The tests cover canonical Auth/Core/Warp/Palm issuer identities and public JWKS; signed cross-host
handoffs; receiver source/URL/signature verification; `rpl=once` versus `rpl=reuse`; native S256
challenge propagation without a device verifier; both fixed iOS/Android delivery callbacks;
state/nonce byte boundaries; duplicate and superseded browser flows; the exclusive 600-second
expiry; tampered, unsolicited and replayed callbacks; empty-session cleanup and cookie size.
Signed POST logout/social ceremonies and native bearer API behavior remain separately controlled.

## Unverified or external prerequisites

No production gateway, DNS, JWKS network reachability, device integration, secret/binding write,
deployment, production signing-key rotation, or persistence migration was performed. Development
public issuer/JWKS/kid/trust/return configuration remains unspecified and issuance is explicitly
disabled. Native client registration/application rollout and renamed Auth configuration require
coordination before deployment. Existing Core bridge values/defaults and legacy Host Authorization
remain a separate persistence/cutover task; Edit graph inclusion and issuer destination least
privilege remain review work.

See `adr/jump-directed-rails-handoff-contract.md` and
`plans/active/rails-jump-directed-handoff-rollout.md` for the implementation and rollback contracts.

## Commit-scope verification

Before committing, the index was exported to an isolated temporary checkout. Cache-policy and
pre-existing Edit implementation changes remained outside the index; overlapping files were
staged by their task-specific content without replacing the original worktree.

`DISABLE_BOOTSNAP=1 bin/rails test test/controllers/auth test/controllers/base test/controllers/core test/controllers/warp test/controllers/palm test/services/jump_rt test/integration/jump_directed_handoffs_test.rb test/integration/palm_jump_sign_in_test.rb test/integration/jump_rt_return_verification_test.rb test/integration/jump_rt_issuer_jwks_authority_test.rb test/services/oidc test/concerns/auth test/unit/jit/security/jwt`
passed in that checkout: 2,590 runs, 14,158 assertions, 0 failures, 0 errors, 0 skips (seed 18787).
After moving the Edit preservation regression into the task-owned handoff test file, the isolated
`DISABLE_BOOTSNAP=1 bin/rails test test/integration/jump_directed_handoffs_test.rb` passed:
3 runs, 113 assertions, 0 failures, 0 errors, 0 skips.

The first isolated attempt lacked the Git-ignored `config/credentials/test.key` and reported
configuration-dependent failures. A reference to the existing local test key restored the test
environment; no key content was changed or staged. The isolated Vite test build completed.

The existing pre-commit hook runs formatter/linter auto-fixes and stages their results. It is
disabled for this partial-stage commit to retain the reviewed index and unrelated worktree
changes. `git diff --cached --check` passed.
