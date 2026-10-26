# WU-19 locale bundle merge (D-113)

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree had many uncommitted changes from
  other in-progress work; the four former bundles were staged-modified, and their index content was
  the merge input.
- Change: `config/locales/{jp,us}/{en,ja}.yml` (and the empty `config/locales/ww/.keep`) were
  replaced by `config/locales/en.yml` and `config/locales/ja.yml`. Keys are sorted alphabetically.
  `config/initializers/locale.rb` now expects exactly `en.yml` and `ja.yml`;
  `test/initializers/locale_test.rb`, `config/i18n-tasks.yml` and `docs/architecture/i18n.md` were updated.

## Merge input

| Language | jp keys | us keys | jp only | us only | Same key, different text |
| -------- | ------- | ------- | ------- | ------- | ------------------------ |
| en       | 3500    | 3558    | 421     | 479     | 36                       |
| ja       | 3714    | 3357    | 526     | 169     | 78                       |

Keys in only one region were kept. `ja.auth.org.settings` was `null` in us and a mapping in jp; the
jp mapping was kept. Before the merge, the load order (us after jp) meant the us text was served for
every differing key; keys resolved to jp below therefore change visible text.

Result: `en.yml` 3979 leaf keys, `ja.yml` 3882 leaf keys. 788 keys exist only in en and 691 only
in ja. That asymmetry already existed before the merge and is not resolved here.

## Choice rule

The more accurate and complete text wins; jp is the default at equal quality. us was chosen when it
named the screen's real purpose (Email settings page, ORG withdrawal not self-service, sign-in
code submit), when it was consistent with sibling keys (preference resets, plural footer labels,
IANA time zone labels used by the other zone options), or when an existing test fixed the contract
(`languages.japanese` is shown in its native name; sign-up telephone OTP copy names the telephone
number). jp was chosen where us reused authenticator-app or sign-up copy for an unrelated screen
(Step-Up, verification, passkey sign-in, Email sign-in title).

## Differing keys (114: 80 jp, 34 us)

