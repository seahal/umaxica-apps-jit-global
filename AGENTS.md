# Umaxica Apps Global — Agent Instructions

Ruby on Rails application, not the Rails framework monorepo.

This repository is built for production deployment, not as a proof of concept. Treat every change as
code that will run in production and serve real users.

`README.md` describes the repository and its current topology. This file contains only
repository-wide agent rules that cannot be reliably derived from the code. Task-specific rules under
`.agents/harnesses/rules/` are canonical within their scope; load only those selected by the Task
Rule Index before editing.

## Scope and Authorization

- For explanation, review, diagnosis, or planning, inspect and report without changing files.
- For change, build, or fix requests, make only the in-scope local change and run non-destructive
  verification without additional approval.
- Obtain explicit approval before destructive or irreversible actions, external writes, purchases,
  material scope expansion, or actions requiring information only the user can provide.
- Preserve unrelated staged, unstaged, and untracked work. Keep the existing worktree intact.

## Application Boundaries

Treat every user-facing surface as an independent trust boundary. Use the `README.md` "Routing"
section for the current surface inventory and `project/surfaces.mdc` for surface-specific rules.

Preserve each surface's controllers, routes, views, policies, sessions, and state. Cross-surface
sharing requires an explicit existing abstraction; cross-surface leakage is a security defect.

## Task Rule Index

Rule paths are relative to `.agents/harnesses/rules/`; documentation and ADR paths are relative to
the repository root. This root `AGENTS.md` is the sole harness-routing entry point; nested
`AGENTS.md` files are not used for rule loading.

Always load `generic/model-behavior-calibration.mdc` — it applies to every task. Load
`generic/rails-change-discipline.mdc` for every Ruby on Rails implementation change. Then load only
the remaining entries matching the task.

- Controllers or endpoints: `generic/controllers.mdc`, `generic/routing.mdc`,
  `project/surfaces.mdc`, `project/controller-inheritance.mdc`, `project/browser-rp-contract.mdc`,
  `generic/authentication-boundaries.mdc`, `docs/architecture/controller-lifecycle.md`
- React components and hooks: `docs/reference/react.md`, `docs/design.md`
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
- Security-sensitive work or broad refactors: `generic/absolute-rules.mdc`,
  `generic/no-silent-fallback.mdc`, `generic/fail-fast.mdc`, `project/regression-guards.mdc`
- Configuration or environment variables: `generic/no-silent-fallback.mdc`, `generic/fail-fast.mdc`
- Invariants, preconditions, unexpected state, or strict-vs-lenient behavior:
  `generic/fail-fast.mdc` — complements `generic/no-silent-fallback.mdc` (raise on broken
  invariants; do not swallow or guess a substitute)
- Renaming, moving, replacing, removing, restructuring, or migrating an existing implementation:
  `generic/no-compatibility-layer.mdc`
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

## Governing Principles and Constraints

Security bounds our ability to create value. Within that boundary, performance, experience,
documentation, longevity and observability are coequal. Category order is not priority.
**MUST**, **SHOULD**, and **MAY** follow BCP 14; express requirements positively.

- **MUST:** preserve surface trust, ownership, session and state boundaries, and applicable
  authentication, authorization, CSRF, verification, rate limits and security-relevant control order.
- **MUST:** prevent SQL injection and XSS through parameterized access, contextual escaping and
  appropriate sanitization; keep untrusted data separate from executable content.
- **MUST:** protect people from foreseeable harm and protect credentials, tokens, cookies,
  authorization data and sensitive request data from disclosure, including diagnostic output.
- **MUST:** keep orchestration, authorization, domain behavior, persistence and presentation with
  their owners. Keep request state explicit, not in class variables, globals or `Thread.current`.
- **MUST:** make invalid state, unsupported workflows, failed prerequisites and missing required
  configuration explicit and observable. Keep production independent of test-only requirements.
- **MUST:** read required Ruby environment variables with one-argument `ENV.fetch("NAME")`; read
  optional variables with `ENV["NAME"]` and an explicit nil branch. Code-side defaults are defects.
- **MUST:** preserve unchanged external contracts, persistent data, identity/security state and
  audit history. Persist authoritative audit, security, compliance and purchase events as records.
- **MUST:** obtain explicit risk and recovery-plan approval before destructive or irreversible
  persistence operations, including bulk updates/deletes and irreversible migrations.
- **SHOULD:** make ownership, visibility, dependencies and failures explicit; implement the smallest
  coherent solution. Adjacent cleanup belongs only within the authorized change.
- **SHOULD:** preserve replaceability and proportional abstractions. **MAY:** use bounded transitional
  mechanisms when safe deployment or migration requires them; record their exit conditions.
- **SHOULD:** code states how, tests state what, commit messages state why, and comments state why
  not. Preserve non-obvious decisions in their owning knowledge artifacts. Maintain affected current
  documentation; historical research has no general maintenance obligation.
- **MUST:** test public contract boundaries immediately below, at and above each range, limit,
  format or classification boundary. Use the nearest valid/reachable value when necessary and
  explain the exception in the test name or comment. Cover type-appropriate missing, empty, zero
  and other reachable sentinel inputs. **SHOULD:** use one representative per equivalence partition
  unless the contract distinguishes more, and make the technique recoverable from names/assertions.

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

Unit tests cover public methods and functions only. A private or protected subroutine needs no test
case of its own: it is reached through the public interface that uses it, and a subroutine that
seems to need a direct test is evidence that the implementation, not the test, needs changing (wrong
ownership, a missing collaborator, or behavior that belongs on a public boundary). Never widen
visibility, add a test-only wrapper or accessor, or reach in through `send`, reflection, or a
redefinition to test one. Any exception carries a comment at the test stating the reason.

Environment and tooling construction is the exception, and it is absolute: never add a Minitest or
Vitest case whose subject is dependency, configuration, container, or mounted-engine setup. Run the
thing and record what you observed in `evidence/`. See
`.agents/harnesses/rules/project/no-environment-tests.mdc`.

Report only claims supported by results from the current session. State failed, skipped, blocked,
and unverified checks plainly. Lead with the outcome; keep responses proportional to the task. Do
not add a separate verifier pass; delegate only independent, substantial work whose parallel
execution outweighs re-establishing context.

## Spec Driven Development

Use `specs/README.md` for scope, lifecycle and traceability, and the `spec-driven-development`
Skill when a significant accepted change needs a workflow. Small obvious edits remain lightweight.
Current knowledge ownership is defined in `docs/reference/repository-knowledge-architecture.md`.
Closed specs preserve change history; current behavior belongs in docs and durable checklists.

### Evidence

Completed tests, validations, verifications, audits, security checks and performance checks leave a
short record in `evidence/` when retaining the result is useful. Records describe work that was
actually performed — never plans, intentions, or unverified claims. A check that could not be
completed is recorded as such, with the reason and whatever was observed. Every record states the
full git commit hash (`git rev-parse HEAD`) the work was performed against, and notes when the
worktree had uncommitted changes that affected the result.

- `evidence/` is flat; no subdirectories.
- Only `.md` files.
- `YYYY-MM-DD-<topic>-XXXX.md`: ISO date, lowercase hyphenated topic, then a 4-character `[0-9A-Z]`
  suffix picked freely by the writing agent to avoid merge collisions.
- No raw logs, screenshots, binaries, archives, dumps, generated reports or other large artifacts.
  Summarize them, and cite the commands, identifiers, hashes, measurements and excerpts that carry
  the result.
