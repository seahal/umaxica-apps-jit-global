# English and Japanese locale key parity

Date: 2026-10-25

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`

The worktree already contained broad staged, unstaged, and untracked changes before this task. This
verification ran against that worktree and the commit above. This task staged no files, and the CI
workflow was not modified. Existing staged state was preserved.

## Inventory and changes

Before editing, `en.yml` had 3,984 leaf keys and `ja.yml` had 3,887. The earlier WU-19 evidence
records 3,979 and 3,882 respectively, a difference of five keys in each bundle. The current
read-only inventory found 788 en-only keys and 691 ja-only keys. `i18n-tasks missing` reported two
keys absent from both locales; `i18n-tasks unused` reported 5,910 entries.

The scanner classified 40 en-only and 85 ja-only keys as used. Source inspection also confirmed 22
activity-event labels and 14 other runtime-selected keys that the unused scan could not recognize.
Twenty Japanese scalar entries representing pluralized English keys were reshaped into `.one` and
`.other` leaves, preserving their existing Japanese wording. The two keys missing from both bundles
were translated in both languages so `i18n-tasks missing` is empty.

Removed 726 confirmed unused en-only keys and 573 confirmed unused ja-only keys. No keys with an
identified runtime caller were removed. Final bundles each have 3,358 leaf keys and identical key
sets. The additions comprise 164 locale key values: 100 English and 64 Japanese. Of those values,
40 Japanese plural leaves reuse the prior scalar translations; 124 messages received new wording.

### Runtime keys retained after source inspection

- 22 activity-event labels assembled by the app and org activity log presenters.
- 8 social sign-in failure keys assembled by the app OmniAuth callback controller.
- 2 occurrence error keys raised by `OccurrenceHmac`.
- 3 visitor model labels used by validation or `human_attribute_name`.
- 1 Visa token-refresh error selected from a controller mapping.

The callers for the dynamic cases above were finite and source-checked. Other common keys still
reported unused by `i18n-tasks` were outside the one-sided key cleanup in this change.

### Untranslated or ambiguous keys

None identified in the reviewed en-only and ja-only lists.

## Verification

| Command or check | Result |
| --- | --- |
| `bundle exec i18n-tasks missing` | Passed; no missing translations. |
| `bundle exec i18n-tasks unused` | Exit 1; 4,646 per-locale entries remain reported unused. The existing CI step was not changed, as instructed. |
| `bundle exec i18n-tasks check-consistent-interpolations` | Passed; no inconsistent interpolations. |
| YAML parse and leaf-key parity check | Passed; 3,358 keys in each locale, exact parity. |
| `bin/rails test test/initializers/locale_test.rb` | Passed; 15 runs, 182 assertions. |
| `bin/rails test test/initializers/` | Passed; 39 runs, 348 assertions. |
| `PARALLEL_WORKERS=1 bin/rails test test/presenters/sign_app_settings_activity_log_presenter_test.rb test/presenters/sign_com_settings_activity_log_presenter_test.rb test/presenters/sign_org_settings_activity_log_presenter_test.rb test/controllers/auth/app/omniauth/omniauth_callbacks_controller_test.rb` | Passed; 55 runs, 99 assertions. |
| `bin/rails test test/presenters/sign_app_settings_activity_log_presenter_test.rb test/presenters/sign_com_settings_activity_log_presenter_test.rb test/presenters/sign_org_settings_activity_log_presenter_test.rb test/controllers/auth/app/omniauth/omniauth_callbacks_controller_test.rb test/integration/omniauth_callbacks_test.rb` | 65 runs; 10 errors in `test/integration/omniauth_callbacks_test.rb` while calling `.css` on a missing form. `PARALLEL_WORKERS=1 bin/rails test test/integration/omniauth_callbacks_test.rb:34` reproduced the same error. |
| `bundle exec rubocop config/initializers/locale.rb config/environments/development.rb config/environments/production.rb config/environments/test.rb test/initializers/locale_test.rb` | Passed; 5 files, no offenses. |
| `git diff --check` | Passed. |
| `bundle exec rails runner -e production 'I18n.t("production_i18n_missing_probe")'` | Could not boot: required `BASE_SERVICE_URL` is absent. Production runtime behavior was not directly exercised. |

Development and test retain their strict missing-translation settings; production retains
`config.i18n.raise_on_missing_translations = true`. With the cross-language fallback removed, a
missing production key is configured to raise rather than return the other locale. The production
runner check remains unverified because boot stopped at the required environment configuration.

The exact final `i18n-tasks unused` command still fails because many common entries remain outside
this task's one-sided cleanup. The added dynamic translations remain source-verified, but step 5's
CI/configuration changes were left untouched per instruction.

## New locale values for review

The table below lists every locale key value added to the bundles, including reused Japanese text
for the plural leaves.

| Key | Language | Text |
| --- | --- | --- |
| actions.submit | en | Submit |
| actions.update | en | Update |
| activerecord.attributes.staff_email.address | en | Email address |
| activerecord.attributes.staff_email.status | en | Status |
| activerecord.attributes.staff_secret_credential.created_at | en | Created at |
| activerecord.attributes.staff_secret_credential.last_used_at | en | Last used at |
| activerecord.attributes.staff_secret_credential.name | en | Name |
| activerecord.attributes.staff_secret_credential.value | en | Value |
| activerecord.attributes.staff_telephone.number | en | Telephone number |
| activerecord.attributes.staff_telephone.status | en | Status |
| activerecord.attributes.user_telephone.status | en | Status |
| activerecord.attributes.visitor_passkey.description | en | Description |
| activerecord.attributes.visitor_passkey.sign_count | en | Sign count |
| activerecord.attributes.visitor_secret_credential.name | en | Name |
| auth.org.sign.up.invitations.create.turnstile_failed | en | Security verification failed. Please try again. |
| base.app.secrets.reattempt | en | Issue again |
| base.app.sign.in.limitations.capacity_still_full | en | Session capacity is still full. Revoke another session to continue. |
| base.app.sign.in.limitations.revoke_failed | en | The session could not be revoked. |
| errors.forbidden | en | Access is forbidden. |
| errors.messages.already_authenticated | en | You are already signed in. |
| errors.messages.login_required | en | You must sign in. |
| errors.messages.not_authorized | en | You are not authorized to perform this action. |
| errors.occurrence.invalid_telephone_format | en | The phone number must be in E.164 format. |
| errors.occurrence.missing_hmac_secret_credential | en | The HMAC secret credential is not configured. |
| messages.totp_credential_default_label | en | Authenticator app %{count} |
| messages.totp_credential_label | en | Authenticator app |
| messages.totp_title_placeholder | en | Title (optional) |
| session_limit.edit.cancel_logout | en | Cancel and sign out. |
| sign.app.authentication.email.create.invalid_format | en | Invalid email address format. |
| sign.app.authentication.email.edit.code_label | en | Verification code |
| sign.app.authentication.email.edit.code_placeholder | en | Enter the 6-digit code |
| sign.app.authentication.email.edit.delivery_help | en | If it doesn't arrive within a minute, check your email address and mail settings, then try again. |
| sign.app.authentication.email.edit.description | en | Almost done. Enter the 6-digit verification code sent to your email address. |
| sign.app.authentication.email.edit.page_title | en | Enter verification code |
| sign.app.authentication.email.update.invalid_code | en | Invalid verification code. |
| sign.app.common.cancel | en | Cancel |
| sign.app.in.mfa.methods.totp | en | Authenticate with an authenticator app (TOTP). |
| sign.app.registration.email.flow.invalid | en | Your session has expired. |
| sign.app.registration.email.new.link_to_sign_in | en | Sign in? |
| sign.app.registration.telephone.edit.code_label | en | Verification code |
| sign.app.registration.telephone.edit.code_placeholder | en | Enter the 6-digit code |
| sign.app.registration.telephone.edit.delivery_help | en | If it doesn't arrive within a minute, check the phone number and SMS settings, then try again. |
| sign.app.registration.telephone.edit.page_title | en | Enter verification code |
| sign.app.registration.telephone.edit.submit | en | Submit |
| sign.app.registration.telephone.new.link_to_other_methods | en | Use another sign-up method? |
| sign.app.registration.telephone.new.link_to_sign_in | en | Sign in? |
| sign.app.registration.telephone.new.page_title | en | Sign up with a phone number |
| sign.app.settings.email.new.page_title | en | Add an email address |
| sign.app.settings.totp.new.description | en | Set up an authenticator app (such as Google Authenticator). |
| sign.app.settings.totp.new.page_title | en | Set up TOTP |
| sign.app.settings.totp.new.title_hint | en | Example: Work phone |
| sign.app.settings.totps.invalid_code | en | Invalid verification code. |
| sign.app.social.sessions.failure.access_denied | en | Access was denied. |
| sign.app.social.sessions.failure.invalid_client | en | Apple sign-in is misconfigured. Please contact support. |
| sign.app.social.sessions.failure.invalid_credentials | en | The credentials are invalid. |
| sign.app.social.sessions.failure.invalid_grant | en | Apple sign-in has expired. Please try again. |
| sign.app.social.sessions.failure.invalid_redirect_uri | en | The Apple sign-in redirect URL is misconfigured. |
| sign.app.social.sessions.failure.invalid_request | en | The request to Apple is invalid. Please try again. |
| sign.app.social.sessions.failure.timeout | en | The request timed out. |
| sign.app.social.sessions.failure.unknown_error | en | An unknown error occurred. |
| sign.app.verification.edit.email_delivery_help | en | If it doesn't arrive within a minute, check your email address and mail settings, then try again. |
| sign.app.verification.edit.totp_help | en | Verification codes refresh periodically. If a code doesn't work, enter the latest code shown in your authenticator app. |
| sign.app.verification.errors.incorrect_code | en | The verification code is incorrect. |
| sign.com.authentication.email.create.invalid_format | en | Invalid email address format. |
| sign.com.authentication.email.edit.code_label | en | Verification code |
| sign.com.authentication.email.edit.code_placeholder | en | Enter the 6-digit code |
| sign.com.authentication.email.edit.delivery_help | en | If it doesn't arrive within a minute, check your email address and mail settings, then try again. |
| sign.com.authentication.email.edit.description | en | Almost done. Enter the 6-digit verification code sent to your email address. |
| sign.com.authentication.email.edit.page_title | en | Enter verification code |
| sign.com.authentication.email.edit.return_page | en | Back |
| sign.com.authentication.email.update.invalid_code | en | Invalid verification code. |
| sign.com.in.mfa.description | en | Choose an authentication method. |
| sign.com.in.mfa.no_methods_available | en | No authentication methods are available. Contact support. |
| sign.com.in.mfa.passkey.authenticate | en | Authenticate with a passkey. |
| sign.com.in.mfa.passkey.back | en | Back to authentication methods. |
| sign.com.in.mfa.passkey.description | en | Authenticate with a registered passkey. |
| sign.com.in.mfa.passkey.title | en | Passkey verification |
| sign.com.in.mfa.title | en | Additional authentication is required. |
| sign.com.registration.email.new.link_to_sign_in | en | Sign in? |
| sign.com.registration.telephone.edit.code_label | en | Verification code |
| sign.com.registration.telephone.edit.code_placeholder | en | Enter the 6-digit code |
| sign.com.registration.telephone.edit.delivery_help | en | If it doesn't arrive within a minute, check the phone number and SMS settings, then try again. |
| sign.com.registration.telephone.edit.page_title | en | Enter verification code |
| sign.com.registration.telephone.edit.submit | en | Submit |
| sign.com.registration.telephone.new.link_to_other_methods | en | Use another sign-up method? |
| sign.com.registration.telephone.new.link_to_sign_in | en | Sign in? |
| sign.com.registration.telephone.new.page_title | en | Sign up with a phone number |
| sign.com.verification.edit.email_delivery_help | en | If it doesn't arrive within a minute, check your email address and mail settings, then try again. |
| sign.com.verification.errors.incorrect_code | en | The verification code is incorrect. |
| sign.org.exits.destroy.success | en | Sign out |
| sign.org.exits.edit.title | en | Do you want to sign out? |
| sign.org.verification.setup.description | en | Before you continue, register a passkey or an authenticator app. |
| sign.token_refresh.errors.invalid_refresh_token | en | The refresh token is invalid or expired. |
| sign.token_refresh.errors.missing_refresh_token | en | A refresh token is required. |
| sign.token_refresh.errors.withdrawal_required | en | The account withdrawal process has not been completed. |
| test.email.com.application_mailer.subject | en | Corporate sample |
| test.email.org.application_mailer.subject | en | Organization sample |
| views.sign.app.settings.totps.new.first_token_delivery_help | en | Verification codes refresh periodically. If a code doesn't work, enter the latest code shown in your authenticator app. |
| views.sign.app.settings.totps.new.first_token_placeholder | en | Enter the 6-digit code |
| views.sign.app.settings.totps.new.submit | en | Submit |
| auth.app.settings.activity.events.email_registered | ja | メールアドレスを登録しました |
| auth.app.settings.activity.events.email_removed | ja | メールアドレスを削除しました |
| auth.app.settings.activity.events.logged_in | ja | ログインしました |
| auth.app.settings.activity.events.logged_out | ja | ログアウトしました |
| auth.app.settings.activity.events.login_success | ja | ログインに成功しました |
| auth.app.settings.activity.events.logout | ja | ログアウトしました |
| auth.app.settings.activity.events.passkey_registered | ja | パスキーを登録しました |
| auth.app.settings.activity.events.recovery_codes_generated | ja | リカバリーコードを生成しました |
| auth.app.settings.activity.events.session_revoked | ja | セッションを無効化しました |
| auth.app.settings.activity.events.signed_up_with_apple | ja | Appleで登録しました |
| auth.app.settings.activity.events.signed_up_with_email | ja | メールアドレスで登録しました |
| auth.app.settings.activity.events.signed_up_with_google | ja | Googleで登録しました |
| auth.app.settings.activity.events.signed_up_with_telephone | ja | 電話番号で登録しました |
| auth.app.settings.activity.events.social_linked | ja | ソーシャルアカウントを連携しました |
| auth.app.settings.activity.events.social_unlinked | ja | ソーシャルアカウントの連携を解除しました |
| auth.app.settings.activity.events.telephone_registered | ja | 電話番号を登録しました |
| auth.app.settings.activity.events.telephone_removed | ja | 電話番号を削除しました |
| auth.app.settings.activity.events.totp_enabled | ja | 認証アプリを登録しました |
| auth.app.settings.activity.events.user_secret_credential_created | ja | シークレットを作成しました |
| auth.org.settings.activity.events.logged_in | ja | ログインしました |
| auth.org.settings.activity.events.login_success | ja | ログインに成功しました |
| auth.org.settings.activity.events.social_unlinked | ja | ソーシャルアカウントの連携を解除しました |
| datetime.distance_in_words.about_x_hours.one | ja | 約%{count}時間 |
| datetime.distance_in_words.about_x_hours.other | ja | 約%{count}時間 |
| datetime.distance_in_words.about_x_months.one | ja | 約%{count}ヶ月 |
| datetime.distance_in_words.about_x_months.other | ja | 約%{count}ヶ月 |
| datetime.distance_in_words.about_x_years.one | ja | 約%{count}年 |
| datetime.distance_in_words.about_x_years.other | ja | 約%{count}年 |
| datetime.distance_in_words.almost_x_years.one | ja | %{count}年弱 |
| datetime.distance_in_words.almost_x_years.other | ja | %{count}年弱 |
| datetime.distance_in_words.less_than_x_minutes.one | ja | %{count}分未満 |
| datetime.distance_in_words.less_than_x_minutes.other | ja | %{count}分未満 |
| datetime.distance_in_words.less_than_x_seconds.one | ja | %{count}秒未満 |
| datetime.distance_in_words.less_than_x_seconds.other | ja | %{count}秒未満 |
| datetime.distance_in_words.over_x_years.one | ja | %{count}年以上 |
| datetime.distance_in_words.over_x_years.other | ja | %{count}年以上 |
| datetime.distance_in_words.x_days.one | ja | %{count}日 |
| datetime.distance_in_words.x_days.other | ja | %{count}日 |
| datetime.distance_in_words.x_minutes.one | ja | %{count}分 |
| datetime.distance_in_words.x_minutes.other | ja | %{count}分 |
| datetime.distance_in_words.x_months.one | ja | %{count}ヶ月 |
| datetime.distance_in_words.x_months.other | ja | %{count}ヶ月 |
| datetime.distance_in_words.x_seconds.one | ja | %{count}秒 |
| datetime.distance_in_words.x_seconds.other | ja | %{count}秒 |
| datetime.distance_in_words.x_years.one | ja | %{count}年 |
| datetime.distance_in_words.x_years.other | ja | %{count}年 |
| errors.messages.too_long.one | ja | は%{count}文字以内で入力してください |
| errors.messages.too_long.other | ja | は%{count}文字以内で入力してください |
| errors.messages.too_short.one | ja | は%{count}文字以上で入力してください |
| errors.messages.too_short.other | ja | は%{count}文字以上で入力してください |
| errors.messages.wrong_length.one | ja | は%{count}文字で入力してください |
| errors.messages.wrong_length.other | ja | は%{count}文字で入力してください |
| errors.template.header.one | ja | %{model}に%{count}個のエラーが発生しました |
| errors.template.header.other | ja | %{model}に%{count}個のエラーが発生しました |
| help.app.contacts.new.error_heading.one | ja | %{count}件のエラーがあるため送信できません。 |
| help.app.contacts.new.error_heading.other | ja | %{count}件のエラーがあるため送信できません。 |
| help.com.contacts.new.error_heading.one | ja | %{count}件のエラーがあるため送信できません。 |
| help.com.contacts.new.error_heading.other | ja | %{count}件のエラーがあるため送信できません。 |
| help.org.contacts.new.error_heading.one | ja | %{count}件のエラーがあるため送信できません。 |
| help.org.contacts.new.error_heading.other | ja | %{count}件のエラーがあるため送信できません。 |
| number.human.storage_units.units.byte.one | ja | バイト |
| number.human.storage_units.units.byte.other | ja | バイト |
| sign.org.exits.destroy.success | ja | ログアウトします |
| sign.org.exits.edit.title | ja | ログアウトしますか？ |
