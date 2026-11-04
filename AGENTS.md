# Umaxica Apps Global — Agent Instructions

This is a production Ruby on Rails application, not the Rails framework monorepo. Changes serve real
users. `README.md` describes topology; its "Routing" section inventories user-facing surfaces. This
file is the shared entry point for Codex and Claude Code; `CLAUDE.md` imports it. Keep repository
rules shared and model-independent. Runtime permissions and model selection belong in tool settings.

## Working Agreement

- For explanation, review, diagnosis or planning, inspect and report without editing. For changes,
  complete the in-scope local work and non-destructive verification without additional approval.
- **MUST:** obtain explicit approval for destructive or irreversible actions, external writes,
  purchases, material scope expansion or decisions requiring information only the user can provide.
  Persistence operations such as bulk updates/deletes and irreversible migrations require risk and
  recovery-plan approval.
- Preserve unrelated staged, unstaged and untracked work. Keep the existing worktree intact.
- Communicate in the user's language. Lead with the outcome, explain concrete behavior and report
  evidence and limits. Use established terms and repository names; explain unfamiliar terms on first
  use. Do not invent jargon, acronyms or compound labels for an explanation. Describe a new concept
  before naming it, and distinguish a proposed name from an accepted one.
- Keep work proportional. Delegate only authorized, independent, substantial work when its benefit
  exceeds context overhead; do not add a separate verifier pass. Give each delegate the purpose,
  scope, constraints, acceptance, verification and unresolved issues. Do not assume inherited
  context.

## Principles and Boundaries

Security bounds our ability to create value. Within that boundary, performance, experience,
documentation, longevity and observability are coequal; list order is not priority. **MUST**,
**SHOULD** and **MAY** follow BCP 14; express requirements positively.

- **MUST:** treat each user-facing surface as an independent trust boundary. Preserve its
  controllers, routes, views, policies, sessions and state; sharing requires an explicit existing
  abstraction. Cross-surface leakage is a security defect. Apply `project/surfaces.mdc` through the
  index below.
- **MUST:** preserve ownership, authentication, authorization, verification, rate limits and
  security-relevant control order, including CSRF, XSS, SSRF and SQL-injection protections. Use
  parameterized access, contextual escaping and sanitization; keep untrusted data separate from
  executable content.
- **MUST:** protect people from foreseeable harm and prevent disclosure of credentials, tokens,
  cookies, authorization data and sensitive request data, including in diagnostics.
- **MUST:** keep orchestration, authorization, domain behavior, persistence and presentation with
  their owners. Keep request state explicit, outside class variables, globals and `Thread.current`.
- **MUST:** make invalid state, unsupported workflows, failed prerequisites and missing required
  configuration explicit and observable. Production must remain independent of test-only
  requirements.
- **MUST:** read required Ruby environment variables with one-argument `ENV.fetch("NAME")`; read
  optional variables with `ENV["NAME"]` and an explicit nil branch. Code-side defaults are defects.
- **MUST:** represent every persisted state explicitly with NOT NULL columns, status reference
  tables or enums. Boolean columns are NOT NULL. NULL must not encode a state, decision or third
  boolean value; code must not branch on whether a persisted column is NULL.
- **MUST:** preserve unchanged external contracts, persistent data, identity/security state and
  audit history. Persist authoritative audit, security, compliance and purchase events as records.
- **SHOULD:** make ownership, visibility, dependencies and failures explicit; implement the smallest
  coherent solution. Keep adjacent cleanup within authorized scope and abstractions proportional.
  Preserve replaceability. **MAY:** use bounded transitions needed for safe deployment or migration,
  recording exit conditions.
- **SHOULD:** let layout communicate meaning; keep secondary labels and explanations necessary. Code
  states how, tests what, commits why, and comments why not. Preserve non-obvious decisions in their
  owning documents and update affected current documentation; historical research needs no general
  upkeep.

## Task Rule Index

Resolve `generic/` and `project/` paths below against `.agents/harnesses/rules/`; all other paths
are repository-relative. This root `AGENTS.md` is the sole harness router; nested `AGENTS.md` files
are not used. Selected rules are canonical within their scope; read them before editing. Read
matching files explicitly: a path reference is not an automatic import.

Always load `generic/model-behavior-calibration.mdc` — it applies to every task. Load
`generic/rails-change-discipline.mdc` for every Ruby on Rails implementation change. Then load only
the remaining entries matching the task.

