# i18n parity repair and production missing-translation handling

Date: 2026-10-25

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`

The worktree already had broad staged, unstaged, and untracked changes before this task. This work
ran against that worktree. No files were staged or committed; existing staged state was preserved.

## Changes

- Restored 18 source-backed keys in both `en.yml` and `ja.yml` (36 locale values total), bringing
  each bundle to 3,376 leaf keys with exact parity.
- Replaced the fake `sign.withdrawal.test` key in
  `test/errors/sign/withdrawal_error_test.rb` with the real
  `sign.withdrawal.errors.deletion_failed` key used by the application.
- Replaced an English message-text assertion in the retired `AcmeLogoutTransaction` validation test
  with an assertion on the public error type (`:inclusion`); the test runs under Japanese locale and
  had been comparing against English copy. Added the matching Active Record attribute label in both
  locales so validation details can still render a human-readable field name.
- Production now uses `config.i18n.raise_on_missing_translations = false`. The initializer wraps
  Rails' existing I18n exception handler and emits one `i18n.missing_translation` structured warning
  per missing translation call through `JitLogEvent`, containing only the normalized key and locale.
  Development and test keep the existing raising behavior. The locale initializer keeps identity
  fallbacks (`en` to `en`, `ja` to `ja`); production does not fall back to the other language.
- Updated `docs/architecture/i18n.md` and added
  `docs/backlog/2026-10-25-i18n-unused-keys.md`.

## Dynamic translation inventory

The inventory below records dynamic construction or selection found in `app/` and `lib/`, the
translation namespace it can emit, and whether the cleanup had deleted a live result.

| Source | Dynamic key shape or selection | Cleanup result |
| --- | --- | --- |
| `app/controllers/auth/app/sign/in/emails_controller.rb` | `sign.app.authentication.{new,email.new,email.edit}.*` from controller scopes | Restored live `sign.app.authentication.email.edit.return_page`; no active emitter for deleted `email.edit.session_expired`. |
| `app/controllers/auth/app/sign/in/challenges_controller.rb` | `sign.app.in.mfa.{title,description,methods.passkey,no_methods_available}` | Restored the deleted live `description`, `title`, and `no_methods_available`; `methods.passkey` was not deleted. |
| `app/controllers/auth/app/sign/in/challenge/passkeys_controller.rb` | `sign.app.in.mfa.passkey.{title,description,authenticate,back}` | Restored all four deleted live keys. |
| `app/controllers/auth/app/sign/ins_controller.rb`, `app/controllers/auth/app/sign/in/passkeys_controller.rb` | `sign.app.authentication.new.*` and `sign.app.authentication.passkey.new.*` | No deleted live result. |
| `app/controllers/auth/app/sign/up/check/{apple,google}/confirmations_controller.rb`, `app/controllers/concerns/app_sign_up_checkpoint_page.rb` | `sign.app.registration.checkpoint.show.*` | No deleted live result. |
| `app/controllers/concerns/surface_chrome.rb` | `layouts.shared.restricted_mode.*`, `layouts.shared.footer_cookie_controls.*`, `layouts.shared.footer_theme_controls.*` | No deleted live result. |
| `app/controllers/concerns/base_preference_screen_page.rb` | `acme.com.preference.<screen>.edit.{description,heading,option_label}` for selectable screens | Restored the deleted live `currency`, `date_format`, and `time_format` triplets (9 keys). Other emitted screen keys were present. |
| `app/controllers/concerns/preference_core.rb` | `acme.<surface>.preference.<type>.options.<catalog_value>` | Fixed screen and catalog option selection; no other deleted live result. |
| `app/presenters/auth/{app,com,org}/settings/activity_log_presenter.rb` | `auth.<surface>.settings.activity.events.<mapped_event>` selected by `EVENT_LABELS` | Finite event maps reviewed; no deleted live result. |
| `app/presenters/base/identity/activity_log_presenter.rb` | Activity and risk keys selected from identity/risk mappings; unknown-activity/location labels use fixed keys | No deleted live result. |
| `app/presenters/base/identity/session_presenter.rb` | `base.shared.identity.sessions.<current-or-active>` and `.sessions.<mode>` | Finite status/mode selection reviewed; no deleted live result. |
| `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb` | `sign.app.social.sessions.failure.<mapped_provider_error>` | Fixed failure mapping reviewed; no deleted live result. |
| `app/controllers/visa/{app,com,org}/edge/v0/token/refreshes_controller.rb` | `sign.token_refresh.errors.<mapped_error_code>` | Fixed error maps reviewed; no deleted live result. |
| `app/controllers/concerns/passkey_sign_in_flow.rb` | `message_key` selected from passkey result/error mapping | No deleted live result. |
| `app/controllers/concerns/sign_up_sequence_controller_support.rb` | Birthdate, registration, and telephone-passkey error keys selected from fixed mappings | No deleted live result. |
| `app/controllers/concerns/sign_entry_sentry_enforcement.rb` | `errors.messages.<selected_sign_in_or_sign_up_unavailable>` | Current emitted values are present; no deleted live result. |
| `app/mailers/email/{app,com}/otp_mailer.rb` | Subject translation key selected by the OTP mail type | Fixed subject maps reviewed; no deleted live result. |
| `app/errors/application_error.rb` and its subclasses | Each subclass passes an explicit translation key to `I18n.t` | Application error call sites reviewed; no deleted live result from the locale cleanup. |
| Active Record validation for `AcmeLogoutTransaction#workflow` | Rails resolves `activerecord.attributes.acme_logout_transaction.workflow` for a human-readable error field | Added the missing English and Japanese attribute labels after the full-suite run exposed it. |
| `app/views/layouts/shared/_footer_theme_controls.html.erb`, `app/views/layouts/shared/_footer_cookie_controls.html.erb`, `app/controllers/auth/org/sign/up/invitations_controller.rb`, `app/controllers/base/app/identity/privacy/erasure/statuses_controller.rb` | Relative translation calls scoped to the view/controller | Reviewed; no deleted live key. |

