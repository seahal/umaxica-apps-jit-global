# Audit Findings

> Generated: 2026-03-30  
> Migrated to: `audit-findings-2026-03-30.md`  
> Total findings: 136 (Critical: 2, High: 33, Medium: 90, Low: 8)

---

## Critical (2)

| #   | Category | Location                                          | Description                                      | Status     | Notes                                                                                                                |
| --- | -------- | ------------------------------------------------- | ------------------------------------------------ | ---------- | -------------------------------------------------------------------------------------------------------------------- |
| 1   | Security | `app/controllers/sign/app/tokens_controller.rb:8` | CSRF protection disabled (FIXME comment present) | **CLOSED** | OAuth token endpoint uses client credentials/PKCE, not session cookies. CSRF protection is not applicable by design. |
| 2   | Security | `app/controllers/sign/org/tokens_controller.rb:9` | Same — CSRF protection disabled                  | **CLOSED** | Same as #1.                                                                                                          |

---

## High (33)

### Hardcoded localhost URLs in WebAuthn trusted_origins (20)

All must be resolved before production deployment.

| #   | Location                                                |
| --- | ------------------------------------------------------- |
| 3   | `app/controllers/acme/app/application_controller.rb:39` |
| 4   | `app/controllers/acme/com/application_controller.rb:39` |
| 5   | `app/controllers/acme/org/application_controller.rb:37` |
| 6   | `app/controllers/core/app/application_controller.rb:21` |
| 7   | `app/controllers/core/com/application_controller.rb:21` |
| 8   | `app/controllers/core/org/application_controller.rb:21` |
| 9   | `app/controllers/docs/app/application_controller.rb:29` |
| 10  | `app/controllers/docs/com/application_controller.rb:28` |
| 11  | `app/controllers/docs/org/application_controller.rb:27` |
| 12  | `app/controllers/help/app/application_controller.rb:37` |
| 13  | `app/controllers/help/com/application_controller.rb:38` |
| 14  | `app/controllers/help/org/application_controller.rb:39` |
| 15  | `app/controllers/news/app/application_controller.rb:40` |
| 16  | `app/controllers/news/com/application_controller.rb:38` |
| 17  | `app/controllers/news/org/application_controller.rb:38` |
| 18  | `app/controllers/sign/app/application_controller.rb:44` |
| 19  | `app/controllers/sign/com/application_controller.rb:19` |
| 20  | `app/controllers/sign/org/application_controller.rb:41` |
| 21  | `app/controllers/sign/org/up/base_controller.rb:30`     |

### IDOR — Missing Authorization on Contact Lookup (3)

| #   | Location                                              | Description                                 |
| --- | ----------------------------------------------------- | ------------------------------------------- |
| 23  | `app/controllers/core/app/contacts_controller.rb:193` | Any authenticated user can view any contact |
| 24  | `app/controllers/core/com/contacts_controller.rb:69`  | Same                                        |
| 25  | `app/controllers/core/org/contacts_controller.rb:168` | Same                                        |

### Step-up Auth Flag Not Persisted (1)

| #   | Location                           | Description                                               |
| --- | ---------------------------------- | --------------------------------------------------------- |
| 26  | `app/lib/sign/risk/enforcer.rb:39` | Step-up auth state could be lost between requests (FIXME) |

### God Classes (2)

| #   | Location                                                 | Description                                                                               |
| --- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 27  | `app/controllers/concerns/authentication/base.rb:1-2422` | 2,422 lines — JWT, cookies, sessions, MFA, audit, risk, DBSC, bulletins, withdrawal gates |
| 28  | `app/controllers/concerns/preference/base.rb:1-1521`     | 1,521 lines — JWT, cookies, locale, timezone, color theme, audit, refresh tokens          |

### Synchronous External API in Request Cycle (2)

| #   | Location                                                  | Description                                      |
| --- | --------------------------------------------------------- | ------------------------------------------------ |
| 29  | `app/controllers/core/app/contacts_controller.rb:103-108` | Cloudflare Turnstile verification blocks request |
| 30  | `app/controllers/core/org/contacts_controller.rb:103-108` | Same                                             |

