# Specs

Accepted change specifications, one directory per change. Vitest tests live in `gait/`.

## Proportional documents

Small, obvious changes need no spec. Use one for significant authentication, authorization, session,
credential, persistent-data, privacy, audit, financial or trust-boundary changes, and changes too
large to carry safely in one conversation. A typo in those areas does not require a new ceremony.

`spec.md` records WHAT, WHY, scope and acceptance. Add `plan.md` for a non-trivial HOW and `tasks.md`
when ordered execution units help coordination; a short implementation can keep those sections in
`spec.md`. Optional `research.md`, `contracts/` and `checklists/` carry change-specific material.
Research remains non-normative even inside an accepted spec.

## Authority and lifecycle

An open spec is normative for its accepted change. It does not silently override an ADR or durable
checklist. Surface disagreements; distinguish observed implementation from intended behavior.
See [knowledge architecture](../docs/reference/repository-knowledge-architecture.md).

Research and backlog are optional preparation, not mandatory stages. Record `Status:` near the top:

- `accepted`: scope and acceptance authorized by the user or responsible owner.
- `implementing`: authorized work is underway.
- `verified`: acceptance has evidence for a stated revision, environment and scope.
- `closed`: evidence disposition and durable documentation promotion are complete.
- `cancelled` or `superseded`: stopped with a reason and a replacement link when applicable.

A blocker is recorded separately; it does not imply a new lifecycle state. Approval carries forward
within scope. Obtain a new decision only when scope, risk or an explicit gate requires it. Verified
means the stated checks passed, not that a change was deployed. Material unverified acceptance keeps
that scope open; excluded checks are stated explicitly.

## IDs and traceability

Use stable local IDs (`AC-1`, `AC-2`) and qualify them by spec path outside the document.
Write definitions as `- AC-1: ...`; reference IDs in prose or code spans elsewhere. Keep IDs
stable rather than renumbering them after removal. Introduce separate requirement IDs only when
many criteria genuinely map to the same requirement. There is no global requirement register.

For high-risk changes, retain a compact acceptance-to-test-to-evidence mapping with each criterion's
disposition. Use existing test names and paths; do not duplicate assertions into a traceability
system. A test being named is not evidence that it passed.

## Closure

Promote lasting behavior into `docs/checklists/`, current explanation into `docs/`, and accepted
architectural decisions into `adr/`. Keep change-only acceptance in the spec. Closed specs preserve
the meaning of the completed change; they are not maintained as current system documentation.
Typo and link corrections are allowed. Explain substantive errata explicitly without rewriting the
original outcome. A new behavior contract belongs in a new spec linked to the predecessor.
Evidence is a historical observation; correct it through a new record referencing the original.

## Legacy entry points

Four inherited changes have `plan.md` and an accepted ADR instead of a reconstructed `spec.md`:

- [OTP disclosure remediation](otp-observability-secret-exposure-remediation/plan.md)
- [Directed Jump rollout](rails-jump-directed-handoff-rollout/plan.md)
- [Realm-separated identifiers](realm-separated-identifiers-and-dead-history/plan.md)
- [Sign FQDN integration](sign-fqdn-integrated-plan/plan.md)

Preserve their recorded scope, gates and progress. Normalize each when its owner next resumes the
change; their presence is not evidence of implementation or verification.

The [Base/app Secret/Core acceptance catalog](base-secret-core-contract/checklists/acceptance.md)
was relocated from research because an accepted ADR already assigns it change-specific acceptance
responsibility. Its original IDs and result semantics remain; no progress or new approval is inferred.
