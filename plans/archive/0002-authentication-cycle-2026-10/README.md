# Authentication Cycle 2026-10 — Cycle Archive

- Generation: 0002
- Period: 2026-10-19 to 2026-10-27 (approximate; the generation number is the ordering key)
- Outcome: accepted by the owner on 2026-10-27 at the request/test level. Visa became the OIDC OP for
  APP/COM/ORG (WU-02), the sign-in path moved to Design D, sign-up was unified under Sign In First,
  Sign Entry Sentry, the authority-stop primitive and the sign-out redesign (`ten.md`) were
  implemented. Acceptance at closure: 143 Passed, 136 Not run, 7 moved to pre-deployment checks,
  3 deferred, 4 closed; no Failed, Blocked, Unverified, Partial or Deviation case.

## What this archive is

A frozen snapshot of the working documents of one implementation cycle, kept as a clue to why the
implementation took its current shape. It is not normative, not evidence and not maintained. Code,
ADRs, `docs/` and `docs/checklists/` always take precedence. It may be deleted at any time; git
history is then the only copy, so nothing that must keep holding depends on it.

What must keep holding from this cycle lives elsewhere:

- Deferred and open work: the next cycle's requirements (`nine.md`, BL-11 … BL-23, gitignored working
  file) and `docs/backlog/2026-10-2*-*.md`, in particular
  [pre-deployment checks](../../../docs/backlog/2026-10-26-pre-deployment-checks.md) and
  [back-channel logout in development](../../../docs/backlog/2026-10-27-backchannel-logout-unverifiable-in-development.md).
- Decisions with lasting effect: the ADRs amended in this cycle, among them
  [sign-in path continuation protocol](../../../adr/sign-in-path-continuation-protocol.md),
  [sign-up finalization in Auth](../../../adr/sign-up-finalization-in-auth.md),
  [OIDC authorization request profile](../../../adr/oidc-authorization-request-profile.md),
  [RP OIDC state and return target](../../../adr/rp-oidc-state-and-return-target.md) and
  [first-party sign-out](../../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md).
- Observations: `evidence/2026-10-19-*` to `evidence/2026-10-27-*`.

Not archived here: `zero.md`, `nine.md`, `eleven.md` and `twelve.md` stay at the repository root
(owner, 2026-10-27); `nine.md`, `eleven.md` and `twelve.md` belong to the next cycle.

## Original file names

Other repository files, evidence in particular, refer to these documents by their working names.
Those references are not rewritten; use this table.

| Working name | Archived name |
| --- | --- |
| `one.md` | [requirements-and-decisions.md](requirements-and-decisions.md) |
| `two.md` | [work-unit-definitions.md](work-unit-definitions.md) |
| `three.md` | [acceptance-cases.md](acceptance-cases.md) |
| `four.md` | [critical-review.md](critical-review.md) |
| `five.md` | [admission-protocol-review.md](admission-protocol-review.md) |
| `six.md` | [critical-review-disposition.md](critical-review-disposition.md) |
| `seven.md` | [acceptance-reconciliation.md](acceptance-reconciliation.md) |
| `eight.md` | [gap-case-test-instructions.md](gap-case-test-instructions.md) |
| `ten.md` | [sign-out-redesign.md](sign-out-redesign.md) |