### N+1 — COUNT Queries in View Loop (3)

| #   | Location                                        | Description                           |
| --- | ----------------------------------------------- | ------------------------------------- |
| 31  | `app/views/docs/com/v1/posts/show.html.erb:98`  | `.count` called 3 times per iteration |
| 32  | `app/views/docs/com/v1/posts/show.html.erb:118` | Same                                  |
| 33  | `app/views/docs/com/v1/posts/show.html.erb:120` | Same                                  |

### FIXME: URL Issues Before Deploy (18 controllers)

All `*_application_controller.rb` files across acme/core/docs/help/news/sign contain:
`# FIXME: Resolve the URL issues before deploying`

---

## Medium (90)

### N+1 — `.exists?` in Instance Methods (16)

| #   | Location                              | Method                             |
| --- | ------------------------------------- | ---------------------------------- |
| 34  | `app/models/user.rb:169`              | `totp_enabled?`                    |
| 35  | `app/models/user.rb:228`              | `verified_email?`                  |
| 36  | `app/models/user.rb:236`              | `verified_telephone?`              |
| 37  | `app/models/user.rb:241`              | `passkey_login_available?`         |
| 38  | `app/models/customer.rb:109`          | `verified_email?`                  |
| 39  | `app/models/customer.rb:117`          | `verified_telephone?`              |
| 40  | `app/models/customer.rb:122`          | `passkey_login_available?`         |
| 41  | `app/models/user_telephone.rb:91`     | Uniqueness check — full table scan |
| 42  | `app/models/user_email.rb:124`        | Same                               |
| 43  | `app/models/customer_email.rb:112`    | Same                               |
| 44  | `app/models/customer_telephone.rb:81` | Same                               |
| 45  | `app/models/concerns/treeable.rb:61`  | Tree traversal N+1                 |
| 46  | `app/models/concerns/treeable.rb:63`  | Same                               |
| 47  | `app/models/staff.rb:148`             | ID generation collision retry      |
| 48  | `app/models/user_activity.rb:91`      | Event existence check              |
| 49  | `app/models/staff_activity.rb:81`     | Same                               |

### N+1 — `.count` in Validation Callbacks (16)

| #   | Location                                  | Model               |
| --- | ----------------------------------------- | ------------------- |
| 50  | `app/models/user_token.rb:106`            | UserToken           |
| 51  | `app/models/customer_token.rb:99`         | CustomerToken       |
| 52  | `app/models/staff_token.rb:107`           | OperatorToken       |
| 53  | `app/models/user_email.rb:133`            | UserEmail           |
| 54  | `app/models/customer_email.rb:120`        | CustomerEmail       |
| 55  | `app/models/staff_email.rb:86`            | OperatorEmail       |
| 56  | `app/models/user_telephone.rb:99`         | UserTelephone       |
| 57  | `app/models/customer_telephone.rb:89`     | CustomerTelephone   |
| 58  | `app/models/user_secret.rb:153`           | UserSecret          |
| 59  | `app/models/customer_secret.rb:146`       | CustomerSecret      |
| 60  | `app/models/staff_secret.rb:129`          | OperatorSecret      |
| 61  | `app/models/user_passkey.rb:66`           | UserPasskey         |
| 62  | `app/models/customer_passkey.rb:66`       | CustomerPasskey     |
| 63  | `app/models/staff_passkey.rb:63`          | OperatorPasskey     |
| 64  | `app/models/staff_telephone.rb:67`        | OperatorTelephone   |
| 65  | `app/models/user_one_time_password.rb:65` | UserOneTimePassword |

### N+1 — `.count` in Controllers (9)

