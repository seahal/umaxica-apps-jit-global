# Final hardening static review

Date: 2026-09-18 (UTC)

Branch: `feature`

Task start HEAD: `3ff5241c4b876c2c828e772c0fd289c8aae5f850`

Verification HEAD: `e176ee4920af6e7c4b14c54ecf4c4161332d1616`

The pre-existing `Gemfile.lock`, `README.md`, deleted `misc.md`/`refactor.md`, and five untracked
browser-block/sign-up investigation files were preserved and were not staged or committed by this
task.

An unrelated deletion of tracked `bin/setup-dev-secrets` was observed in the final commit even
though it was not part of the implementation. The `bin/` mount is read-only in this workspace, so
restoring the worktree file or creating a corrective hook-checked commit was not possible. It must
be restored or otherwise resolved in a writable checkout before integration. The separately staged
`bin/setup-diagnostic-env` deletion was not modified or committed by this task.

## Checks performed

- `ruby -c` over the 254 existing Ruby files changed since the task start, excluding deleted rename
  sources: passed.
- `git diff --name-only --diff-filter=ACMRT ... -- '*.rb' | xargs bundle exec rubocop --format simple`:
  the full 254-file run reported only the two pre-existing `ThreadSafety/ActiveSupportCallbacks`
  offenses in `test/security/invariants/refresh_token_reuse_invariant_test.rb`. The offending
  callback setup is present at the task-start revision as well. The other 253 changed Ruby files
  passed the same RuboCop command with no offenses.
- Scoped invariant searches passed: no `request.request_id` is used as an OTel trace ID; no queue or
  recurring wildcard/alias/merge pattern exists in `config/queue.yml` or `config/recurring.yml`; no
  concrete `Persona`/`Organization` alias or class remains in `app`/`lib`.
- With explicit disposable test variables, `RAILS_ENV=test bundle exec bin/jobs check` passed with
  `Solid Queue configuration is valid.`
- `ss` showed no listeners on `127.0.0.1:5432` or `127.0.0.1:6379`; `postgres`, `valkey-server`, and
  `redis-server` binaries were unavailable. No non-test datastore or external provider was used.

## Interpretation

Static and configuration checks above are current-session results. They do not prove PostgreSQL
transaction/concurrency behavior, Valkey atomic consumption, Solid Queue worker execution, recurring
delivery, or cross-database scrub recovery. Those checks remain blocked and are recorded in
`conflict.md`; no deployment-readiness claim is made for them.

## Addendum: free-form observability value redaction

- Commit `63478758d` extends the existing `ObservabilityRedactor` value boundary to replace
  token-shaped JWT and Bearer values inside free-form diagnostic strings. This covers exception
  messages normalized by `JitLogEvent` without changing request correlation IDs, access-log shape,
  authentication outcomes, or audit persistence.
- A DB-free smoke and the new redactor regression case confirmed that synthetic JWT and Bearer
  values become `[FILTERED]`; syntax, scoped RuboCop, and the commit hook passed. The Rails test
  command was attempted with explicit loopback PostgreSQL/Valkey test endpoints but stopped during
  schema boot because PostgreSQL was unavailable at `127.0.0.1:5432`; no assertions ran and no
  fallback datastore was used.

## Addendum: named credential assignment redaction

- Commit `033c5d88c` extends the same free-form boundary to values written as `token=...`,
  `access_token: ...`, and the other explicitly named credential forms covered by the redactor. This
  is a logging-only change; it does not change credential validation or authentication state.
- A DB-free red check reproduced the leak and the green smoke confirmed both values become
  `[FILTERED]`. Ruby syntax and scoped RuboCop passed, and no Rails test was claimed after this
  follow-up because the isolated PostgreSQL listener remains unavailable.