| Key | jp | us | Chosen |
| --- | -- | -- | ------ |
| en.acme.app.preference.cookie.edit.accept_necessary_cookies | Allow necessary cookies (required) | Allow strictly necessary cookies (required) | us |
| en.acme.app.preference.date_format.edit.description | Choose how dates are displayed in the application. | Select the date format used by the application. | jp |
| en.acme.app.preference.date_format.edit.option_label | Date format | Date Format | jp |
| en.acme.app.preference.resets.back | Back to preferences | Back to Preferences | jp |
| en.acme.app.preference.resets.description | Remove saved preference data for this browser. | Remove saved preference cookies for this browser. | jp |
| en.acme.app.preferences.footer.cookie | Cookie | Cookies | us |
| en.acme.app.preferences.footer.preference | Preference | Preferences | us |
| en.base.com.preference.resets.back | Back to settings list | Back to Preferences | us |
| en.base.com.preference.resets.button | Reset Settings | Clear preference data | us |
| en.base.com.preference.resets.confirm | Are you sure? | This action deletes saved preference data for this browser. Continue? | us |
| en.base.com.preference.resets.description | Delete the settings data stored in this browser. | Remove saved preference cookies for this browser. | us |
| en.base.com.preference.resets.destroyed | Settings reset | Preferences have been reset | us |
| en.base.com.preference.resets.title | Reset Settings | Reset Preferences | us |
| en.base.org.preference.resets.back | Back to settings list | Back to Preferences | us |
| en.base.org.preference.resets.button | Reset Settings | Clear preference data | us |
| en.base.org.preference.resets.confirm | Are you sure? | This action deletes saved preference data for this browser. Continue? | us |
| en.base.org.preference.resets.description | Delete the settings data stored in this browser. | Remove saved preference cookies for this browser. | us |
| en.base.org.preference.resets.destroyed | Settings reset | Preferences have been reset | us |
| en.base.org.preference.resets.title | Reset Settings | Reset Preferences | us |
| en.help.app.contacts.new.submit | Create | Continue | jp |
| en.languages.japanese | Japanese | 日本語 | us |
| en.root.app.preferences.regions.select_timezone_selector.JST | Japan Standard Time (JST) | Japan Standard Time (Asia/Tokyo) | us |
| en.root.com.preferences.regions.select_timezone_selector.JST | Japan Standard Time (JST) | Japan Standard Time (Asia/Tokyo) | us |
| en.sign.app.preferences.footer.home | home | HOME | jp |
| en.sign.app.preferences.footer.preference | Preferences | PREFERENCES | jp |
| en.sign.app.preferences.footer.settings | Settings | SETTINGS | jp |
| en.sign.app.settings.email.edit.title | Delete Email Address | Email Address Settings | us |
| en.sign.org.preference.cookie.edit.accept_necessary_cookies | Allow necessary cookies (required) | Allow strictly necessary cookies (required) | us |
| en.sign.org.preference.theme.edit.description | Pick the display mode that fits your workspace and comfort. | Pick the display mode that keeps your org dashboards comfortable. | jp |
| en.sign.org.preference.theme.edit.hints.dark | Ideal for night shifts or reducing eye strain. | Favored for late-night monitoring without eye strain. | jp |
| en.sign.org.preference.theme.edit.hints.light | Great when you work during the day or in bright rooms. | Best when teams operate in bright operations centers. | jp |
| en.sign.org.preference.theme.edit.hints.system | Matches your operating system and switches automatically. | Keeps theme aligned with managed device policies. | jp |
| en.sign.org.preferences.footer.home | Home | HOME | jp |
| en.sign.org.preferences.footer.preference | Preference | PREFERENCES | jp |
| en.sign.org.preferences.footer.settings | Settings | SETTINGS | jp |
| en.sign.org.settings.withdrawal.show.description | Review your withdrawal status. | Org withdrawal is not self-service. Another operator must review and execute it. | us |
| ja.acme.app.preferences.regions.select_timezone_selector.JST | 日本標準時 (JST) | 日本標準時 (Asia/Tokyo) | us |
| ja.acme.com.preferences.regions.select_timezone_selector.JST | 日本標準時 (JST) | 日本標準時 (Asia/Tokyo) | us |
| ja.acme.org.preferences.regions.select_timezone_selector.JST | 日本標準時 (JST) | 日本標準時 (Asia/Tokyo) | us |
| ja.auth.com.settings.activity.events.unknown | 不明なイベント（%{event_id}） | 不明なイベント %{event_id} | jp |
| ja.controller.sign.preferences.regions.select_timezone_selector.JST | 日本標準時 (JST) | 日本標準時 (Asia/Tokyo) | us |
| ja.help.com.contacts.new.description | 以下のフォームにご記入ください。 | 必要事項をご入力のうえ送信してください。担当者からご連絡します。 | jp |
| ja.help.com.contacts.new.submit | 次へ | 送信 | jp |
| ja.help.org.contacts.new.description | 以下のフォームにご記入ください。 | 必要事項をご入力のうえ送信してください。担当者からご連絡します。 | jp |
| ja.help.org.contacts.new.submit | 次へ | 送信 | jp |
| ja.root.org.preferences.regions.select_timezone_selector.JST | 日本標準時 (JST) | 日本標準時 (Asia/Tokyo) | us |
| ja.sign.app.authentication.email.edit.description | 完了まであと少しです。メールに送信された6桁の認証コードを入力してください。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | jp |
| ja.sign.app.authentication.email.edit.page_title | 認証コードの入力 | 認証コード入力 | jp |
| ja.sign.app.authentication.email.edit.submit | Email で登録 | 送信する | us |
| ja.sign.app.authentication.email.new.page_title | メールでログイン | メールでページ登録 | jp |
| ja.sign.app.authentication.email.update.invalid_code | パスコードが正しくありません | 確認コードが正しくありません | jp |
| ja.sign.app.authentication.passkey.new.description | パスキーを使って安全にログインします。 | 信頼できる端末を使ってパスキーを追加し、パスワードなしでサインインします。 | jp |
| ja.sign.app.authentication.passkey.new.page_title | パスキーでログイン | パスキーを登録する | jp |
| ja.sign.app.in.mfa.totp.description | 認証アプリに表示されている6桁のコードを入力してください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.app.in.mfa.totp.submit | 認証する | 送信する | jp |
| ja.sign.app.in.mfa.totp.title | 認証アプリによる確認 | 認証コード入力 | jp |
| ja.sign.app.registration.email.create.verification_code_sent | 確認コードをメールアドレスに送信しました。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | us |
| ja.sign.app.registration.telephone.create.verification_code_sent | 確認コードをSMSで送信しました。 | 入力いただいた電話番号に、認証コードという6桁の数字がSMSで届きますので、入力してボタンを押してください。 | us |
| ja.sign.app.settings.email.edit.title | メールアドレスの検証 | メールアドレス設定 | us |
| ja.sign.app.settings.telephone.edit.pass_code_label | 確認コード | 認証コード | jp |
| ja.sign.app.settings.telephone.edit.pass_code_placeholder | SMSで受け取ったコードを入力 | 6桁の数字を入力 | jp |
| ja.sign.app.step_up.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.app.step_up.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.app.step_up.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.app.step_up.edit.submit | 確認 | 送信する | jp |
| ja.sign.app.step_up.edit.title | 再認証 | 認証コード入力 | jp |
| ja.sign.app.verification.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.app.verification.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.app.verification.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.app.verification.edit.email_description | 本人確認のため、コードの入力を行ってください。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | jp |
| ja.sign.app.verification.edit.submit | 確認 | 送信する | jp |
| ja.sign.app.verification.edit.title | 検証 | 認証コード入力 | jp |
| ja.sign.com.authentication.email.edit.description | 完了まであと少しです。メールに送信された6桁の認証コードを入力してください。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | jp |
| ja.sign.com.authentication.email.edit.page_title | 認証コードの入力 | 認証コード入力 | jp |
| ja.sign.com.authentication.email.edit.submit | Email で登録 | 送信する | us |
| ja.sign.com.authentication.email.new.page_title | メールでログイン | メールでページ登録 | jp |
| ja.sign.com.authentication.email.update.invalid_code | パスコードが正しくありません | 確認コードが正しくありません | jp |
| ja.sign.com.authentication.passkey.new.description | パスキーを使って安全にログインします。 | 信頼できる端末を使ってパスキーを追加し、パスワードなしでサインインします。 | jp |
| ja.sign.com.authentication.passkey.new.page_title | パスキーでログイン | パスキーを登録する | jp |
| ja.sign.com.registration.email.create.verification_code_sent | 確認コードをメールアドレスに送信しました。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | us |
| ja.sign.com.registration.telephone.create.verification_code_sent | 確認コードをSMSで送信しました。 | 入力いただいた電話番号に、認証コードという6桁の数字がSMSで届きますので、入力してボタンを押してください。 | us |
| ja.sign.com.verification.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.com.verification.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.com.verification.edit.email_description | 本人確認のため、コードの入力を行ってください。 | 入力いただいたメールアドレスに、認証コードという6桁の数字が届きますので、入力してボタンを押してください。 | jp |
| ja.sign.com.verification.edit.submit | 確認 | 送信する | jp |
| ja.sign.org.settings.withdrawal.show.description | 退会状況を確認します。 | org の退会は self-service では実行できません。別の operator による確認と実行が必要です。 | us |
| ja.sign.org.settings.withdrawal.show.title | 退会 | 退会ステータス | jp |
| ja.sign.org.social.sessions.create.success | %{provider}で登録を開始しました | %{provider} でアカウントを作成してサインインしました。 | jp |
| ja.sign.org.step_up.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.org.step_up.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.org.step_up.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.org.step_up.edit.submit | 確認 | 送信する | jp |
| ja.sign.org.step_up.edit.title | 再認証 | 認証コード入力 | jp |
| ja.sign.org.verification.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.org.verification.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.org.verification.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.org.verification.edit.submit | 確認 | 送信する | jp |
| ja.sign.org.verification.edit.title | 検証 | 認証コード入力 | jp |
| ja.sign.registration_extra.step_up.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.registration_extra.step_up.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.registration_extra.step_up.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.registration_extra.step_up.edit.submit | 確認 | 送信する | jp |
| ja.sign.registration_extra.step_up.edit.title | 再認証 | 認証コード入力 | jp |
| ja.sign.registration_extra.verification.edit.code_label | 確認コード | 認証コード | jp |
| ja.sign.registration_extra.verification.edit.code_placeholder | 6桁 | 6桁の数字を入力 | jp |
| ja.sign.registration_extra.verification.edit.description | 本人確認のため、コードの入力またはパスキー認証を行ってください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |
| ja.sign.registration_extra.verification.edit.submit | 確認 | 送信する | jp |
| ja.sign.registration_extra.verification.edit.title | 検証 | 認証コード入力 | jp |
| ja.sign.token_refresh.errors.invalid_refresh_token | 無効または期限切れのリフレッシュトークンです | リフレッシュトークンが無効です。 | jp |
| ja.sign.token_refresh.errors.missing_refresh_token | リフレッシュトークンが必要です | リフレッシュトークンが必要です。 | jp |
| ja.views.sign.app.settings.telephones.registrations.edit.description | SMSで届いた確認コードを入力してください。 | 入力いただいた電話番号に、認証コードという6桁の数字がSMSで届きますので、入力してボタンを押してください。 | jp |
| ja.views.sign.app.settings.telephones.registrations.edit.heading | 確認コードの入力 | 認証コード入力 | jp |
| ja.views.sign.app.settings.telephones.registrations.edit.page_title | 確認コードの入力 | 認証コード入力 | jp |
| ja.views.sign.app.settings.totps.new.first_token_help | 認証アプリに表示されている6桁のコードを入力してください。 | 認証アプリに表示される6桁の認証コードを入力して、ボタンを押してください。 | jp |

