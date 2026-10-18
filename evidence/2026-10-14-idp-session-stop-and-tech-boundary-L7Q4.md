# IdP-session stop and Tech/Browser RP boundary verification

Date: 2026-10-14 UTC

Commit under test: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`

The worktree was already extensively dirty. The verification preserved that state and used only
the ordinary Rails `test` and `development` databases; `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset
for every Rails command recorded below. No reset, cleanup, isolated database, destructive rollback,
external write, or guard bypass was performed.

## Implemented boundary

`OidcEndSessionRequest` now treats an actor without a captured IdP `sid` as lacking a current IdP
session. `SignOidcLogout` stops a verified `id_token_hint` before it stages a pending request or
redirects when that session is absent, lacks its `sid`, or the hint does not match the current
subject/session. The HTML response is a plain localized `400` with `Cache-Control: no-store` and no
`Location`; it creates no logout intent and revokes no session or token. JSON keeps the protocol
error shape. The duplicate local token-revocation helper was removed so the authoritative logout
transaction owns that mutation, and an unknown commit outcome is rendered as indeterminate.

The Browser RP authority confirmation applies the same stop to a durable challenge: an absent,
different, or otherwise non-matching current IdP session leaves the challenge and all session rows
unchanged and returns the same plain localized error instead of the origin continuation.

The Browser RP launcher keeps origin continuation behind the authority-cleanup steps and the
version-one browser proof/binding. Tech has its host-local route, independent `tech.access` policy,
completion boundary, and catalog constraint. The AppTicket and OrgZenith migrations were applied
through Rails to the normal test and development databases. The current ADR, security sequence
docs, and state-transition inventory now describe the strict no-session stop and the implemented
Browser RP transitions.

## Verification

- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/oidc/logouts_controller_test.rb test/services/oidc/end_session_request_test.rb test/integration/oidc_rp_authority_first_logout_test.rb test/controllers/tech/org/sign/out/completions_controller_test.rb test/integration/routes/tech_route_contract_test.rb` — **60 runs, 508 assertions, 0 failures, 0 errors, 0 skips**.
- The authority-first subset alone passed **5 runs / 210 assertions** after the no-session and different-parent error-stop correction.
- The Base COM/ORG OIDC logout controller regression files passed **26 runs / 147 assertions**.
- The broader current Tech/Palm/Base/OIDC selection passed **111 runs, 899 assertions**; the current-session, authority-first, completion-matrix and Tech exchange selection passed **41 runs, 640 assertions**. These were executed sequentially against the same standard test database.
- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test bin/rails db:migrate:status:app_ticket` reports `20261014120000` **up**; the matching development status also reports it **up**. `db:migrate:status:org_zenith` reports `20261013184127` **up** in both environments.
- Read-only Rails runners against both environments reported `app_ticket` columns `binding_version`, `realm`, `parent_session_ref`, `captured_root_ref`, `root_refresh_family_ref`, `captured_root_generation`, and `origin_intent_digest`; constraints `acme_logout_transactions_binding_version` and `acme_logout_transactions_browser_rp_binding_shape`; and `OperatorCapabilityGrant::TECH_ACCESS` in the catalog.
- `bin/rubocop` on the 13 changed Ruby, route, migration, policy, and test files reported no offenses. `ruby -c` reported `Syntax OK` for all 13 files. Scoped `git diff --check`, including the untracked implementation files, passed.
- The earlier full prescribed Vitest run remains **100 files / 1,156 tests passed** (recorded in `evidence/2026-10-14-vitest-step19-current-ui-P8M3.md`).

## Remaining limits

The latest completed standard-database full Rails run (before this focused authority correction)
was non-clean: **15,256 runs, 128,994 assertions, 0 failures, 14 errors, 0 skips**. All 14 errors
were the Avatar committed-history worker-receipt guard refusing execution without run-owned
receipts; this is not reported as a full-suite pass, and the full run was not repeated after the
focused correction. `bin/rails db:verify_no_schema_drift` remains blocked by the pre-existing dirty
schema dumps. Tech T14's disposable up/down rehearsal and Avatar MIG-2/MIG-4 and AV-3/AV-6 checks
cannot be completed under the standard-database-only rule. BCL removal still awaits confirmation
that no external consumer exists. Frozen read-only mounts, live external keys/DNS/deployment,
real-browser acceptance, and production behavior remain unverified. `one.md` and `two.md` retain
their frozen hashes.
