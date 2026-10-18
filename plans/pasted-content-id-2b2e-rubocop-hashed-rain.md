# Plan: devcontainer browser desktop, strict RuboCop, SDD/harness review

## Context

Three pasted task briefs, to be run in the order the user chose:

1. **Chromium / Playwright / noVNC inside the existing Dev Container** (implement and verify).
2. **RuboCop strict configuration refactor** (implement and verify).
3. **Enterprise SDD / agent-harness architecture review** (analysis only, no repository changes).

Working split requested by the user: static work (reading, editing) happens on the host checkout;
everything dynamic (bundle, rubocop, rails, playwright, the desktop stack) runs inside the
`global-devcontainer-core` container through `podman exec`. The host does not run Rails.

State observed at `feature` @ `6eb02aa9f` (remote is `seahal/umaxica-app-jit`, not the
`umaxica-apps-jit-global` named in the brief; the working directory is taken as the target):

- All compose containers are stopped (exited ~9h ago). ~600 files of uncommitted WIP.
- RuboCop 1.91.0, rails 2.38.0, performance 1.27.0, minitest 0.41.0, rake 0.7.1, i18n 3.3.0,
  thread_safety 0.8.0, rubycw 0.2.2, rails-omakase 1.1.0, ast 1.50.0.
- `.rubocop.yml` inherits omakase, `.rubocop/rubocop_ast.yml`, `.rubocop/umaxica.yml`,
  `.rubocop_todo.yml`; `Style/DisableCopsWithinSourceCodeDirective` is off.
- 775 `rubocop:disable`, 353 `rubocop:enable`, 0 `todo`. Largest groups: `Lint/Void` 231,
  `Minitest/Assert{Equal,Operator,Same}` 275, `I18n/RailsI18n/DecorateString` 65,
  `Rails/SkipsModelValidations` 60, `Minitest/MultipleAssertions` 54, `ThreadSafety/*` 105,
  `Metrics/*` 31.
- 6 `Enabled: false`, 17 `Exclude:`, 4 `Allowed*` blocks in `.rubocop.yml`.
- `config/tmp/rubocop_cache/` is tracked; `CacheRootDirectory` is `tmp/rubocop_cache`.
- No `db/**/*_migrate/**/*.rb` file is tracked, so that `AllCops/Exclude` entry and its per-cop
  twins match nothing.
- `Layout/ClassStructure` is scoped to `app/controllers/**` only. 896 model files, 1109 controllers.
- Two custom cops exist (`lib/rubocop/cop/umaxica/*`), with `.rubocop_todo.yml` (1388 lines) and the
  `architecture_baseline` rake/lib/test serving only them.
- Dev image is Debian trixie (`Containerfile`, `development` stage), already carries Chromium's
  shared-library closure; `playwright ^1.64.0` and `playwright.config.ts` exist; `core` runs
  `sleep infinity` under `no-new-privileges` with loopback-only port publication.

Decisions already made by the user:

- Keep the two existing custom cops and their baseline; add no new custom cop. `.rubocop_todo.yml`
  therefore stays, limited to those two cops, and is reported as a retained exception.
- Commit the current WIP as one `[WIP]` commit before starting, then commit each stage separately.
- Starting the stack, rebuilding `core`, and rebuilding the dev/test databases are authorized.

## Step 0 — Preparation

1. Inspect the 10 untracked paths before staging (no secrets, no scratch documents swept in by
   accident), then create one `[WIP]` commit of the existing work. If a lefthook hook fails, stop and
   report rather than bypass it.
2. Bring the stack up: `podman rm -f --depend` the stale containers, then compose up with
   `-f compose.yaml -f .devcontainer/compose.yaml`. Do not start the apps-edge tunnel connector.
3. Rebuild databases (`RAILS_ENV=test bin/rails db:migrate`, dev likewise) and re-clone the replica.
   Leave `db/*_structure.sql` untouched.

## Part 1 — Chromium / Playwright / noVNC

Architecture: `Chromium / Playwright → Xvfb :99 (1440x900x24, -nolisten tcp) → x11vnc (127.0.0.1:5900
in-container, password file) → websockify + noVNC :6080 → host 127.0.0.1:6080`. No new service.

Files:

- `Containerfile` (`development` stage only): add `chromium`, `chromium-sandbox`, `xvfb`, `x11vnc`,
  `novnc`, `websockify`, `openbox`, `fonts-noto-cjk`, `fonts-noto-color-emoji` to the existing apt
  list after confirming each exists in trixie; `COPY` the launcher root-owned `0555` next to
  `core-entrypoint`. Production stages are not touched.
