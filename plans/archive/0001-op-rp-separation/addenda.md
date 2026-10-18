# OP/RP Separation — Formal Supplements

> Archived snapshot, generation 0001 (originally `four.md`). Non-normative and not evidence; see
> [README](./README.md).

Status: **initial registration structure; no addenda approved or registered**.

## Control Rules

[one.md](./implementation-plan.md) is the implementation baseline and
[two.md](./acceptance-definitions.md) the acceptance baseline. This file registers later changes
with unique IDs and explicit approval. Current confirmed requirements are integrated into those
baselines, not deferred into this file. [three.md](./implementation-reports.md) records actual
implementation discoveries; [five.md](./notes.md) cannot establish a requirement.

IDs are `ADD-ONE-0001` or `ADD-TWO-0001`, monotonic and never reused. Each proposal states its
target existing section/unit/Gate and exactly what is added, replaced or retired. Approval is
PROPOSED / APPROVED / REJECTED / SUPERSEDED, with actual user decision source/date. Only APPROVED,
unsuperseded scope is normative. Record updates as dated history; preserve original proposals and
decisions.

A conflict with a confirmed specification/Accepted ADR is reported to the user, with affected work
stopped until resolved. An addendum never silently wins merely because it is newer or located here.
Approved replacement names the precise displaced clause and successor; maintain a clear effective
register rather than a chain readers must merge by guesswork. A new contradiction discovered later
is reported even if both entries appear APPROVED.

Each implementation change records affected Work Units, direct dependency updates, corresponding
Acceptance Gates/cases and whether a Two Addendum is needed. Each acceptance change records its
owning implementation unit/contract. No unit/case renumbering; new IDs extend the registry. Updating
traceability is an explicit action, not assumed to happen automatically through a link.

## One Addenda

This heading is the stable target of `one.md`'s `./four.md#one-addenda` link. Keep the
heading/anchor stable.

Register: **none**. There are no approved supplemental implementation requirements.

### One Addendum Template

```text
Addendum ID: <ADD-ONE-nnnn>
Added date: <UTC>
Target document: one
Release / Work Unit / Gate / Cell: <explicit IDs and scope>
Target section / clause: <baseline reference>
Change type: <add / replace / retire>
Content: <precise technical requirement or Work Unit>
Reason: <new fact or actual approved decision>
Dependencies: <units, approvals, other addenda; explicit none if none>
Displaced clause / conflict assessment: <exact reference and effect>
Security / data / compatibility / recovery impact: <explicit>
Traceability updates required: <Work Units / DAG / Gates / cases>
Acceptance counterpart: <ADD-TWO ID or pending authoring requirement>
Approval state: <PROPOSED / APPROVED / REJECTED / SUPERSEDED>
Actual approver / decision source / approval date: <reference or none>
Related Report ID: <REP ID or none; no invented report>
Effective applicability: <release/cell/revision condition>
Supersession history: <exact predecessor/successor, or none>
```

## Two Addenda

This heading is the stable target of `two.md`'s `./four.md#two-addenda` link. Keep the
heading/anchor stable.

Register: **none**. There are no approved supplemental acceptance criteria.

### Two Addendum Template

```text
Addendum ID: <ADD-TWO-nnnn>
Added date: <UTC>
Target document: two
Release / Work Unit / Gate / Case / Cell: <explicit IDs and scope>
Target section / clause: <baseline reference>
Change type: <add / replace / retire>
Content: <acceptance condition, case, fault/recovery or evidence requirement>
Reason: <new fact or actual approved decision>
Dependencies: <units, approvals, environment, other addenda>
Implementation contract: <one section / ADD-ONE ID>
Displaced clause / conflict assessment: <exact reference and effect>
Traceability updates required: <Gate / case / unit / evidence mapping>
Approval state: <PROPOSED / APPROVED / REJECTED / SUPERSEDED>
Actual approver / decision source / approval date: <reference or none>
Related Report ID: <REP ID or none>
Execution result: <NOT_RUN until actual execution; evidence/status separately>
Effective applicability: <release/cell/revision condition>
Supersession history: <exact predecessor/successor, or none>
```

## Registration and Review Checklist

Confirm unique ID, date, target document/scope, exact content/reason, dependencies, actual approval
source, Report ID or explicit none, conflict handling, traceability updates and evidence impact. An
approval never implies that implementation or verification happened. Data-shape approval, actual
DB-operation approval and external-owner authorization remain distinct where required by the
implementation contract.