- Controllers or endpoints: `generic/controllers.mdc`, `generic/routing.mdc`,
  `project/surfaces.mdc`, `project/controller-inheritance.mdc`, `project/browser-rp-contract.mdc`,
  `generic/authentication-boundaries.mdc`, `docs/architecture/controller-lifecycle.md`
- React components and hooks: `docs/reference/react.md`, `docs/design.md`
- UI/UX, visual appearance, layout, styling, or interaction design: `DESIGN.md` — the canonical
  owner of these concerns; follow it over other guidance for appearance and experience
- JSON API endpoints, error responses, or API versioning: `docs/reference/api-design-standards.md`
- Minitest or behavior changes: `generic/testing.mdc`, `generic/no-test-only-code.mdc`,
  `project/static-invariant-guards.mdc`
- Any line that reads or assigns `ENV`, in application, configuration, Rake, or test code:
  `generic/no-silent-fallback.mdc`, `adr/env-fetch-without-default.md`
- Environment, dependency, tooling, or mounted-engine setup: `project/no-environment-tests.mdc`,
  `adr/no-test-suite-for-environment-construction.md` — setup is never covered by Minitest or
  Vitest; run it and record the result in `evidence/`
- Adding any class outside `app/models` and `app/controllers` — values, results, services,
  operations, resolvers, policies, queries, forms, presenters, serializers, or adapters:
  `project/value-object-boundaries.mdc`
- Migrations: `generic/migrations.mdc`, `generic/rails-change-discipline.mdc`
- Persistent data or API shape, including JSON and database schemas: `generic/data-shape-design.mdc`
- Identifier generation, public references or identifier constraints: `project/identifiers.mdc`
- Security-sensitive work or broad refactors: `generic/absolute-rules.mdc`,
  `generic/no-silent-fallback.mdc`, `generic/fail-fast.mdc`, `project/regression-guards.mdc`
- Configuration or environment variables: `generic/no-silent-fallback.mdc`, `generic/fail-fast.mdc`
- Invariants, preconditions, unexpected state, or strict-vs-lenient behavior:
  `generic/fail-fast.mdc` — complements `generic/no-silent-fallback.mdc` (raise on broken
  invariants; do not swallow or guess a substitute)
- Renaming, moving, replacing, removing, restructuring, or migrating an existing implementation:
  `generic/no-compatibility-layer.mdc`
- Runbooks, or any change that alters an operator procedure for a deployed environment, shared
  database or external provider (key rotation, rollout, provisioning, incident response):
  `docs/runbooks/README.md` — every runbook lives in `docs/runbooks/`; update the affected runbook
  in the same change
- Compose files, container ports, or devcontainer configuration:
  `docs/operations/development-host-port-exposure.md`
- Routing or authentication workflows: `project/surfaces.mdc`, `generic/routing.mdc`,
  `generic/no-workflow-drift.mdc`, `generic/no-silent-fallback.mdc`,
  `generic/authentication-boundaries.mdc`, `project/browser-rp-contract.mdc`,
  `docs/architecture/controller-lifecycle.md`
- Sign-in, session issuance, session limits, the login cooldown, or sign-out:
  `project/session-issuance.mdc`, `generic/lifecycle-transition-writers.mdc`,
  `adr/root-login-establishment-boundary.md`
- State machines, flow or status columns, status reference tables, or any code that writes a state
  or status value: `docs/mermaid/README.md` — locate the affected axis in its inventory, compare the
  matching `docs/mermaid/idp-*.mmd` diagram and its section in
  `docs/mermaid/idp-state-machine-transition-inventory.md` with the code, and update them in the
  same change so the diagrams keep describing the current implementation; also load
  `generic/lifecycle-transition-writers.mdc`; add an inventory row and a diagram when the change
  introduces a new axis
- User-facing notices, alerts, or feedback: `generic/no-flash-messages.mdc`
- Translation keys, locale bundles under `config/locales/`, or `t`/`I18n.t` calls:
  `docs/architecture/i18n.md`, `adr/i18n-explicit-translation-keys.md`
- Google, Apple, or Microsoft Entra ID sign-in buttons and provider branding:
  `docs/reference/third-party-sign-in-button-requirements.md`
- External technical sources: `generic/source-policy.mdc`
- Documentation, ADRs, plans, research, harnesses, comments, or test names:
  `generic/repository-language.mdc`
- `README.md` changes: `project/readme-authoring.mdc`, `generic/repository-language.mdc`
- Logging, audit records, telemetry, or analytics: `adr/application-logging-boundary.md`,
  `docs/security/observability-boundary.md`
