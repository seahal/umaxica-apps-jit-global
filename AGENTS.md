# Umaxica Apps Global — Agent Instructions

Ruby on Rails application, not the Rails framework monorepo.

`README.md` describes the repository and its current topology. This file contains only
repository-wide agent rules that cannot be reliably derived from the code. Task-specific rules under
`.agents/harnesses/rules/` are canonical within their scope; load only those selected by the
Task Rule Index before editing.

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

Rule paths are relative to `.agents/harnesses/rules/`; documentation paths are relative to the repository root. Load only the entries matching the task.

- Controllers or endpoints: `generic/controllers.mdc`, `generic/routing.mdc`, `project/surfaces.mdc`, `project/controller-inheritance.mdc`, `docs/architecture/controller-lifecycle.md`
- JSON API endpoints, error responses, or API versioning: `docs/reference/api-design-standards.md`
- Minitest or behavior changes: `generic/testing.mdc`, `generic/no-test-only-code.mdc`
- Environment, dependency, tooling, or mounted-engine setup: `project/no-environment-tests.mdc`, `adr/no-test-suite-for-environment-construction.md`
- Adding any class outside `app/models` and `app/controllers` — values, results, services, operations, resolvers, policies, queries, forms, presenters, serializers, or adapters: `project/value-object-boundaries.mdc`
- Migrations: `generic/migrations.mdc`
- Persistent data or API shape, including JSON and database schemas: `generic/data-shape-design.mdc`
- Security-sensitive work or broad refactors: `generic/absolute-rules.mdc`, `generic/no-silent-fallback.mdc`, `project/regression-guards.mdc`
- Configuration or environment variables: `generic/no-silent-fallback.mdc`
- Compose files, container ports, or devcontainer configuration: `docs/operations/development-host-port-exposure.md`
- Routing or authentication workflows: `project/surfaces.mdc`, `generic/routing.mdc`, `generic/no-workflow-drift.mdc`, `docs/architecture/controller-lifecycle.md`
- User-facing notices, alerts, or feedback: `generic/no-flash-messages.mdc`
- Google, Apple, or Microsoft Entra ID sign-in buttons and provider branding: `docs/reference/third-party-sign-in-button-requirements.md`
- External technical sources: `generic/source-policy.mdc`
- Documentation, ADRs, plans, notes, memos, harnesses, comments, or test names: `generic/repository-language.mdc`
- `README.md` changes: `project/readme-authoring.mdc`, `generic/repository-language.mdc`
- Logging, audit records, telemetry, or analytics: `adr/application-logging-boundary.md`, `docs/security/observability-boundary.md`
- Concerns, method visibility, or `included do` hooks: `generic/rails-concerns.mdc`, `docs/architecture/method-visibility-and-concerns.md`
- Non-trivial decisions, plan deviations, or handoff context: `generic/implementation-notes.mdc`, `project/repository-knowledge-tree.mdc`

For non-trivial architecture, routing, authentication, authorization, database, preference, surface, or service-layer work, use `project/repository-knowledge-tree.mdc` to load and prioritize material under `memos/`, `notes/`, `adr/`, `plans/`, and `docs/`. Surface conflicts between current code and an accepted ADR before choosing an implementation path.

## Governing Principles

We sustain this codebase by creating value for people.

**Security preserves our ability to continue that work.** Security defines the boundary within which implementation proceeds and preserves both safety and the system's ability to deliver value.

Four coequal virtues guide implementation within that boundary:

- **Performance:** measure material behavior rather than assuming it.
- **Experience:** preserve responsiveness, usability, accessibility, and interaction quality.
- **Documentation:** preserve intent, decisions, plans, and evidence in natural language that humans and AI agents can reason from.
- **Longevity:** keep the system understandable, replaceable, maintainable, and safe to change over time.

## Implementation Rules

**MUST**, **SHOULD**, and **MAY** use the normative meanings defined by BCP 14 (RFC 2119 and RFC 8174). Use positive formulations that state the behavior, invariant, or protection to preserve.

Category labels are identifiers only. Category order carries no priority. Rules are independent constraints rather than scores or weights, and rule counts are never additive. Resolve genuine conflicts through the governing principles above.

* **(A) Security and Trust Boundaries**

  * **MUST:** preserve separation between the `app`, `org`, `com`, `dev`, and `net` surfaces and their applicable trust, session, state, routing, and ownership boundaries.
  * **MUST:** preserve applicable authentication, authorization, verification, CSRF, rate-limit, input-validation, and equivalent security controls throughout every affected path, including the relative order in which those controls run when that order is itself security-relevant.
  * **MUST:** prevent SQL injection (SQLi) and cross-site scripting (XSS) through parameterized data access, context-appropriate output escaping or encoding, appropriate sanitization, and strict separation of untrusted data from executable SQL or browser content.
  * **MUST:** protect credentials, secrets, tokens, cookies, authorization data, and sensitive request data from unintended disclosure, including in logs, error messages, and diagnostic output.
  * **MUST:** protect people, users, operators, and other affected parties from foreseeable harm caused by the implementation or operation of the system.