## Verification

- `bin/rails test test/initializers/ test/controllers/base/preference_authority_slice_1f_test.rb`:
  54 runs, 612 assertions, 0 failures, 0 errors.
- `bin/rails test test/controllers test/integration test/helpers test/presenters` (before the last
  choice adjustment): 5531 runs, 297 failures, 605 errors; the only text-related failure was
  `Auth::Com::Sign::Up::TelephonesControllerTest#test_edit_renders_authentication_code_copy`, fixed by
  choosing us for the four `registration.*.create.verification_code_sent` keys. Every other failure
  message was searched for the non-chosen texts and for missing translations; none matched.
- Re-run of the 72 failing files plus `test/initializers` and the files that reference a differing
  key: 767 runs, 297 failures, 13 errors. Two failures were new compared with the first run
  (`OrgAdminStepUpCeremonyTest`, 302 instead of 303 redirect status), and neither involves translated text. Step-Up code was being
  edited concurrently by another agent.
  The failures are the pre-existing admission-redirect failures. Errors dropped from the first run
  because another agent's in-progress code was settling.
- `bin/rails zeitwerk:check`: all is good.

## Not done

No test refuses a key that exists in only one language: 788 en-only and 691 ja-only keys already
exist, so the test would fail until those are translated. The case of one key with two different
texts can no longer arise, because each language has exactly one bundle (enforced at boot by
`config/initializers/locale.rb`) and the existing duplicate-key test refuses a key repeated inside a
bundle.