The scan found no client-side translation helper in `src/` or `app/javascript`. Inertia `scope`
props in React forms name request parameters and are not translation prefixes. Direct translation
calls found under `lib/` use literal keys; no dynamic user-facing key prefix there matched a deleted
live key.

### Reviewed deleted candidates not restored

These removed descendants had no current emitted suffix at the inspected call sites, so they were
not restored speculatively:

- `sign.app.authentication.edit.title`, `email.create.locked`, `email.edit.session_expired`,
  `email.update.success`, `new.back_to_root`, `passkey.already_logged_in`, and
  `passkey.new.{email_label,email_placeholder}`.
- `sign.app.in.mfa.required`, `session_expired`, and `totp.{back,description,help,submit,title,
  token_label,token_placeholder}`; the current MFA flow emits the restored challenge/passkey keys,
  and no current TOTP challenge controller emits these descendants.
- `auth.app.settings.secret_credentials.*` and `auth.org.settings.secret_credentials.*`; current
  credential-management screens use Base namespaces and no current Auth call site was found.
- `errors.messages.credential_already_registered`, `extension_allowlist_error`,
  `validation_failed`, `webauthn.credential_already_registered`, and `webauthn.no_passkey`; no
  current `app/` or `lib/` caller was found. Ownership by an external runtime remains unverified.

## Locale values for owner review

This table lists every locale value added by this repair, including the Japanese copies newly written
or checked for namespace consistency.