* **(B) Responsibility and State**

  * **MUST:** place behavior with the component that owns its responsibility, keeping orchestration, authorization, domain behavior, persistence, and presentation distinguishable.
  * **MUST:** keep request-scoped state explicitly scoped and propagated through appropriate objects or interfaces, rather than through shared mutable state such as class variables, global variables, or `Thread.current`.
  * **SHOULD:** keep dependencies, ownership, state transitions, method visibility, and failure behavior explicit where they materially affect understanding or maintenance.

* **(C) Failure and Runtime Behavior**

  * **MUST:** make missing required configuration, invalid state, failed prerequisites, unsupported workflows, and migration assumptions explicit and observable.
  * **MUST:** keep production behavior independent of requirements that exist only for tests.
  * **MUST:** preserve externally visible behavioral contracts when the task leaves those contracts unchanged.
  * **SHOULD:** make failure modes diagnosable from their observable behavior and recorded context.

* **(D) Data and Records**

  * **MUST:** persist authoritative audit, security, compliance, and purchase events as data when the system depends on them as records of fact.
  * **MUST:** preserve persistent data, identity state, security state, and audit history except when an explicitly authorized operation requires their transition.
  * **MUST:** obtain explicit approval of the risk and the recovery or migration plan before any destructive or irreversible persistence operation, including but not limited to dropping or truncating tables, bulk deletes or updates, and irreversible schema or migration changes.
  * **SHOULD:** keep persistent data ownership and lifecycle explicit when modifying schemas, storage, or state transitions.

* **(E) Scope and Design**

  * **SHOULD:** make the smallest coherent change that completely solves the current problem.
  * **SHOULD:** build for current requirements and keep abstractions proportional to demonstrated need.
  * **SHOULD:** use established, actively maintained libraries or abstractions when they solve the required problem while preserving repository boundaries.
  * **SHOULD:** remove directly encountered accidental complexity, obsolete structure, and technical debt when the cleanup remains within the same coherent change.
  * **MAY:** refactor directly adjacent code when the refactor is required to leave the resulting implementation coherent.

* **(F) Documentation and Knowledge**

  * **SHOULD:** preserve non-obvious reasoning in the appropriate ADR, plan, evidence record, note, documentation, or comment so another human or AI agent can recover the intent.
  * **SHOULD:** keep comments focused on constraints and reasoning that cannot be recovered directly from the implementation.
  * **SHOULD:** update or remove documentation and comments when their assumptions cease to match the implementation.
  * **SHOULD:** explain why a change exists in its commit message rather than only what changed.

* **(G) Evolution and Compatibility**

  * **SHOULD:** preserve replaceability and clear ownership when extending existing components.
  * **SHOULD:** keep transitional mechanisms bounded to the requirement that makes them necessary.
  * **MAY:** use transitional compatibility mechanisms when safe deployment or migration requires a temporary compatibility boundary.


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

Environment and tooling construction is the exception, and it is absolute: never add a Minitest or
Vitest case whose subject is dependency, configuration, container, or mounted-engine setup. Run the
thing and record what you observed in `evidence/`. See
`.agents/harnesses/rules/project/no-environment-tests.mdc`.

Report only claims supported by results from the current session. State failed, skipped, blocked,
and unverified checks plainly. Lead with the outcome; keep responses proportional to the task. Do
not add a separate verifier pass; delegate only independent, substantial work whose parallel
execution outweighs re-establishing context.

## Spec Driven Development

<!-- Details pending; Evidence is filed under this section as its first subsection. -->

### Evidence

Completed tests, validations, verifications, audits, security checks and performance checks leave a
short record in `evidence/` when retaining the result is useful. Records describe work that was
actually performed — never plans, intentions, or unverified claims. A check that could not be
completed is recorded as such, with the reason and whatever was observed.

- `evidence/` is flat; no subdirectories.
- Only `.md` files.
- `YYYY-MM-DD-<topic>-XXXX.md`: ISO date, lowercase hyphenated topic, then a 4-character
  `[0-9A-Z]` suffix picked freely by the writing agent to avoid merge collisions.
- No raw logs, screenshots, binaries, archives, dumps, generated reports or other large artifacts.
  Summarize them, and cite the commands, identifiers, hashes, measurements and excerpts that carry
  the result.
