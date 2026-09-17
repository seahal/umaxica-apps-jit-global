# No Test Suite for Environment Construction

Accepted: 2026-09-17

## Context

Adding the three diagnostic surfaces (`rails_performance`, Coverband, Swagger UI) produced four new
test files before anyone asked whether they belonged in the suite at all:

- an invariant asserting no OpenAPI description sits under `public/`
- an invariant comparing this repository's copy of `rails_performance`'s route list against the
  gem's shipped file
- a unit test for the record sanitiser that strips secrets before they reach Valkey
- a unit test for the process gate that keeps Coverband out of consoles, rake tasks, and the suite

Each was defensible on its own. Together they made the problem visible.

Three of the four assert things about an environment that does not exist while they run. All three
gems are `group :development`, so under `RAILS_ENV=test` the constants are undefined, the engines
are unmounted, and the routes are undrawn. The mount-and-host assertions therefore either skip or
check the shape of a route table in the one environment where nothing is mounted. They pass, they
look like coverage, and they are not evidence about the environment anyone was worried about.

The suite's value comes from being readable as a description of this application's behaviour. A
developer opening `test/security/invariants/` is asking what the authorization model guarantees.
Answering that question now means sorting genuine invariants — refresh-token reuse, CSRF strategy,
cookie security, controller lifecycle order — from assertions that a gem landed in the right
Bundler group. The signal degrades in proportion to how much setup accumulates, and setup
accumulates every time the environment is touched.

The cost profile is also inverted. Environment construction is a one-time activity; a test case runs
on every commit forever. The route-list comparison reaches into a gem's internal
`config/routes.rb` — it is guaranteed to break on an upgrade, and the breakage will be
indistinguishable from a real problem until somebody reads it closely.

What would actually have caught a failure in any of this is reaching the host and watching what it
answers.

## Decision

Environment and tooling construction is not covered by Minitest or Vitest.

This covers: third-party dashboards, engines, and mounted Rack apps; gem, npm, and container
dependencies and their lockfiles; `config/environments/*`, `config/application.rb`, and initializer
wiring for a tool; Host Authorization entries and operator-surface host constraints; Compose,
devcontainer, and Procfile configuration; build, bundling, lint, and format tooling; and the
environment variables that plumb any of it.

Results are established by running the thing and recorded in `evidence/` under the rules AGENTS.md
already sets: the commands, identifiers, status codes, and excerpts actually observed, with
anything that could not be completed recorded as not completed and why.

Reasoning goes where the next reader will be standing — a comment at the configuration site, and an
ADR when the decision is architectural. Where a gem internal has been copied into this repository,
the copy site says so and names what to re-read on upgrade.

The four files described above are deleted. The rule is written into
`.agents/harnesses/rules/project/no-environment-tests.mdc` and indexed from AGENTS.md so it reaches
agent sessions without being restated each time.

## Boundaries

The rule is about a test's subject, not its directory.

Behaviour changes to this application's own code keep their existing obligation to carry
risk-appropriate tests covering success, failure, authorization, and boundary cases. Touching a
configuration file on the way does not exempt a behaviour change.

Existing invariants under `test/security/invariants/` stay as they are. They encode real properties
of application code. `MountedEngineInvariantTest` in particular keeps working unchanged and was
deliberately not extended for the three new surfaces: it already fails on any mounted Rack app that
is not in its reviewed list, and the three new gems do not load under `RAILS_ENV=test`, so there is
nothing for it to see.

A tool is covered through the application's dependency on its output, never through the tool
itself. The OpenAPI descriptions are contract-tested because the JSON API must conform to them, not
because Redocly is configured correctly.

## Consequences

Accepted, and stated plainly rather than minimised:

- Regressions in environment construction are not caught automatically. If someone moves
  `coverband` out of `group :development`, or drops the `paths["config/routes.rb"] = []` line that
  suppresses `rails_performance`'s unconstrained self-mount, no test fails. Those specific hazards
  are documented at their sites and in
  `adr/diagnostic-surfaces-performance-coverband-swagger.md`; they now rely on review and on the
  comments being read.
- The `rails_performance` route-list copy will drift on upgrade with nothing to flag it.
- In exchange, the suite stays a description of the product, upgrades stop breaking tests that were
  never about the product, and the evidence for environment work is an actual observation of the
  running system rather than an assertion evaluated in an environment where the subject is absent.

## Related

- `.agents/harnesses/rules/project/no-environment-tests.mdc` — the operative rule
- `.agents/harnesses/rules/generic/no-test-only-code.mdc` — the converse prohibition: test concerns
  must not leak into application code
- `adr/diagnostic-surfaces-performance-coverband-swagger.md` — the work that prompted this