- Rails Concern creation, modification, review, or refactoring (controller or model concerns),
  including method visibility or `included do` hooks: `generic/rails-concerns.mdc`,
  `docs/architecture/method-visibility-and-concerns.md`
- Behavior changes in an area covered by `docs/checklists/`: `project/acceptance-checklists.mdc`
- Non-trivial decisions, plan deviations, or handoff context: `generic/implementation-notes.mdc`,
  `project/repository-knowledge-tree.mdc`

For non-trivial architecture, routing, authentication, authorization, database, preference, surface,
or service-layer work, use `project/repository-knowledge-tree.mdc` to load and prioritize material
under `research/`, `adr/`, `specs/`, `plans/`, and `docs/`. Surface conflicts between current code
and an accepted ADR before choosing an implementation path.

## Specifications and Repository Content

Use `specs/README.md` for scope, lifecycle and traceability, and the `spec-driven-development` Skill
for significant accepted changes. Keep small obvious edits lightweight. Define purpose, scope and
observable acceptance before implementation; add plans and ordered tasks when complexity warrants
them. Consider affected quality priorities above and how to verify them. Follow existing
authorization; workflow phases alone do not require repeated approval.

- `docs/reference/repository-knowledge-architecture.md` defines ownership. Accepted ADRs, open specs
  and durable checklists define intended behavior; code and observed execution establish current
  behavior. Preserve existing implementation patterns where compatible with those contracts. Report
  conflicts explicitly and resolve them within authorized scope; neither code nor documentation
  silently overrides the other. Closed specs preserve history; current behavior belongs in docs and
  durable checklists.
- Repository prose is English except localization content, translation fixtures, non-English
  customer copy and necessary quotations. Conversation language does not change this; follow
  `docs/reference/repository-language-policy.md`.
- `.agents/skills/` holds skills with a `SKILL.md` entrypoint. `.agents/harnesses/rules/` is the
  only harness directory. Keep task scope in the conversation; do not add `.agents/goals/` files.
- At significant implementation-cycle closure, archive working plans, detailed definitions, addenda,
  acceptance definitions and reports under `plans/archive/NNNN-<slug>/`, not ignored root files.
  Promote lasting requirements first. Archives are non-normative, deletable and not evidence; follow
  `plans/archive/README.md`.

## Verification and Reporting

```bash
bin/rails test                             # all Ruby tests (Minitest)
bin/rails test test/path/to/file_test.rb   # one file
bin/rails test test/path/to/file_test.rb:LINE
bun run test                             # JavaScript tests (Vitest)
```

- Meaningful behavior changes need risk-appropriate tests for success, failure, authorization and
  boundaries. No placeholder, skipped, TODO or behavior-mocking tests. Start with the narrowest
  relevant checks; broaden only when the affected boundary warrants it.
- **MUST:** test immediately below, at and above each public range, limit, format or classification
  boundary. Use the nearest valid/reachable value when needed and explain the exception in the test
  name or comment. Cover type-appropriate missing, empty, zero and reachable sentinel inputs.
  **SHOULD:** use one representative per equivalence partition unless the contract distinguishes
  more; make the technique recoverable from names/assertions.
- Unit tests exercise public methods and functions. Reach private/protected subroutines through
  their public callers; a need to test one directly suggests misplaced behavior or a missing
  collaborator. Do not widen visibility, add test-only wrappers/accessors, or use `send`, reflection
  or redefinition to test them. Any exception needs a reason in a comment at the test.
- Environment/tooling construction is an absolute exception: no Minitest or Vitest tests of
  dependency, configuration, container or mounted-engine setup. Run it and record observations in
  `evidence/`; see `.agents/harnesses/rules/project/no-environment-tests.mdc`.
- Before reporting behavior, check implementing code, relevant docs and tests. Documentation alone
  does not establish behavior; report every discrepancy found. Claim only results supported in this
  session and state failed, skipped, blocked and unverified checks plainly. Keep reports
  proportional.

### Evidence

Retain short records in `evidence/` when useful for completed tests, validation, audits, security or
performance checks. Record actual work, not plans or unverified claims. For incomplete checks, state
why and what was observed. Include the full commit hash from `git rev-parse HEAD` and whether
uncommitted changes affected the result.

- Flat directory, Markdown only: `YYYY-MM-DD-<topic>-XXXX.md`, with a freely chosen four-character
  `[0-9A-Z]` suffix to avoid collisions. Use an ISO date and a lowercase, hyphenated topic.
- Summarize results and cite commands, identifiers, hashes, measurements and relevant excerpts. Keep
  raw logs, screenshots, binaries, archives, dumps and large generated reports out of evidence.
