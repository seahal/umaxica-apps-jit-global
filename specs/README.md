# Specs

One directory per accepted change that warrants a written specification.

```text
specs/<feature>/
├── spec.md        WHAT and WHY, with acceptance criteria
├── plan.md        HOW
├── tasks.md       execution units
├── research.md    optional: investigation specific to this change
├── contracts/     optional: interface or schema contracts
└── checklists/    optional
```

## When a spec is required

Small, obvious changes need none. Write one when the change touches authentication, authorization,
session or credential handling, persistent data or migrations, privacy, audit records, money, or a
trust boundary between surfaces, or when it is too large to hold in one conversation.

## Standing

- A spec is normative for its change while that change is in progress.
- A spec describes a change, not the system. Once the change is implemented and verified, the
  current behavior is described in `docs/`, and the spec is closed and left as written. Do not keep
  a closed spec up to date; `docs/` is the single description of the current system.
- A spec does not override an accepted ADR. A conflict between them is raised, not resolved
  silently.

## Lifecycle

`research/` → `plans/backlog/` → accepted → `specs/<feature>/` → implementation and tests →
`evidence/` → `docs/` and `docs/checklists/` updated → closed.

State the status at the top of `spec.md`: `accepted`, `implementing`, `verified` or `closed`.

Number acceptance criteria within the spec (`AC-1`, `AC-2`, …) so tests and evidence can name them.
There is no repository-wide requirement register.

## Changes carried over from `plans/active/`

Four directories hold only a `plan.md`. They were open implementation plans under the former
`plans/active/`, each tied to an accepted ADR that states the what and why. They are kept as plans
rather than given a reconstructed `spec.md`; a new change starts with `spec.md`.

Vitest tests live in `gait/`, not here.
