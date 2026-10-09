# Repository knowledge architecture

## Ownership

| Location | Purpose and audience | Authority and maintenance | Lifecycle |
| --- | --- | --- | --- |
| `.agents/` | Operating guidance for agents and maintainers | Repository constraints and selected workflows; maintained with affected tooling | Replace obsolete guidance; vendor adapters point here |
| `research/` | Institutional memory for builders | Non-normative; no general maintenance obligation; revalidate facts before use | May be corrected, reorganized or deleted; preserve useful failures and rejected alternatives |
| `plans/backlog/` | Unaccepted proposals for decision makers | Consideration only; reassess when selected | Accepted changes move to specs; useful history may enter archive |
| `plans/archive/` | Historical proposals | Non-normative; no current-state maintenance | Retain only useful provenance |
| `specs/` | Accepted changes for implementers and reviewers | Normative within each open change; maintain through closure | Freeze meaning at close; successor changes link back |
| `adr/` | Accepted decisions and rationale for builders | Normative until explicitly superseded | Keep decision history and explicit supersession |
| `evidence/` | Actual observations for reviewers and operators | Historical, revision-scoped facts; not a plan or current guarantee | Append correction records; preserve originals |
| `docs/` | Current explanation for programmers, operators and agents | Maintain when affected implementation changes | Reference decisions and promote delivered explanations here |
| `docs/checklists/` | Durable behavior for implementers and reviewers | Maintain intentional contract changes with code | Promote lasting acceptance, not every one-time criterion |
| `manuals/` | Product guidance for users and authors | Draft or reviewed prose; presence does not mean published | Review affected guidance; publish only through a separate product action |
| `test/`, `gait/`, `e2e/` | Executable Minitest, Vitest, Playwright checks | Tests describe expected behavior; results require execution | Maintain with behavior changes |

`gait` is a repository-specific proper name for the Vitest test location. `spec/` is retired.
There is no top-level governance, risks or controls directory, and no `plans/active/` or
`plans/analysis/`. Risk management lives under `docs/risk-management/` when a real risk needs it.

## Facts and contracts

Code and observed execution establish what currently happens. Accepted ADRs, open change specs and
durable checklists establish what should happen within their scopes. Neither axis silently wins:
a code defect does not supersede a contract, and a desired contract does not prove implementation.
Report the concrete conflict and obtain a scope decision if the authorized task does not settle it.
Current user instructions guide this task; changes to lasting contracts are recorded in their
owning artifacts. Historical material supplies context, not executable instructions.

## Agent layers

`AGENTS.md` is the shared entry point and sole harness router. `.mdc` files under
`.agents/harnesses/rules/` are explicitly selected Markdown guidance, not native runtime policy.
`CLAUDE.md` imports the entry point. Shared Skills live in `.agents/skills/`; individual Claude
symlinks supply discovery without copying bodies. Runtime permissions and sandbox configuration
remain vendor-specific and are not granted by prose, Skill metadata or symlinks.

Instructions explain decisions and constraints. A Skill supplies a procedure worth loading for a
specific task. Scripts and CI enforce objective structural properties. Hooks are optional event
adapters only when the event, failure behavior and runtime trust have been verified; asynchronous
post-edit commands cannot be used as a correctness gate.

Subagents need explicit task scope, relevant boundaries and ownership. Delegate independent,
substantial investigations when authorized and worthwhile; avoid universal second-review agents.
For parallel writes, assign disjoint files and serialize shared-file edits. Never assume every
runtime propagates the parent transcript, imported instructions or invoked Skills.

## Navigation and records

Link to canonical content instead of copying its requirements. Use file-relative Markdown links.
Preserve old paths inside historical evidence; annotate history only through a new record. A
current navigation link must resolve or explicitly identify an unavailable historical source.
Do not invent deleted requirements from a broken reference.

See [spec lifecycle](../../specs/README.md), [runtime compatibility](agent-runtime-compatibility.md),
[checklists](../checklists/README.md) and [risk management](../risk-management/README.md).