- `podman/core/desktop.sh` (new, baked as `/usr/local/bin/core-desktop`): `start|stop|status`.
  Idempotent via per-process pidfile + liveness check under a `flock`; logs per process under
  `~/.local/state/desktop/`. Generates a random VNC password into a `0600` file there on first
  start (never in the repo, image, or logs). Runs as `global`.
- `.devcontainer/compose.yaml`: add `127.0.0.1:6080:6080`, set `DISPLAY=:99`, and start the desktop
  from `core`'s command before `sleep infinity` so a plain container start is enough. A desktop
  failure is logged and must not take the container down. Port 5900 is not published.
- `docs/operations/development-host-port-exposure.md`: add the 6080 row; adjust
  `test/tooling/compose_host_port_exposure_test.rb` only if it carries an allowlist.
- `playwright.config.ts`: optional `PLAYWRIGHT_CHROMIUM_EXECUTABLE` read with an explicit unset
  branch (no default), mapped to `launchOptions.executablePath`. Headed mode stays the `--headed`
  CLI flag. Existing bundled-Chromium behavior is unchanged when the variable is unset.
- A short operations doc for start, connect, password retrieval, update procedure.

Known risks to resolve by observation, not assumption:

- **Sandbox.** `no-new-privileges:true` disables the setuid `chromium-sandbox`; Chromium must use
  the user-namespace sandbox. If nested userns is refused in this container, that is reported as a
  blocker with the observed error. `--no-sandbox` is not added and security options are not relaxed.
- **Loopback bind vs publication.** Rootless Podman forwards to the container interface, so
  websockify probably has to listen on `0.0.0.0` inside the container while the host side stays
  `127.0.0.1` (same contract as Rails). Verify with `ss` on the host.
- **Version skew** between APT Chromium and the build Playwright 1.64 expects; record both versions
  and any failing feature.
- Manual browsing uses a dedicated `--user-data-dir`; Playwright keeps its temporary profiles.

Verification (all ten items of the brief, each marked verified / unverified):

- Smoke script kept outside the tracked test suites (environment setup is never a Vitest/Minitest
  subject): headless and headed runs against a `data:` URL, screenshot, trace saved and opened.
- `xwd`/screenshot of `:99` during a headed run to prove it renders on the shared display;
  `curl 127.0.0.1:6080/vnc.html` from the host; noVNC interaction through the host browser.
- `ps -o user,args` and `chrome://sandbox` / `/proc/<pid>/status` to prove non-root and sandbox on.
- `podman restart` then repeat; run the launcher twice to prove no duplicate processes.
- One existing `e2e/` spec against the local Rails app if `bin/dev` comes up.
- Record in `evidence/YYYY-MM-DD-devcontainer-browser-desktop-XXXX.md`. Commit.

## Part 2 — RuboCop strict refactor

Rules of engagement: no `rubocop:disable`, no new todo debt, no `-A`, no bulk
`Layout/ClassStructure` autocorrect, no semantic change to auth/security code. An offense that
cannot be removed without changing runtime or security behavior is listed as a blocker and left
visible; it is not suppressed.

Stages, each ending with `bundle exec rubocop` and its own commit:

1. **Baseline** (in container, outputs under `tmp/`): `--version`, `--show-cops`, JSON with and
   without `--ignore-disable-comments`, and the suppression / `Enabled: false` / `Exclude` /
   `Allowed*` counts.
2. **Omakase removal.** Diff effective config with and without the `inherit_gem`. Classify each
   omakase-driven setting as keep-explicit / unneeded / newly-enabled. Omakase sets
   `DisabledByDefault`-style department switches, so departments the project relies on get explicit
   `Enabled: true`. Remove the gem from `Gemfile`, `bundle lock`, confirm the bundle resolves.
3. **Loader and cache cleanup.** Remove `.rubocop/rubocop_ast.yml` only after rubocop loads
   identically without it. `git rm --cached` `config/tmp/rubocop_cache/` after confirming it is pure
   cache, and ignore it. Translate the Japanese comments in `.rubocop.yml` to English while
   restructuring (repository language policy). Set `FailLevel` explicitly; keep `NewCops: enable`.