| Key | Language | Text |
| --- | --- | --- |
| activerecord.attributes.acme_logout_transaction.workflow | en | Workflow |
| activerecord.attributes.acme_logout_transaction.workflow | ja | ワークフロー |
| acme.com.preference.currency.edit.description | en | Choose the currency used for regional display. |
| acme.com.preference.currency.edit.description | ja | 表示に使う通貨を選択します。 |
| acme.com.preference.currency.edit.heading | en | Currency |
| acme.com.preference.currency.edit.heading | ja | 通貨設定 |
| acme.com.preference.currency.edit.option_label | en | Currency |
| acme.com.preference.currency.edit.option_label | ja | 通貨 |
| acme.com.preference.date_format.edit.description | en | Choose how dates are displayed. |
| acme.com.preference.date_format.edit.description | ja | 表示する日付形式を選択します。 |
| acme.com.preference.date_format.edit.heading | en | Date Format |
| acme.com.preference.date_format.edit.heading | ja | 日付形式 |
| acme.com.preference.date_format.edit.option_label | en | Date format |
| acme.com.preference.date_format.edit.option_label | ja | 日付形式 |
| acme.com.preference.time_format.edit.description | en | Choose how times are displayed. |
| acme.com.preference.time_format.edit.description | ja | 表示する時刻形式を選択します。 |
| acme.com.preference.time_format.edit.heading | en | Time Format |
| acme.com.preference.time_format.edit.heading | ja | 時刻形式 |
| acme.com.preference.time_format.edit.option_label | en | Time format |
| acme.com.preference.time_format.edit.option_label | ja | 時刻形式 |
| sign.app.authentication.email.edit.return_page | en | Back |
| sign.app.authentication.email.edit.return_page | ja | 戻る |
| sign.app.in.mfa.description | en | Choose an authentication method. |
| sign.app.in.mfa.description | ja | 認証方法を選択してください。 |
| sign.app.in.mfa.no_methods_available | en | No authentication methods are available. Contact support. |
| sign.app.in.mfa.no_methods_available | ja | 利用可能な認証方法がありません。サポートにお問い合わせください。 |
| sign.app.in.mfa.title | en | Additional authentication is required. |
| sign.app.in.mfa.title | ja | 追加の認証が必要です |
| sign.app.in.mfa.passkey.authenticate | en | Authenticate with a passkey. |
| sign.app.in.mfa.passkey.authenticate | ja | パスキーで認証 |
| sign.app.in.mfa.passkey.back | en | Back to authentication methods. |
| sign.app.in.mfa.passkey.back | ja | 認証方法の選択に戻る |
| sign.app.in.mfa.passkey.description | en | Authenticate with a registered passkey. |
| sign.app.in.mfa.passkey.description | ja | 登録済みのパスキーで認証してください。 |
| sign.app.in.mfa.passkey.title | en | Passkey verification |
| sign.app.in.mfa.passkey.title | ja | パスキーによる確認 |

## Verification

| Command or check | Result |
| --- | --- |
| `bundle exec i18n-tasks missing` | Passed; no translations missing. |
| YAML parse and leaf-key parity | Passed; 3,376 keys in each locale, exact parity. |
| `bundle exec i18n-tasks unused` | Exit 1; 4,682 locale entries remain reported unused. See the backlog entry. |
| `bin/rails test test/initializers/` | Passed on the final locale state: 39 runs, 348 assertions, 0 failures/errors/skips. |
| Eight specified authentication/social files | Passed on the final state: 124 runs, 2,638 assertions, 0 failures/errors/skips. |
| `bin/rails test test/models/acme_logout_transaction_test.rb:63` | Passed after making its inclusion assertion locale-independent: 1 run, 2 assertions. The first rerun exposed that the former assertion compared Japanese validation text to an English literal; it was changed to assert the error type without relying on the locale. |
| First `bin/rails test` run | 18,312 runs, 152,157 assertions, 191 failures, 300 errors; the failure report exposed the missing Active Record attribute label and the language-specific test assertion. |
| Final `bin/rails test` run | Exit 1; 18,312 runs, 152,192 assertions, 189 failures, 304 errors, 0 skips. `MissingTranslationData` count: **0**. Failures and errors remain in the broad worktree; sampled failures include integration form lookups returning `nil` and a host expectation mismatch. The final log had no failure entry for the changed withdrawal test, the adjusted `AcmeLogoutTransaction` test, or initializer tests. |
| `bundle exec rails runner -e production 'I18n.t("production_i18n_missing_probe")'` | Could not boot because required `BASE_SERVICE_URL` is absent. Production rendering/log behavior was not directly exercised. |
| CI workflow edit | Not completed. `.github/workflows/ci.yml` is on a read-only ZFS mount (`ro`); writes were rejected. The current workflow still runs both `i18n-tasks missing` and `i18n-tasks unused`. No CI step was staged or otherwise modified. |
| `git diff --check` on changed tracked implementation/docs/test files | Passed after the final edits. |

The implementation sets production missing translations to Rails' normal missing-translation output
and logs the key and locale once per call. The runner could not reach that production code path
without the required environment configuration, so deployed behavior remains unverified.
