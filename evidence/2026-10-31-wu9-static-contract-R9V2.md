# WU-9 static contract work

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes: 61 staged, 2,676 unstaged, and 901 untracked entries immediately before this evidence file was added. No commit was created.
- Updated Auth/Core/Warp Preference browser contracts to remain read-only, including the registry, API refusal guard, consent GET behavior, and browser chrome tests. Added assertions that reader hosts do not issue Preference state cookies or create Preference rows.
- Updated the Auth APP/ORG ERB layouts to omit interactive theme and cookie controls when the registry grants no writer capability.
- Removed Base com's request-actor hydration of consent and Web Push from the preference database. Updated its integration contract to expect the API response to expose bound Web Push while the request Actor retains its display-only default.
- Removed the remaining runtime read of the retired `ct` item cookie from the page theme helper; layouts now derive their theme from the request Actor display value. Updated helper and Visa landing contracts for the current source.
- Updated current Preference architecture documentation to describe the display-only Actor projection and Base-owned browser controls.
- Ruby syntax validation passed for 29 specifically listed changed application and test files (`ruby -c`); the two changed Auth ERB layouts compiled successfully in a method context. Scoped staged and unstaged `git diff --check` completed without output.
- Static source scans found no runtime references under `app/` to `PreferenceAdoption`, Preference refresh/DBSC/assurance, the old consent buffer, actor-consent hydration, or reads of retired item cookies; no `adult_content_gate` references were found in controller/helper/view/value/service/policy/operation/resolver code.
- The first focused `bin/rails test` invocation stopped at boot because local `PREFERENCE_COM_JWT_*` metadata was absent. The retry supplied the required process-local issuer, audience, and revoked-kids values; `db:test:prepare` then attempted the pending WU-9 cutover and stopped at `CutOverClientPreferenceShape#require_empty_table!` because `client_preferences` had rows. No test bodies ran.
- A subsequent read-only `RAILS_ENV=test bin/rails runner -` inventory found 2 parent rows in each of `test_app_setting_db`, `test_org_setting_db`, `test_app_zenith_db`, and `test_org_zenith_db`; none of the four WU-9 cutover versions was recorded, and all four tables retained their legacy columns. The guard prevented cutover; no destructive WU-9 schema change occurred.
- The execution ticket still requires owner approval before any destructive migration. Runtime acceptance against the target schema and the closing full suite remain unverified. Production and Neon were not accessed.

### Final read-only source check (2026-10-31)

- HEAD remained `336811e5072a93c0523e484f905082635b28f48f`; the worktree remained uncommitted, with 2,724 tracked status entries and 902 untracked entries. No files were changed during this final check.
- A runtime-source scan excluding `app/models` found no `PreferenceAdoption`, old Preference refresh/DBSC/assurance identifiers, old actor-consent hydration, or `adult_content_gate` references. Literal reads of the retired item-cookie keys (`ct`, `ci`, `ia`, `lc`, `lg`, `th`, `tz`, `cu`, `df`, `tf`, `mo`, `de`, `ps`) were also absent from `app/`.
- A whole-worktree `git diff --check` now reports trailing whitespace at `Gemfile:209` in the existing unstaged Gemfile diff. Gemfile was not changed as part of WU-9 and was left untouched; the prior scoped check had completed without output.
- The execution ticket remains marked as requiring owner approval. No Rails tests, migration, row cleanup, restore, or schema mutation were performed in this final check.

### Continued WU-9 implementation (2026-10-31)

- HEAD remained `336811e5072a93c0523e484f905082635b28f48f`; the worktree remains uncommitted with 2,725 tracked status entries and 902 untracked entries. No commit was created. `AGENTS.md`, `one.md`, `three.md`, and `two.md` were not edited.
- Visa sign-out now copies all stored anonymous display children, including `region`, while Visa sign-in still excludes account `region`. The APP/ORG status diagrams and transition inventory now state this distinction.
- Added APP/ORG integration coverage for explicit Visa sign-in, region exclusion, Preference issuance failure after authentication, sign-out copying DB display/consent/receipt/Web Push/binding state despite a conflicting signed display projection, rollback when receipt copy fails after logout commits, and Base reset retiring both anonymous and actor Preference rows while reissuing shared cookies and expiring the binding cookie.
- Updated test callers from the old `user_id`/`staff_id` Preference columns to `client_id`/`operator_id`. Removed application branches that treated persisted `explicit_fields = NULL` as a special state; explicit display methods now use only the required explicit field list and do not infer values from child presence. Updated current architecture text for the owner decision.
- `ruby -c` passed for 10 changed Ruby implementation and test files. Scoped `git diff --check` passed. Runtime scans over controllers/helpers/views/services/policies found no retired Preference adoption/refresh/DBSC/assurance, consent-mirror, or dormant adult-gate references; the retired item-cookie reads and explicit-fields NULL branches were also absent.
- These newly added/updated integration tests were not executed. The prior focused test command stopped in `db:test:prepare` at the empty-table guard because the local test Preference tables contain rows. The current task requires execution-ticket approval before migrations, so no test database rows were cleared and no migration, restore, or schema change was run. The 3-realm runtime AC and closing full suite remain unverified.