4. **Config audit.** Every `Enabled: false`, `Exclude`, `Allowed*` gets a keep/remove verdict
   against upstream docs for the installed versions. Drop the dead `*_migrate` entries, the stale
   paths that no longer exist (e.g. `app/controllers/sign/...`, `core/com/contact/...`), and
   allowlist entries that only exist to pass existing code. Audit the rubocop-rails cop list,
   including the sixteen named cops; keep `Rails/ActionControllerFlashBeforeRender`,
   `Rails/ActiveRecordCallbacksOrder`, `Rails/MatchRoute`, `Rails/MultipleRoutePaths` on. Review
   Metrics maxima without triggering unrelated refactors.
5. **Suppression removal**, by cop group, smallest-risk first, running affected tests per group:
   - Minitest assertion cops and `Lint/Void` in `test/`: rewrite assertions to the intended form,
     checking `assert_same` vs `assert_equal` meaning case by case.
   - `I18n/RailsI18n/DecorateString`, `Rails/SkipsModelValidations`, `ThreadSafety/*`: fix the code
     where the cop is right; where the cop is inapplicable to a whole class of files (e.g. thread
     tests), decide in config with a written reason rather than per-line.
   - `Metrics/*`, `Rails/*`, `Lint/*` in `app/` and `lib/`: behavior-preserving extraction only;
     auth and security paths get the most conservative treatment and the most blockers.
   - Then enable `Style/DisableCopsWithinSourceCodeDirective` (`AllowedCops: []`),
     `Lint/CopDirectiveSyntax`, `Lint/Redundant{CopDisable,CopEnable}Directive`,
     `Style/DoubleCopDisableDirective`.
6. **`Layout/ClassStructure` for models.** Inventory the DSL actually used in `app/models`, design
   one merged `Categories` / `ExpectedOrder` that serves controllers and models, extend `Include`,
   then reorder class by class by hand. After each batch: `bin/rails runner
   'Rails.application.eager_load!'` and the model tests. Order-dependent declarations are either
   untangled or reported.
7. **Final comparison.** `--show-cops` after vs before: no cop lost unintentionally, plugin cops
   loaded, departments as intended. `bundle exec rubocop`, `--ignore-disable-comments`, full
   `bin/rails test`. Evidence record, final report per section 23 of the brief, including every
   retained exception and every blocker.

Expectation to state plainly: with 775 suppressions concentrated in tests and authentication code,
reaching zero offenses in one pass is the goal, not a guarantee. What does not reach zero is
reported with counts and reasons.

## Part 3 — SDD / agent-harness architecture review (read-only)

No file is created, moved, or changed. Output is the Japanese decision report (sections A–K of the
brief) delivered in the conversation.

1. Read current primary documentation for OpenAI (AGENTS.md discovery/precedence, skills, hooks,
   subagents, sandboxing, prompting guidance) and Anthropic (CLAUDE.md, skills, hooks, subagents,
   plugins, skill authoring), tagging each statement as guaranteed / documented / observed /
   hypothesis. Model names and discovery paths are confirmed from the docs, not from memory.
2. Audit the repository: `AGENTS.md` (18 KB), `CLAUDE.md` (`@AGENTS.md` import), 30 harness rules
   (85 KB), 25 skills (243 KB), `.claude/skills`, `.codex`, `spec/` (111 files) and its references
   in `vitest.config.ts`, `knip.json`, `package.json`, `tsconfig*`, `plans/` (active 4, analysis 14,
   backlog 63, archive 5), `notes/` 197, `memos/` 27, `adr/` 199, `docs/` 391, `evidence/` 669, root
   documents (`refactor.md` 427 KB, `one.md`…`seven.md`, `misc.md`, `conflict.md`, empty `SKILL.md`),
   and Markdown path references.
3. Findings already visible and to be examined: empty top-level `governance/`, `controls/`, `risks/`
   contradict the brief's own decisions; `specs/`, `gait/`, `research/` exist empty; skill volume
   versus current-model need; where harness, skills, and docs duplicate each other.
4. Deliver the report and stop for approval.

## Critical files

- `Containerfile`, `.devcontainer/compose.yaml`, `podman/core/desktop.sh` (new),
  `playwright.config.ts`, `docs/operations/development-host-port-exposure.md`
- `.rubocop.yml`, `.rubocop/rubocop_ast.yml`, `Gemfile`, `Gemfile.lock`, `.gitignore`,
  `config/tmp/rubocop_cache/`, plus the source files carrying suppressions and `app/models/**`
- Unchanged by decision: `lib/rubocop/cop/umaxica/*`, `.rubocop/umaxica.yml`, `.rubocop_todo.yml`,
  `lib/architecture_baseline.rb`

## Reporting

Each part ends with its own report: what changed, what was verified with which command, what stayed
unverified, and what was left as an exception or blocker.
