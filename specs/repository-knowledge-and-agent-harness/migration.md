# Migration dispositions

Recorded against the checkpoint used for this change; no application behavior is changed.

| Previous location/material | Disposition and reason |
| --- | --- |
| `spec/` | Already renamed to `gait/`; Vitest, TypeScript, formatting and Knip use the new path. No repeat rename. |
| `notes/`, `memos/`, `plans/analysis/` | Already consolidated into research. No replacement analysis hierarchy. |
| `plans/active/` | Already moved to four plan-only specs. Preserve their ADRs, scope and recorded progress; do not fabricate acceptance. |
| OTP remediation plan | Accepted spec entry; remediation owner/security reviewer gate remains. No claim of production exposure or remediation. |
| Directed Jump rollout plan | Accepted Rails contract; external deployment prerequisites remain separate and unverified. |
| Realm-separated identifiers plan | Accepted contract with mixed progress; preserve concurrent implementation ownership. |
| Sign FQDN plan | Accepted plan with explicit missing historical inputs; preserve gate and retired IDs. |
| `plans/backlog/` | Unaccepted proposals; repair the OTP link and mark the unavailable step-up source explicitly. |
| `one.md` through `five.md` | User-designated temporary files; leave content, location and inbound references untouched. |
| `six.md`, `seven.md`, `conflict.md`, `misc.md`, `refactor.md` | Retain auth handoffs/ledgers with their active owners. A mixed ledger cannot safely be archived as one contract during concurrent work. Later split accepted work, backlog and useful history by content. |
| `DESIGN.md` | Move explicitly historical presentation content to research; update current design navigation. |
| `REACT.md` | Move reusable reference to docs and route explicitly; remove misleading automatic-rule frontmatter. |
| Contact auth research notes | Annotate former acceptance/terminology as historical; preserve useful context without promoting stale claims. |
| Base/app Secret/Core acceptance catalog | Move into the owning change's specs/checklists; accepted ADR already assigns its acceptance role. Preserve IDs and update current references. |
| SNS assessment links | Repair actual relative destinations; mark absent old paths as historical, without guessing replacements or claiming a fresh domain audit. |
| `evidence/` | Preserve old records and names. Add only observations from this implementation. |
| `CLAUDE.md` | Keep the explicit shared import. |
| Ignored vendor settings/hooks | Excluded local environment; no edits. Existing stale async hook needs its own local owner review. |
| Broken tracked `vite-plus` link | Remove unusable version-specific discovery link; no reinstall or dependency change. Ignored local Claude link remains outside shared validation. |

## Skill consolidation

Retain concise SDD, security, migration, launch, browser, frontend, observability and review workflows.
Merge planning, incremental execution, documentation/closure, public-behavior testing and adversarial
questions into their owning workflows and routed constraints. Remove the blanket skill router and
generic API, CI, simplification, debugging, Git, performance, source-research and context tutorials:
ordinary model capability plus repository rules owns these tasks. Idea-refinement/interview assets
and a mkdir-only helper do not earn always-discoverable repository metadata; remove them from this
shared layer rather than silently installing personal tools. Git history retains their old text.

No fixed Skill-count quota is a policy. Add a future Skill when repeated tasks demonstrate that its
specific procedure improves outcomes enough to justify discovery and maintenance cost.

## Remaining environmental limitation

The attempted CI edit failed with `Read-only file system`. `ci.patch` is the exact unapplied change;
apply it in a writable checkout and run actionlint/remote CI as a separately authorized operation.
The local checker is implemented and wired into `bin/ci`; it can be run without the remote job. Hosted Sol/Opus behavioral trials
and external deployment/issue inspection are excluded, not reported as passing.
