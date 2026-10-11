# Local restoration of prescribed Skill adapters

HEAD: `3a47c5634b834362d7c4938df3778e1db028cdc8`. Shared generator/application/test changes and
unrelated source-policy work remain uncommitted. Rails Gate 2 was running; no application feature or
test change was made during this repair.

Read-only filesystem/Git inspection found `.claude` and `.claude/skills` absent, with no tracked
adapter entries and no sparse-checkout setting. The eight checker errors were missing paths, not
eight observed malformed links. Canonical `.agents/skills` bodies were present. The existing
accepted agent-harness ADR, runtime-compatibility document and exact gitignore exceptions prescribe
eight individual relative symlinks. This is repository agent-runtime discovery ownership; no
external runtime configuration or unidentified existing adapter needed replacement.

The bounded local repair created only `.claude/skills` and these previously absent links:
browser-testing-with-devtools, code-review-and-quality, deprecation-and-migration,
frontend-ui-engineering, observability-and-instrumentation, security-and-hardening,
shipping-and-launch, spec-driven-development. Each target is exactly `../../.agents/skills/<name>`
and resolves to its existing SKILL.md. The operation checked absence before creation, overwrote
nothing and wrote no canonical Skill body, settings, checker, permission or hook. No read-only
protection was bypassed. Environment construction was verified directly, not by adding
Minitest/Vitest setup tests.

`ruby -rpathname scripts/check-repository-knowledge .agents/harnesses/rules/project/identifiers.mdc docs/reference/identifier-conventions.md docs/checklists/identifier-contracts.md AGENTS.md`
now exits 0: 8 Skills/adapters, 68 documents, 0 evidence records in that invocation. Earlier
documented exit-1 results remain historical facts; this repair does not retrospectively make them
PASS. It removes this local checker execution blocker, not remaining implementation/acceptance gaps
or the pending full Rails gate.

The eight adapters remain untracked local discovery artifacts and are not included in the
documentation-only commit. That commit does not snapshot the full application or test environment.
No CI pipeline, dependency/framework, production resource or external service was invoked or
changed. Nothing was pushed.
