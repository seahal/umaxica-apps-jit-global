# Xper Rails Surface Retirement Implementation Notes

## Context

- Original plan: frozen `one.md` and `two.md`, Xper retirement (DEC-064), AT-014–AT-017.
- Related decisions: `adr/xper-phase-zero-bootstrap.md`,
  `adr/defer-auth-xper-transient-workflow-redesign.md`, and
  `adr/xper-rails-surface-retirement.md`.
- Implementation date: 2026-10-13.

## Decisions Made During Implementation

- Removed the Rails Xper route draw, route file, 39 controllers, three views, three layouts, the
  stylesheet, host slots, Rails host allowlist entries, frontend-stack entries, and six Xper host
  variables from the example environment files.
- Removed only Xper rows from the twelve shared test files named by the plan. The generic unknown
  family assertion in `PreferenceBrowserControlsRegistryTest` remains, using `unknown` as its
  representative input.
- The new retired-host integration test checks the three public and three private former hosts over
  root, health, revision, both JSON endpoints, CSP report, robots, and sitemap paths. It does not
  impose a uniform status code; a retained Base host is the route-owner positive control.
- Static search found no Xper registration in `src/controllers/application.ts` and no Xper-specific
  locale keys in the two named locale files. Those files were not edited. The unrelated translation
  text containing the word “experience” remains.
- `docs/reference/ui-view-inventory.md` remains unchanged because it is an explicitly dated
  2026-10-05 snapshot; changing its historical source inventory would rewrite that record.
- No model, database, Preference implementation, authentication implementation, Edge, or Cloudflare
  configuration file changed. Flipper records were not deleted.

## Deviations From Plan

- `.devcontainer/compose.yaml` is mounted read-only. It still contains the three Xper frontend
  aliases at `services.core.networks.frontend.aliases`; it contains no `PUBLIC_XPER_*` or
  `PRIVATE_XPER_*` environment entries. The exact alias-only follow-up and preservation of adjacent
  aliases are recorded in the ignored `six.md` handoff. Step 5 is incomplete until that edit is
  recovered.
- The targeted Minitest command stopped before loading test cases. The test database safety check
  rejected the unset `POSTGRESQL_TEST_PREPARE_DATABASES` because 17 verified databases were absent
  from the preparation list. The current checkpoint deleted the isolated-test helpers, and the
  previously observed scratch manifests are absent. The guard was not bypassed and no test database
  was prepared.
- As a non-test routing check, Rails route recognition was run against six former hosts and eight
  paths; it found no product-surface controller match. The same eight paths resolved to Base on the
  retained Base host. This does not substitute for the unexecuted request integration test.

## Review Notes

- Development boot passed with all six Xper variables unset and the updated
  `.env.devcontainer.example` selected. `RUBY_DEBUG_ENABLE=0` was needed to prevent the debugger
  from binding a UNIX socket at a sandbox-restricted path.
- A production-mode `ConfigValues::HostFamilyValues.build` passed with 28 non-Xper host inputs and
  no Xper environment keys or data fields.
- Ruby syntax checks passed for 18 files. RuboCop reported no offenses in the 17 changed tracked Ruby
  files and the new integration test. Frontend-stack YAML parsing, six changed-document link checks,
  and `git diff --check` passed.
- The database guard prevented execution of the new request behavior test and the twelve shared test
  files. Their behavior remains unverified until the approved isolated-test setup is recovered.
