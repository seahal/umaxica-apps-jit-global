# Umaxica Apps Global — Agent Instructions

Ruby on Rails application (not the Rails framework monorepo). This file holds only guidance that
applies repository-wide and cannot be derived from the code. Detailed rules live under
`.agents/harnesses/rules/` and are loaded per task via the index below; each rule is canonical
within its area. Read the applicable rules before editing.

## Scope and Authorization

- Answer / explain / review / diagnose / plan requests: inspect and report; change nothing.
- Change / build / fix requests: make the in-scope local change and run non-destructive verification
  without asking.
- Ask first before destructive or irreversible actions, external writes, purchases, material scope
  expansion, or anything needing information only the user can provide.
- Preserve unrelated staged, unstaged, and untracked changes. Never reset or clean the worktree.

## Application Boundaries

Three independent user-facing trust boundaries:

- `app` — end-user application
- `org` — staff and organization surface
- `com` — public and corporate surface

Keep each surface's controllers, routes, views, policies, sessions, and state separate unless
current code provides an explicit shared abstraction. Cross-surface leakage is a security defect.
Read `.agents/harnesses/rules/project/surfaces.mdc` for any surface-related work.

## Task Rule Index

Rule paths are relative to `.agents/harnesses/rules/`; documentation paths are relative to the
repository root. Load only the entries matching the task.

- Controllers or endpoints: `generic/controllers.mdc`, `generic/routing.mdc`,
  `project/surfaces.mdc`, `project/controller-inheritance.mdc`,
  `docs/architecture/controller-lifecycle.md`
- JSON API endpoints, error responses, or API versioning: `docs/reference/api-design-standards.md`
- Minitest or behavior changes: `generic/testing.mdc`, `generic/no-test-only-code.mdc`
- Adding any class outside `app/models` and `app/controllers` — values, results, services,
  operations, resolvers, policies, queries, forms, presenters, serializers, or adapters:
  `project/value-object-boundaries.mdc`
- Migrations: `generic/migrations.mdc`
- Persistent data or API shape (JSON and database schemas): `generic/data-shape-design.mdc`
- Security-sensitive work or broad refactors: `generic/absolute-rules.mdc`,
  `generic/no-silent-fallback.mdc`, `project/regression-guards.mdc`
- Configuration or environment variables: `generic/no-silent-fallback.mdc`
- Compose files, container ports, or devcontainer configuration:
  `docs/operations/development-host-port-exposure.md`
- Routing or authentication workflows: `project/surfaces.mdc`, `generic/routing.mdc`,
  `generic/no-workflow-drift.mdc`, `docs/architecture/controller-lifecycle.md`
- User-facing notices, alerts, or feedback: `generic/no-flash-messages.mdc`
- Google or Apple sign-in buttons and provider branding:
  `docs/reference/third-party-sign-in-button-requirements.md`
- External technical sources: `generic/source-policy.mdc`
- Documentation, ADRs, plans, notes, memos, harnesses, comments, or test names:
  `generic/repository-language.mdc`
- Logging, audit records, telemetry, or analytics: `adr/application-logging-boundary.md`,
  `docs/security/observability-boundary.md`
- Concerns, method visibility, or `included do` hooks: `generic/rails-concerns.mdc`,
  `docs/architecture/method-visibility-and-concerns.md`
- Non-trivial decisions, plan deviations, or handoff context: `generic/implementation-notes.mdc`,
  `project/repository-knowledge-tree.mdc`

For non-trivial architecture, routing, authentication, authorization, database, preference, surface,
or service-layer work, use `project/repository-knowledge-tree.mdc` to load and prioritize material
under `memos/`, `notes/`, `adr/`, `plans/`, and `docs/`. Call out conflicts between current code and
an accepted ADR before choosing an implementation path.

## Non-Negotiable Boundaries

Do not:

- mix the `app`, `org`, and `com` surfaces
- skip or reorder authentication, authorization, verification, CSRF, or rate-limit protections
- put business logic in controllers; use a service, query, policy, or value object
- use `permit!`, `skip_before_action`, `skip_authorization`, `skip_forgery_protection`, `html_safe`,
  `raw(...)`, `VERIFY_NONE`, `rescue nil`, or ignored rescues
- use Rails flash; render feedback inline in the response
- log tokens, cookies, authorization headers, full request parameters, or secrets; log identifiers
  and outcomes instead
- use application logs as the authoritative record for audit, security, compliance, or purchase
  events; persist those events as data
- store request state in class variables, globals, or `Thread.current`; pass it explicitly
- introduce test-only behavior into application code; change the test instead
- use silent configuration, workflow, or migration fallbacks; fail loudly and name what is missing
- add `included do` / `prepended do` hooks, or leave a method's visibility to Ruby's implicit public
  default
- publish a container port to the host without an explicit loopback bind address, or publish a
  datastore port (PostgreSQL, Valkey) to the host at all
- perform destructive database operations without explicit approval of the risk and migration plan

Required Ruby environment variables must use one-argument `ENV.fetch("NAME")` in application and
configuration code so missing configuration fails at boot.

## Working Style

- YAGNI: build only what is needed now. No speculative abstractions, unrelated cleanup, or support
  for hypothetical requirements.
- Make the smallest coherent change; prefer direct edits over compatibility shims unless safe
  deployment requires compatibility.
- Prefer established, well-maintained libraries over custom implementations when practical.
- Comments explain why a non-obvious implementation is necessary; update comments a change makes
  stale. Commit messages explain why.

## Repository Content

Write repository prose in English except explicit localization content, translation fixtures,
non-English customer copy, or necessary quotations. Conversation language does not override this.
Follow `docs/reference/repository-language-policy.md`.

- `.agents/skills/` holds skills, each directory with a `SKILL.md` entrypoint.
- `.agents/harnesses/rules/` is the only harness directory; do not invent other harness locations.
- Keep task scope in the conversation; do not add `.agents/goals/` files.

## Verification and Reporting

```bash
bin/rails test                              # all Ruby tests (Minitest)
bin/rails test test/path/to/file_test.rb    # one file
bin/rails test test/path/to/file_test.rb:LINE
bun run test                                  # JavaScript tests (Vitest)
```

Meaningful behavior changes need risk-appropriate tests covering success, failure, authorization,
and boundary cases. No placeholder, skipped, TODO, or behavior-mocking tests. Run the narrowest
relevant checks first, then broaden only when the affected boundary warrants it.

Report only claims supported by results from the current session. State failed, skipped, blocked,
and unverified checks plainly. Lead with the outcome; keep responses proportional to the task. Do
not add a separate verifier pass; delegate only independent, substantial work whose parallel
execution outweighs re-establishing context.

## Evidence

Completed tests, validations, verifications, audits, security checks and performance checks leave a
short record in `evidence/` when retaining the result is useful. Records describe work that was
actually performed — never plans, intentions, or unverified claims. A check that could not be
completed is recorded as such, with the reason and whatever was observed.

- `evidence/` is flat; no subdirectories.
- Only `.md` files.
- `YYYY-MM-DD-<topic>.md`, ISO date, lowercase hyphenated topic.
- No raw logs, screenshots, binaries, archives, dumps, generated reports or other large artifacts.
  Summarize them, and cite the commands, identifiers, hashes, measurements and excerpts that carry
  the result.
- Enforced by `bin/rails test test/tooling/evidence_layout_test.rb`.

## Tool Compatibility

- Claude Code reads this file via `CLAUDE.md` (`@AGENTS.md` import) — keep that file as the import
  shim only.
- Codex and Grok read `AGENTS.md` natively; nested `AGENTS.md` files scope to their subtree and the
  closest file wins on conflict, so add nested files only for genuinely divergent rules.
- Keep this file concise: adherence drops as it grows (Anthropic recommends under 200 lines; Codex
  caps combined instructions at 32 KiB by default).