| #   | Location                                                   | Description                    |
| --- | ---------------------------------------------------------- | ------------------------------ |
| 66  | `app/controllers/sign/app/settings/totps_controller.rb:20` | MAX_TOTPS check always hits DB |
| 67  | `app/controllers/concerns/authentication/base.rb:2115`     | UserToken session count        |
| 68  | `app/controllers/concerns/authentication/base.rb:2117`     | OperatorToken session count    |
| 69  | `app/controllers/concerns/authentication/base.rb:2119`     | CustomerToken session count    |
| 70  | `app/controllers/sign/app/in/sessions_controller.rb:164`   | Active session count           |
| 71  | `app/controllers/sign/com/in/sessions_controller.rb:117`   | Same                           |
| 72  | `app/controllers/sign/org/in/sessions_controller.rb:179`   | Same                           |
| 73  | `app/controllers/docs/com/edge/v0/posts_controller.rb:69`  | `.count` in query chain        |
| 74  | `app/controllers/docs/com/edge/v0/posts_controller.rb:77`  | `documents_scope.count`        |

### N+1 — `.count`/`.size` in Views (7)

| #   | Location                                          | Description              |
| --- | ------------------------------------------------- | ------------------------ |
| 75  | `app/views/sign/app/in/sessions/show.html.erb:26` | `@active_sessions.count` |
| 76  | `app/views/news/org/v1/posts/index.html.erb:9`    | `@posts.size`            |
| 77  | `app/views/news/com/v1/posts/index.html.erb:9`    | Same                     |
| 78  | `app/views/news/app/v1/posts/index.html.erb:9`    | Same                     |
| 79  | `app/views/docs/org/v1/posts/index.html.erb:9`    | Same                     |
| 80  | `app/views/docs/app/v1/posts/index.html.erb:9`    | Same                     |

### Implicit Authorization — Missing `authorize` Calls (10)

| #   | Location                                                        | Description                              |
| --- | --------------------------------------------------------------- | ---------------------------------------- |
| 81  | `app/controllers/sign/com/settings/emails_controller.rb:19`     | Relies on scoping, no explicit authorize |
| 82  | `app/controllers/sign/com/settings/telephones_controller.rb:26` | Same                                     |
| 83  | `app/controllers/sign/com/settings/secrets_controller.rb:70`    | Same                                     |
| 84  | `app/controllers/sign/app/settings/emails_controller.rb:19`     | Same                                     |
| 85  | `app/controllers/sign/app/settings/secrets_controller.rb:71`    | Same                                     |
| 86  | `app/controllers/sign/app/settings/totps_controller.rb:97`      | Same                                     |
| 87  | `app/controllers/sign/app/settings/passkeys_controller.rb:206`  | Same                                     |
| 88  | `app/controllers/sign/app/settings/sessions_controller.rb:77`   | Same                                     |
| 89  | `app/controllers/sign/com/settings/sessions_controller.rb:73`   | Same                                     |

### Unclear Comments — `# what is this?` / `# FIXME: what is this method?` (5)

| #   | Location                                               | Description                                            |
| --- | ------------------------------------------------------ | ------------------------------------------------------ |
| 90  | `app/models/user.rb:50`                                | `# what is this?` on `LOGIN_BLOCKED_STATUS_IDS`        |
| 91  | `app/models/user.rb:187`                               | `# what is this?` on `has_verified_recovery_identity?` |
| 92  | `app/controllers/concerns/authentication/viewer.rb:73` | `# FIXME: what is this method?`                        |
| 93  | `app/controllers/concerns/authentication/user.rb:67`   | Same                                                   |
| 94  | `app/controllers/concerns/authentication/staff.rb:71`  | Same                                                   |

### TODO — Deferred Deletion Lifecycle Work (7)

| #   | Location                          | Description                              |
| --- | --------------------------------- | ---------------------------------------- |
| 95  | `app/models/user.rb:162`          | Migrate `deletable_at` → `shreddable_at` |
| 96  | `app/models/app_preference.rb:52` | Add `shreddable_at`                      |
| 97  | `app/models/com_preference.rb:52` | Same                                     |
| 98  | `app/models/org_preference.rb:52` | Same                                     |
| 99  | `app/models/operator.rb:34`       | Same                                     |
| 100 | `app/models/member.rb:32`         | Same                                     |
| 101 | `app/models/avatar.rb:39`         | Same                                     |

### Cross-Surface Code Duplication (6)

