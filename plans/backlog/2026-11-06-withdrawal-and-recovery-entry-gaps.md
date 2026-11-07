# Withdrawal, Early Erasure and Recovery: Unreachable or Unfinished Base APP Pages

Date: 2026-11-06

Status: Backlog. The owner deferred this on 2026-11-06 because the withdrawal flow is still largely
unimplemented. Found during a review of Base identity routes against identity hub links (source
reading only; nothing was run). Related earlier items:
`2026-10-19-withdrawal-avatar-preparation-and-restoration.md`,
`2026-10-19-withdrawal-final-deletion-and-retention.md`,
`2026-10-19-withdrawal-termination-assurance.md`.

## Findings

1. Early personal data erasure status (`GET /identity/privacy/erasure/status`,
   `Base::App::Identity::Privacy::Erasure::StatusesController`) has no inbound link or redirect.
   The request page (`GET /identity/privacy/erasure/new`) is reached only from the withdrawal edit
   page (`erasure_link` in `Base::App::Identity::WithdrawalsController`), and its `create` always
   answers `render_privacy_erasure_forbidden`. No path reaches the status page.
2. The withdrawal page's erasure link label is a hard-coded English string ("Request early personal
   data erasure", `withdrawals_controller.rb`), not a translation key.
3. Recovery (`GET /identity/recovery`) is not linked from the identity hub. It is reached through the
   recovery session flow (`/identity/recovery/session/new`, `EnforcementRecoveryCeremonyFlow`) used
   by restricted or withdrawing accounts. This appears intentional; confirm when the withdrawal and
   recovery entry design is settled.

## To decide when resumed

- The intended withdrawal, early erasure and recovery journey end to end, including which page each
  state lands on and how the user returns.
- Whether early erasure is offered at all before final deletion, and the status page's entry.
- Whether the hub should show a recovery entry for affected accounts only.
