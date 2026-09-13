# Cloudflare Private Origin Implementation Notes

## Context

- Original plan: `plans/you-are-working-in-enchanted-sunbeam.md`
- Related decisions: `adr/public-private-url-boundaries.md`,
  `adr/internal-health-endpoint-edge-isolation.md`, and
  `adr/org-cloudflare-access-authentication-layer.md`
- Implementation date: 2026-07-13

## Decisions Made During Implementation

- Gate 1 uses a pinned ephemeral curl container attached to the running cloudflared container's
  actual compose-labeled `frontend` network.
  - Why: the connector image is not an application debugging environment and must not gain a shell,
    curl, or wget dependency.
- Gate 2 boots Rails development configuration in a separate process and drives
  `ActionDispatch::HostAuthorization` on `/`.
  - Why: the normal Rails test command boots the test environment, where Host Authorization is not
    active. Loading development configuration into the already-booted test application would mutate
    global configuration and would not prove a clean development boot.
- Gate 3 recognizes non-health paths separately from the transport probe.
  - Why: production excludes `/health` from Host Authorization, and a health response cannot prove
    middleware or general surface-route acceptance.

## Deviations From Plan

- Replaced `podman compose exec cloudflare-tunnel wget` with an ephemeral pinned probe container.
  - Why: mandatory implementation correction; cloudflared image contents are not part of the probe
    contract.
  - Risk: the probe image must be pulled once before an offline verification run.
- Removed source-text hostname assertions as the primary Host Authorization test.
  - Why: mandatory implementation correction; effective middleware behavior is the acceptance
    contract.
  - Risk: the behavioral test is slower because it boots an isolated Rails development process.
- Retained source checks only for catastrophic broad bypasses such as `config.hosts.clear` or a
  universal regular-expression append.
  - Why: this is a supplementary security ratchet, not acceptance evidence.

## Review Notes

- Host Authorization contract: 2 runs, 19 assertions, 0 failures, 0 errors.
- Route contracts: the Rails test files were blocked before execution because
  `test_com_principal_db` is missing; an isolated development Rails process recognized all 11 new
  non-health contracts with the expected controllers and actions.
- Full-suite baseline and final run: blocked before test execution because `test_com_principal_db`
  is missing.
- Coverage: the database boot error stopped the run; the emitted partial report is not valid Gate 6
  coverage evidence.
- Runtime Podman checks: unavailable because the implementation environment has no `podman` binary.
- Static verification: shell syntax, compose YAML/contract assertions, RuboCop on changed Ruby
  files, and `git diff --check` passed.
- Documentation promotion: stable operational behavior is recorded in
  `docs/operations/cloudflare-private-origin.md`.
