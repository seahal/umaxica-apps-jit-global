# WU-7 slice 4: D-57 browser binding digest — schema, minting, re-binding, constant-time read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; nothing committed; worktree = WU-3..WU-7-slice-3
  plus this slice.
- Scope: two.md section 4.7's binding transport on the com consent write: schema column, minting at
  the consent grant, re-binding of a presented well-formed value, and the constant-time read
  predicate. Web Push options rows and the Visa-side copy of the binding record are later slices.

## Code

- Migration `db/com_settings_migrate/20261029213000_add_preferences_browser_binding_digests.rb`:
  adds `com_preference_cookies.browser_binding_digest` (string 64) plus a unique
  `idx_com_pref_cookies_on_binding_digest` index (`algorithm: :concurrently`,
  `disable_ddl_transaction!`; strong_migrations clean). Applied to the test com_setting DB and
  verified: the column exists via information_schema. The `down` removes index and column.
- `app/controllers/concerns/preference_browser_binding.rb` — new concern (included from
  `PreferenceBase`):
  - `PreferenceBrowserBinding.mint_value` — 32-byte CSPRNG via `SecureRandom.urlsafe_base64(32)`
    (43 chars, URL-safe alphabet), `digest_for` = SHA-256 hex (64 chars);
  - `matches?(raw, digest)` — well-formedness first, then
    `ActiveSupport::SecurityUtils.secure_compare` (constant time);
  - `ensure_browser_binding_cookie!(cookie_record)` — re-binds a presented well-formed cookie value
    as-is, mints a fresh one otherwise; persists only the digest on the cookie row and queues the
    host-only cookie (`PreferenceCookieName.binding`, `CoreCookieOptions` → no `Domain`, `path=/`,
    httponly, SameSite=Lax, 400-day TTL); read paths never mint or extend.
- `PreferenceIoKeys::Cookies::BINDING_BASENAME` and `PreferenceCookieName.binding` (`__Host-`
  prefix under `JitSessionCookieConfig.force_secure?`, bare name in test).
- `ComPreferenceCookie` — format validation `DIGEST_FORMAT = /\A[0-9a-f]{64}\z/` on
  `browser_binding_digest` (allow nil: no consent grant → no binding).
- `update_preference_cookie_dual_write!` — after the dual-write commit, a consent grant
  (`consented` truthy in the submitted params) mints/re-binds the binding on the same request.

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/preference_browser_binding_test.rb`:
  4 runs, 17 assertions, 0 failures, 0 errors (mint format/uniqueness; match/mismatch/blank bounds;
  digest format acceptance/rejection through the model validation with a fresh preference; cookie
  name shape `__Host-preference_binding` vs `preference_binding` under the secure-mode switch).
- Combined slice regression: `bin/rails test test/controllers/concerns/preference_browser_binding_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb test/values/anonymous_com_preference_token_shape_test.rb test/values/anonymous_com_preference_payload_build_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb`
  → 33 runs, 147 assertions, 0 failures, 0 errors.
- Rubocop `-A` over the eight touched files; `preference_browser_binding.rb` ends "no offenses";
  `ruby -c` passes on every edited file.

## Not in this slice

- Web Push option/child-record tables (section 4.3 columns); Visa sign-out copy of the binding
  record (WU-9); GET-time read wiring for the com consent endpoints (section 4.7's read half —
  `browser_binding_matches?` is provided and unexercised by controllers yet).

## Schema dump after the migration

- `bin/rails db:schema:dump:com_setting` regenerated `db/com_setting_structure.sql`; the new
  `browser_binding_digest character varying(64)` column and
  `idx_com_pref_cookies_on_binding_digest` index are in the dump. A direct normalized diff of the
  committed dump against a fresh dump (`SCHEMA=/tmp/com_setting_fresh.sql`) reports **0 lines** of
  difference — the committed com_setting dump is exact for the migration-built state.
- `bin/rails db:verify_no_schema_drift` still over-reports on the live test fleet (the pre-existing
  HMAC-definer role-digest mismatch recorded in the WU-5 removal ticket: live test databases carry
  development-digest role names through the ParallelTestDatabaseCloner template copies). The drift
  task's role normalizer expects the digest of each *test* database name; the mismatch is a
  live-database artifact, not a committed-dump drift. Recorded; not silently "fixed".