| #   | Location                                 | Description                                    |
| --- | ---------------------------------------- | ---------------------------------------------- |
| 102 | `contacts_controller.rb` (app vs org)    | create/show logic nearly identical             |
| 103 | `contacts_controller.rb` (app vs org)    | `turnstile_stealth_valid?` duplicated verbatim |
| 104 | `contacts_controller.rb` (app vs org)    | `canonical_*_email` pattern duplicated         |
| 105 | `contacts_controller.rb` (app vs org)    | `core_*_host` URI parsing duplicated           |
| 106 | `withdrawals_controller.rb` (app vs com) | Withdrawal flow duplicated                     |
| 107 | `secrets_controller.rb` (app vs com)     | Passcode verification logic duplicated         |
| 108 | `activities_controller.rb` (app/com/org) | Triply duplicated                              |

### Hardcoded Japanese Messages — Should Use i18n (8)

| #   | Location                                               | Message                             |
| --- | ------------------------------------------------------ | ----------------------------------- |
| 109 | `app/controllers/concerns/authentication/base.rb:56`   | `SESSION_LIMIT_HARD_REJECT_MESSAGE` |
| 110 | `app/controllers/concerns/authentication/base.rb:57`   | `LOGIN_COOLDOWN_MESSAGE`            |
| 111 | `app/controllers/concerns/authentication/base.rb:202`  | `You do not have permission`        |
| 112 | `app/controllers/concerns/authentication/base.rb:243`  | Same                                |
| 113 | `app/controllers/concerns/authentication/base.rb:2400` | Same                                |
| 114 | `app/controllers/concerns/authentication/base.rb:2403` | `The request is invalid`            |
| 115 | `app/controllers/core/app/contacts_controller.rb:116`  | `Please register an email address`  |
| 116 | `app/controllers/core/app/contacts_controller.rb:122`  | `Please add a telephone number`     |

### `Rails.env.test?` Branching in Production Code (6)

| #   | Location                                                    | Description                  |
| --- | ----------------------------------------------------------- | ---------------------------- |
| 117 | `app/controllers/concerns/authentication/base.rb:65`        | `LOGIN_COOLDOWN_ENABLED`     |
| 118 | `app/controllers/concerns/authentication/base.rb:1540-1574` | `load_from_test_header`      |
| 119 | `app/controllers/concerns/authentication/base.rb:1670-1674` | Token destruction branching  |
| 120 | `app/controllers/concerns/authentication/base.rb:2070-2077` | Cooldown check branching     |
| 121 | `app/controllers/concerns/preference/base.rb:61-65`         | Localhost audience branching |

### Cross-Surface Controller References (6)

| #   | Location                                       | Description             |
| --- | ---------------------------------------------- | ----------------------- |
| 122 | `core/org/news/com/posts_controller.rb`        | org serving com content |
| 123 | `core/org/news/app/posts_controller.rb`        | org serving app content |
| 124 | `core/org/docs/com/posts_controller.rb`        | org serving com content |
| 125 | `core/org/docs/app/posts_controller.rb`        | org serving app content |
| 126 | `core/org/help/app/contacts_controller.rb`     | org serving app content |
| 127 | `core/org/emergency/com/outages_controller.rb` | org serving com content |

### Business Logic in Controllers (4)

| #   | Location                                                    | Description                                 |
| --- | ----------------------------------------------------------- | ------------------------------------------- |
| 128 | `app/controllers/core/app/contacts_controller.rb:42-55`     | Multi-model transaction in controller       |
| 129 | `app/controllers/core/org/contacts_controller.rb:42-55`     | Same                                        |
| 130 | `app/controllers/sign/com/in/secrets_controller.rb:108-140` | 33-line passcode verification in controller |
| 131 | `app/controllers/concerns/authentication/base.rb:565-692`   | `log_in` method is 128 lines                |

### Test Gaps (16)

Controllers without dedicated tests:

| #   | Location                                                  |
| --- | --------------------------------------------------------- |
| 132 | `app/controllers/core/app/contacts_controller.rb`         |
| 133 | `app/controllers/core/com/contacts_controller.rb`         |
| 134 | `app/controllers/core/org/contacts_controller.rb`         |
| 135 | `app/controllers/core/app/edge/v0/messages_controller.rb` |
| 136 | `app/controllers/core/com/edge/v0/messages_controller.rb` |
| 137 | `app/controllers/core/org/edge/v0/messages_controller.rb` |
| 138 | `app/controllers/docs/app/edge/v0/posts_controller.rb`    |
| 139 | `app/controllers/docs/com/edge/v0/posts_controller.rb`    |
| 140 | `app/controllers/docs/org/edge/v0/posts_controller.rb`    |
| 141 | `app/controllers/news/app/edge/v0/posts_controller.rb`    |
| 142 | `app/controllers/news/com/edge/v0/posts_controller.rb`    |
| 143 | `app/controllers/news/org/edge/v0/posts_controller.rb`    |

Services without tests:

| #   | Location                                               |
| --- | ------------------------------------------------------ |
| 144 | `../app/services/org/invitation_service.rb`            |
| 145 | `../app/services/org/registration_policy.rb`           |
| 146 | `../app/services/jit/security/jwt/anomaly_reporter.rb` |
| 147 | `../app/services/sign/in/otp_resend_service.rb`        |

---

## Low (8)

### Commented-Out Gems in Gemfile (6)

| #   | Location      | Gem                 |
| --- | ------------- | ------------------- |
| 148 | `Gemfile:25`  | `jbuilder`          |
| 149 | `Gemfile:30`  | `neighbor`          |
| 150 | `Gemfile:61`  | `sitemap_generator` |
| 151 | `Gemfile:72`  | `pagy`              |
| 152 | `Gemfile:142` | `spring`            |
| 153 | `Gemfile:145` | `web-console`       |

### Duplicate Live Reload Mechanisms (4)

| #   | Location      | Gem                 |
| --- | ------------- | ------------------- |
| 154 | `Gemfile:122` | `rack-livereload`   |
| 155 | `Gemfile:125` | `guard-livereload`  |
| 156 | `Gemfile:137` | `hotwire-spark`     |
| 157 | `Gemfile:138` | `rails_live_reload` |

### Other

| #   | Category    | Location                                              | Description                                                 |
| --- | ----------- | ----------------------------------------------------- | ----------------------------------------------------------- |
| 158 | Dependency  | `Gemfile:39-40`                                       | Both `argon2` and `bcrypt` installed — verify both are used |
| 159 | Performance | `db/schema.rb` (various)                              | Empty table stubs for status/category tables                |
| 160 | Code Smell  | `app/lib/sign/risk/emitter.rb:7`                      | FIXME: PG INSERT latency vs Redis ZADD                      |
| 161 | Config      | `app/controllers/concerns/authentication/base.rb:94`  | Hardcoded default JWT issuer `"umaxica-auth"`               |
| 162 | Config      | `app/controllers/concerns/authentication/base.rb:112` | Hardcoded default audience `["umaxica-api"]`                |
| 163 | Config      | `app/controllers/concerns/preference/base.rb:36`      | Hardcoded default preference JWT issuer `"jit-preference"`  |

---

## Top 5 Priority Fixes

1. **CSRF disabled on token endpoints** (Critical) — `sign/app/tokens_controller.rb`,
   `sign/org/tokens_controller.rb`
   - **Status**: CLOSED — OAuth token endpoint design does not require CSRF protection.

2. **Hardcoded localhost URLs in 20+ controllers** (High) — all `*_application_controller.rb` files
   with WebAuthn trusted_origins

3. **IDOR in contact controllers** (High) — `core/*/contacts_controller.rb` allow viewing any
   contact

4. **N+1 in `docs/com/v1/posts/show.html.erb`** (High) — 3 COUNT queries per version in a loop

5. **God class `authentication/base.rb`** (High) — 2,422 lines needs decomposition

---

## Migration Notes

This document was migrated from `../plans/archive` to `audit` on 2026-04-07.

- The Critical findings (#1-2) were reviewed and determined to be **false positives** for an OAuth
  token endpoint. The endpoint uses `ActionController::API` (no session cookies) and relies on
  client credentials and PKCE for security, not CSRF tokens.
- Remaining findings retain their original priority pending review and remediation.
