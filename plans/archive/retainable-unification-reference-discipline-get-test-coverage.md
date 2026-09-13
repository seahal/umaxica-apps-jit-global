# Detailed design: Reference table/GET 200 assertion/Retainable unified

## Status

**COMPLETED** (2026-05-08)

The main body of the implementation is complete. Only test greening and E2E confirmation will
continue separately.

Accomplishments:

- ✅ Introduced `Retainable` concern, applied directly to 40 models with `include`, transitively
  applied to 12 models via concern
- ✅ `ReferenceRecord` concern introduced, adopted in 95 files
- ✅ Old columns (`deletable_at` / `shreddable_at` / `revoked_at` / `refresh_expires_at` /
  `compromised_at` / `expired_at` / `scheduled_purge_at`) All app code references have been zeroed
  out and also dropped from the DB schema.
- ✅ `lapses_at` / `purge_at` 2 axis naming unified, `Float::INFINITY` sentinel adopted
- ✅ Solid Queue `RetentionPurgeJob` working, `config/recurring.yml` registered
- ✅ Verification::Base 401 bug (inconsistency with sentinel) resolved
- ✅ Implementation of created_at boundary measures (`[now, created_at].compact.max`) for
  TokenStatusManagement#revoke!
- ✅ ADR `adr/reference-table-discipline.md` and `adr/retainable-concern-and-retention-purge.md`
  Confirmed

## Related

- **Supersedes**: `plans/archive/gh586-lifecycle-columns-and-partitioning.md` (lifecycle (The final
  form of the column design is finalized in this plan)
- **Spin-off**: GitHub issue [#789](https://github.com/seahal/umaxica-apps-global/issues/789)
  (`published_at` rename — not covered by this plan, continued in another issue)
- **References**: `adr/secure-jump-link-redirector.md` (`deletable_at` Define the retention role for
  this plan, rename it to `purge_at` + deepen it by introducing `lapses_at`)
- **ADR**: `adr/reference-table-discipline.md`, `adr/retainable-concern-and-retention-purge.md`

## Context

The design debt for the three systems will be reduced at once.

1. **Lack of lookup table discipline** — 68 lookup tables, many of which are
   `record_timestamps = false` There is no date, but the value of the NOTHING constant is 0 / 1 /
   11, and it says "Unspecified = 0" is only implicitly enforced. For join systems like
   `avatar_role_permissions` `created_at`/`updated_at` remains. ADR not created.
2. **Missing verification of 200 normal systems** — `assert_response :success` for approximately 287
   routes of GET Explicit verification of the system accounts for only approximately 70–75% of the
   tests. There are some places where only the rendered content is asserted and 5xx conversion
   cannot be detected.
3. **retention/inconsistency in physically deleted columns** — 24 Model replaces existing column
   `deletable_at` with NOT NULL + Operated by `Float::INFINITY` sentinel, 6 models of
   User/Customer/Avatar/Member/Operator/Staff are sold separately. `shreddable_at` is also retained
   (duplicate), JumpLinkable is separate sentinel `Time.utc(9999,...)` Use. Three concerns
   (`token_deletable_sync` / `occurrence` / `jump_linkable`) has duplicate functionality, and the
   concept of "unaccessible time" (`lapses_at` described below) has not been introduced. Solid
   Queue's recurring purge only covers risk occurrences.

goal:

- Change reference table convention to ADR, set Nothing=0 to all references Align to model, remove
  date from related tables (including joins)
- Added `assert_response :success` (or explicit redirect) to controller test assuming all GET routes
- Introduced `Retainable` concern and integrated 24 models + existing 3 concerns at once, Solid
  Added generic retention purge job for Queue

Design decisions adopted (user responses):

- The time column is unified to **NOT NULL + `Float::INFINITY` sentinel** (spec `IS NULL OR ...` is
  a concept, and the implementation is a single `> Time.current`)
- Rollout is **Bulk Migration (1 PR)**
- Date deletion of related tables is strictly applied including join systems\*\*
- 200 assertion **explicitly in each controller test `assert_response`**
- **Column naming**: Inaccessible time (=logical deletion) = `lapses_at`/Physical deletion candidate
  time = `purge_at`. `shreddable_at` is not a misspelling but an orthography, but because of the
  overlap in meaning, `purge_at` integrated into. `lapses_at` is changed from `inaccessible_at` in
  the specification (intransitive + `_at`, same type as `expires_at`).
- **Semantics**: `lapses_at` elapsed = logical delete (filtered by query, UI invisible) / `purge_at`
  Elapsed = Physical deletion possible (Solid Queue collection target). Usually
  `lapses_at <= purge_at` (logical deletion → physical deletion order).
- **scope is not defined**: concern is instance method (`accessible?` / `lapsed?` / `purgeable?`)
  only. The query writes raw `where(...)` on the caller side. Reason: `.active` for existing model /
  To prevent confusion with `.deletable`, etc., and unexpected conditional combinations due to scope
  chains.

---

## Theme 1: Reference table convention

### Design policy

**Conditions (targeted by ADR)**:

1. The reference table has only PK. `record_timestamps = false` is required for all models.
2. All referenced models have `NOTHING = 0` as sentinel and the first row of reference data is
   `id = 0`, logically meaning "unspecified/unknown/not set".
3. The FK to the reference table has `default: 0`, and the unset state is represented by the NOTHING
   row (NULLable FK is not used).
4. Join tables between reference tables (e.g. `avatar_role_permissions`) also does not have a date
   column. Treat the life cycle as reference data itself.

### Target of change

- Added new ADR `adr/reference-table-discipline.md` (Conditions / Nothing=0 / FK default 0 /
  justification for absence of date)
- Added `reference_record.rb` to `app/models/concerns/` to consolidate common behavior of referenced
  models:
  ```ruby
  module ReferenceRecord
    extend ActiveSupport::Concern
    included do
      self.record_timestamps = false
    end
    class_methods do
      def nothing_id; const_get(:NOTHING); end
      def ensure_defaults!; insert_missing_fixed_ids!(self::DEFAULTS); end
    end
  end
  ```
- Among the existing 68 reference models, those whose `NOTHING` is not 0 (`NOTHING = 1`,
  `NOTHING = 11`, etc.) **Check compatibility with existing data** Align to 0. If compatibility
  breaks, specify exception handling with ADR.
- `avatar_role_permissions` and others, from join between reference tables `created_at` /
  `updated_at` migration.
- `ensure_reference_rows()` for `db/seeds.rb` `ensure_defaults!` for each model on the caller are
  driven in a unified manner.

### important file

- New: `adr/reference-table-discipline.md`
- New: `app/models/concerns/reference_record.rb`
- Renovation of existing: `app/models/application_record.rb` (`insert_missing_fixed_ids!` is used as
  existing)
- Existing renovation: `db/seeds.rb`
- Migration: drop date column from join system under `db/avatar_migrate/` (starting from
  avatar_role_permissions)
- 68 items for each reference model: `include ReferenceRecord` + `NOTHING = 0` unified

### Points to note

- `NOTHING = 1` / `11` When changing to 0, there are cases where it is necessary to remap the FK
  value that is already in production. For existing data **Do not change ID** Policy (reference The
  id of data is treated like an immutable enum), and the option to specify in the Exception section
  of ADR any existing model whose Nothing line is not 0 as a "legacy that deviates from the
  regulations" is also included. The final decision is made during migration design.

---

## Theme 2: 200 assertion reinforcement for GET route

### Design policy

`assert_response` among the parts that cycle through each controller test and call `get` Add
explicit assertions where there is no system. Where redirects are expected Make it
`assert_response :redirect`.

### scope estimate

- Target test file: 141 (`test/controllers/{acme,sign,jump}/`)
- Methods to be modified: Approximately 50–100
- Existing pattern: Host setting with `host!`, inheriting `ActionDispatch::IntegrationTest` from
  `test_helper.rb`

### How to proceed

1. Extract all GET routes with `bin/rails routes` → List them (as checklist for test completion)
2. Extract `^\s+get\s` by greping under `test/controllers/`, and add `assert_response` to the
   subsequent line. List the things that don't have
3. Cycle through each file for each surface (acme/sign/jump) and use `assert_response :success` or
   Reinforce `:redirect`
4. At the same time as augmentation, ensure that the host! settings for each test are correct after
   resolving ENV (existing (via helper of `test/support/auto_headers.rb`)

### unreinforced test

- For tests such as authorization failure, 404, 401, etc., maintain the existing
  `assert_response :unauthorized` etc. (do not change)
- Exceptionally, GET (jump redirector, etc.) where redirect is the correct answer is fixed to
  `:redirect`
- To test without logging in on an endpoint that requires authentication, use `:redirect` (to
  sign-in) or `:unauthorized` maintain

### important file

- Target of modification: `test/controllers/acme/**/*_test.rb` (29 files)
- Target of modification: `test/controllers/sign/**/*_test.rb` (141 files) — Main scope
- Target of modification: `test/controllers/jump/**/*_test.rb` (5 files)
- Utilize existing helpers: `test/support/auto_headers.rb`, `test/test_helper.rb`

### Points to note

- Batch machine replacement of sed system is dangerous (redirect system will be overwritten with
  success). Manual patrol required.
- `assert_response :success` instead of "test passes = returns 200" at the same time as
  reinforcement Be aware that this will be a testdouble that catches the "expected response". There
  is a possibility that tests with 500 numbers accidentally appear due to a lack of fixtures.

---

## Theme 3: Retainable concern unity

### Design policy (core)

**Unified to NOT NULL + `Float::INFINITY` sentinel for all models**. `Retainable` concern absorbs
the features of 24 models + 3 existing concerns as a single correct answer.

### Concern API

```ruby
# app/models/concerns/retainable.rb
module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :lapses_at, :datetime, default: -> { SENTINEL }
    attribute :purge_at,    :datetime, default: -> { SENTINEL }

    validates :lapses_at, presence: true
    validates :purge_at,    presence: true
    validate  :lapses_at_not_after_purge_at
    validate  :retention_times_not_before_created_at, on: :update

  end

  # NOTE: ActiveRecord scope is intentionally not defined (existing `.active` / `.deletable` etc.
  #   (because it is confused with implicit behavior). Write the query as raw `where('lapses_at > ?', Time.current)`.

  def accessible?; lapses_at > Time.current; end
  def lapsed?;     lapses_at <= Time.current; end
  def purgeable?;  purge_at  <= Time.current; end

  def schedule_retention!(lapses_at:, purge_at:)
    raise ArgumentError, 'lapses_at must be in the future' if lapses_at <= Time.current
    raise ArgumentError, 'purge_at must be in the future'  if purge_at  <= Time.current
    raise ArgumentError, 'lapses_at must be <= purge_at'   if lapses_at > purge_at
    update!(lapses_at: lapses_at, purge_at: purge_at)
  end

  private

  def lapses_at_not_after_purge_at
    return if lapses_at.blank? || purge_at.blank?
    errors.add(:lapses_at, 'must be <= purge_at') if lapses_at > purge_at
  end

  def retention_times_not_before_created_at
    return if created_at.blank?
    errors.add(:lapses_at, 'must be >= created_at') if lapses_at < created_at
    errors.add(:purge_at,    'must be >= created_at') if purge_at    < created_at
  end
end
```

**Design implications**:

- The spec `accessible: lapses_at IS NULL OR lapses_at > Time.current` is sentinel = Semantically
  equivalent to `> Time.current` alone under INFINITY (INFINITY > now is always true). This is
  specified using ADR.
- `>= created_at` Validation is only for `on: :update` (created_at is nil and cannot be referenced
  at the time of creation).
- `schedule_retention!` throws ArgumentError (satisfies the spec "Throw an exception").
- Normally, do not include `>= Time.current` in validation (if a record with past purge_at was job).

### Column integration map (C/D integration strategy)

As a result of implementation reading, the TTL / revocation / retention type scattered columns are
distributed as follows.

#### Integrated into `lapses_at`

| Old column                        | Target model                                                                                                                                           | Integration basis                                                                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `revoked_at`                      | verifications (3), authorization_codes (3), tokens (3), jump_links (3), occurrences (9), reauth_sessions (3), preferences (3), single_use_token series | `update!(revoked_at: now)` expresses "no longer available", completely synonymous with `lapses_at`                                                           |
| `expires_at` (credential variant) | user/staff/customer verifications, authorization_codes, reauth_sessions, secrets, organization_invitations, post_version                               | `TTL.from_now` set on issue, row level outer bound                                                                                                           |
| `refresh_expires_at`              | user_token, customer_token, staff_token                                                                                                                | OAuth refresh window exit = row is completely dead, perfect as outer bound of `lapses_at`                                                                    |
| `compromised_at`                  | single_use_token series                                                                                                                                | Treated the same as `revoked_at` (`where(revoked_at: nil, compromised_at: nil)` pattern). If forensic distinction is required, keep it in the occurrence log |

#### Integrated into `purge_at`

| Old column | Target model | Integration basis | | -------------------------------------- |
-------------------------------------------------------------------------------------------------------------------------------------
| ----------------------------------------------------------------------------------------- | --- |
---------------------------------------------------------- | | `deletable_at` | 24+ models (as
mentioned above) | Confirmed | | `shreddable_at` | User/Customer/Avatar/Member/Operator/Staff (6) |
Confirmed | | `scheduled_purge_at` | User, Customer | `withdrawals_controller.rb:140` operates the
same as `deletable_at                        |     | = scheduled_purge_at`, view also refers to the
same column | | `expires_at` (audit/chronicle variant) | app/com/org*contact_chronicle,
*\_document*audit, *\_preference*chronicle, *\_timeline*audit, staff/user_chronicle, *\_activity
(13+) | Retention period of `default: now + 7.years`, purely means "can be deleted after 7 years" |

#### Delete (dead column)

| Old column   | Target model               | Reason for deletion                                                                                                                                                                                                                                                                                                       |
| ------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `expired_at` | user_token, customer_token | `app/lib/sign/risk/enforcer.rb:32`, `verification/base.rb:185`, `dbsc_helpers.rb:82`, `token_status_management.rb:88` are referenced only in the fallback chain of `column_names.include?("expired_at") ? :expired_at : :revoked_at`, and the functionality is completely equivalent to `revoked_at`. Transitional Relics |

#### Deferred (sub-state column, independent of row lifetime)

| Column                                               | Target model                                                                           | Basis for deferral                                                                                                                                                    |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `token_expires_at`                                   | contacts (app/com/org), user_social_google, user_social_apple                          | TTL of the token embedded in the line, the line persists and can be reissued even after expiration. `alias_attribute :expires_at, :token_expires_at` (external OAuth) |
| `verifier_expires_at` / `otp_expires_at` (alias)     | contact_email/telephone, identity_email/telephone, user/customer_email, contact_topics | OTP / verifier of TTL, updated with reissue                                                                                                                           |
| `expires_at` (token only: user/staff/customer_token) | tokens (3)                                                                             | access token TTL (short term ~1h), `refresh_expires_at` (=`lapses_at`) are outer bound, leave this as the inner access axis                                           |
| `consumed_at`                                        | authorization_codes                                                                    | A record of the fact that a code was used, separate from retention                                                                                                    |
| `used_at`                                            | single_use_token series                                                                | Same as above                                                                                                                                                         |

### Migration strategy

**Phase A — Added new column `lapses_at`**:

1. Issue new migration by DB (principals/guests/operators/chronicle/settings/redirector/avatar):
   ```ruby
   add_column :users, :lapses_at, :datetime, null: false, default: -> { "'infinity'" }
   ```
2. At the same time, models that do not have `purge_at` also have `purge_at`. (chronicle-based audit
   tables, etc.).
3. `Float::INFINITY` is supported using PostgreSQL's `timestamp 'infinity'` (Rails attribute API is
   type conversion).

**Phase B — Consolidation of existing physically deleted columns**:

1. **`deletable_at` → `purge_at` rename** (24 models):
   ```ruby
   rename_column :users, :deletable_at, :purge_at
   # Similarly, customers, staffs, app/org/com_preferences, *_tokens, *_verifications,
   # *_authorization_codes, *_reauth_sessions, *_occurrences, *_jump_links
   ```
2. **`shreddable_at` integration** (6 models of User/Customer/Avatar/Member/Operator/Staff):
   - User/Customer was using `deletable_at` and `shreddable_at` together → `deletable_at` After
     renaming, backfill the value of `shreddable_at` with `LEAST(purge_at, shreddable_at)`. drop
     `shreddable_at`
   - Avatar/Member/Operator/Staff is only `shreddable_at` → `rename_column shreddable_at → purge_at`
3. **`scheduled_purge_at` integration** (User, Customer):
   - `deletable_at` Backfill the value of `scheduled_purge_at` to renamed `purge_at` (Adopts
     `LEAST(purge_at, scheduled_purge_at)`)
   - drop `scheduled_purge_at`
   - Related views (`app/views/sign/app/settingss/edit.html.erb`,
     `sign/com/settingss/edit.html.erb`) Rewrite `current_user.scheduled_purge_at` reference to
     `purge_at`
   - `scheduled_purge_at` assignment of `withdrawals_controller.rb` (both app/com) to `purge_at`
     Rewrite to assignment (`||= deactivated_at + 31.days`)
4. **`expires_at` (audit/chronicle variant) → `purge_at` rename** (chronicle family 13+ tables):
   ```ruby
   rename_column :app_contact_chronicles, :expires_at, :purge_at
   # *_chronicle, *_document_audit, *_preference_chronicle, *_timeline_audit, *_activity
   ```
   Defalut's `now + 7.years` expression is maintained as is (just rename).
5. **JumpLinkable sentinel unification**:
   ```ruby
   update_all(purge_at: 'infinity') # WHERE purge_at = '9999-12-31...'
   ```

**Phase C — `lapses_at` integration for stale columns**:

1. **Backfill and drop the value of `revoked_at` to `lapses_at`** (24+ models):
   ```ruby
   # Already born in lapses_at='infinity' default → If revoked_at is past, LEAST is revoked_at
   execute(<<~SQL)
     UPDATE user_tokens SET lapses_at = LEAST(lapses_at, revoked_at) WHERE revoked_at IS NOT NULL;
   SQL
   remove_column :user_tokens, :revoked_at
   # Similarly *_verifications, *_authorization_codes, *_reauth_sessions, *_occurrences,
   # *_jump_links, *_preferences, *_secrets, single_use_token series
   ```
2. **backfill and drop the value of `expires_at` (credential variant) to `lapses_at`**:
   ```ruby
   execute(<<~SQL)
     UPDATE user_verifications SET lapses_at = LEAST(lapses_at, expires_at) WHERE expires_at IS NOT NULL;
   SQL
   remove_column :user_verifications, :expires_at
   # Similarly *_authorization_codes, *_reauth_sessions, *_secrets, organization_invitations, post_versions
   # NOTE: expires_at of tokens (user/staff/customer_token) is left unchanged
   ```
3. **backfill and drop the value of `refresh_expires_at` to `lapses_at`** (tokens 3 model):
   ```ruby
   execute(<<~SQL)
     UPDATE user_tokens SET lapses_at = LEAST(lapses_at, refresh_expires_at);
   SQL
   remove_column :user_tokens, :refresh_expires_at
   ```
4. **`lapses_at` integration of `compromised_at`** (single_use_token family):
   ```ruby
   execute(<<~SQL)
     UPDATE single_use_tokens SET lapses_at = LEAST(lapses_at, compromised_at) WHERE compromised_at IS NOT NULL;
   SQL
   remove_column :single_use_tokens, :compromised_at
   # forensic distinction maintained in occurrence log
   ```
5. **drop of `expired_at`** (user_token, customer_token):
   ```ruby
   # Since the data is equivalent to revoked_at, Phase C-1 has already been absorbed into lapses_at
   remove_column :user_tokens, :expired_at
   remove_column :customer_tokens, :expired_at
   ```

**Phase D — New CHECK constraint + concern integration**:

1. Add CHECK constraint with `NOT VALID` → online with `VALIDATE`:
   ```sql
   ALTER TABLE users ADD CONSTRAINT chk_users_retention_order
     CHECK (lapses_at <= purge_at) NOT VALID;
   ALTER TABLE users VALIDATE CONSTRAINT chk_users_retention_order;
   ```
2. Sorting out existing concerns:
   - Delete `app/models/concerns/token_deletable_sync.rb` (function is `Retainable` + distributed to
     token side callback)
   - `refresh_expires_at` reference of `app/models/concerns/refresh_tokenable.rb` to `lapses_at` and
     rename `ensure_refresh_expires_at` to `ensure_lapses_at`
   - `app/models/concerns/token_status_management.rb` Rewrite all
     `expired_at`/`revoked_at`/`refresh_expires_at` references to `lapses_at` and fallback chain
     (`column_names.include?("expired_at") ? :expired_at : :revoked_at`) is no longer needed so
     delete it
   - `revoked_at` defaults for `app/models/concerns/occurrence.rb` / `occurrence_status.rb` Replaced
     by `lapses_at`
   - All `FAR_FUTURE` / `revoked_at` / `deletable_at` of `app/models/concerns/jump_linkable.rb`
     Replace `Retainable` with `lapses_at`/`purge_at`
   - `revoked_at`/`compromised_at` reference of `app/models/concerns/single_use_token.rb` to
     `lapses_at` integrated into
   - Rewrite `expires_at` reference in `app/models/concerns/secret.rb` to `lapses_at`
3. Added `include Retainable` to all 24+ models.

**Phase E — `lapses_at` of app code** (after applying Retainable):

| File                                                                     | Changes                                                                                                                                                                                 |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/models/{user,staff,customer}_verification.rb`                       | `validates :expires_at` → `validates :lapses_at`, `scope :active` deleted, `active?` integrated into `accessible?`, `issue_for_token!(expires_at:)` → `issue_for_token!(lapses_at:)` ​​ |
| `app/models/{user,staff}_authorization_code.rb`                          | Similar. Expand `scope :valid` to raw `where('lapses_at > ?', now).where(consumed_at: nil)` on caller                                                                                   |
| `app/models/{user,staff,customer}_reauth_session.rb`                     | `validates :expires_at` → `lapses_at`, `expired?` → `lapsed?`                                                                                                                           |
| `app/models/{user,staff,customer}_secret.rb`                             | Integrate logic of `is_expired?` into `lapsed?`, delegate `Float::INFINITY` check to concern                                                                                            |
| `app/models/organization_invitation.rb`                                  | `expires_at` → `lapses_at`, `scope :active` / `:expired` Delete (written by caller with raw where)                                                                                      |
| `app/models/post_version.rb`                                             | `validates :expires_at` → `lapses_at`                                                                                                                                                   |
| `app/models/concerns/email.rb` / `telephone.rb`                          | `otp_expires_at` (sub-state) is left unchanged so no changes are required                                                                                                               |
| `app/services/auth/current_resource_resolver.rb`                         | Delete the two-stage branch of `expired_at`/`revoked_at` and create a single `where('lapses_at > ?', Time.current)`                                                                     |
| `app/services/oidc/single_logout_service.rb`                             | `update!(revoked_at: now, status: "revoked", ...)` → `update!(lapses_at: now, status: "revoked", ...)`                                                                                  |
| `app/services/oidc/token_exchange_service.rb`                            | `refresh_expires_at: REFRESH_TOKEN_TTL.from_now` → `lapses_at: REFRESH_TOKEN_TTL.from_now`                                                                                              |
| `app/services/sign/refresh_token_service.rb`                             | `attrs[:expired_at]` / `attrs[:revoked_at]` → `attrs[:lapses_at]`                                                                                                                       |
| `app/lib/sign/risk/enforcer.rb`                                          | Remove fallback chain (line 32, 50) of `expiry_column` to direct reference to `lapses_at`                                                                                               |
| `app/controllers/concerns/restricted_session_guard.rb`                   | `session.refresh_expires_at` / `session.expired_at` references merged into `session.lapses_at`                                                                                          |
| `app/controllers/concerns/verification/base.rb`                          | `expiry_column` Delete branch (line 185)                                                                                                                                                |
| `app/controllers/concerns/authentication/base/refresh_token_handlers.rb` | Same as above                                                                                                                                                                           |
| `app/controllers/concerns/authentication/base/dbsc_helpers.rb`           | Same as above                                                                                                                                                                           |
| `app/controllers/sign/{app,com}/settings/withdrawals_controller.rb`      | `scheduled_purge_at` reference merged into `purge_at` (line 56, 139, 140, 149)                                                                                                          |
| `app/views/sign/app/settingss/edit.html.erb`                             | `current_user.scheduled_purge_at` → `current_user.purge_at`, INFINITY judgment added (when displayed only for `purge_at != Float::INFINITY`)                                            |
| `app/views/sign/{app,org}/settings/sessions/index.html.erb`              | `session.refresh_expires_at` → `session.lapses_at`                                                                                                                                      |

### Solid Queue retention job

**Replacement target**: Raw of `purge_expired_risk_occurrences` of `config/recurring.yml` SQL is
anti-pattern.

**New design**:

```ruby
# app/jobs/retention_purge_job.rb
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = [
    User, Customer, Staff, AppPreference, OrgPreference, ComPreference,
    UserToken, OperatorToken, CustomerToken,
    UserVerification, OperatorVerification, CustomerVerification,
    UserAuthorizationCode, OperatorAuthorizationCode, CustomerAuthorizationCode,
    UserReauthSession, OperatorReauthSession, CustomerReauthSession,
    AreaOccurrence, UserOccurrence, OperatorOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence,
    AppJumpLink, ComJumpLink, OrgJumpLink
  ].freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where('purge_at <= ?', now).in_batches(of: batch_size).delete_all
    end
  end
end
```

```yaml
# config/recurring.yml
retention_purge:
  class: RetentionPurgeJob
  schedule: every 15 minutes
```

The old `purge_expired_risk_occurrences` entry has been deleted (the risk occurrence is also
`Retainable`). the same job picks up via).

**Design Note**:

- Use `delete_all` (callback skip). `destroy_all` is N+1 / dependent Because destroy runs, it gets
  clogged with a large amount of data. dependent Models that require destroy can be handled
  individually using override (currently not required).
- If the model is separate for each DB (principals / guests / operators / chronicle / settings /
  redirector), multiple connections will be made from a single Solid Queue process → for each model.
  Verify that the `connects_to` setting is effective.
- The model list is `Retainable.included_models` on the concern side There is an option to have a
  registry like this, but an explicit list is recommended as it is easier to audit.

### Tests (Minitest)

**New**:

- `test/models/concerns/retainable_test.rb`: instance method (accessible?/lapsed?/purgeable?),
  validation, `schedule_retention!` normal and exception systems, `>= created_at` verification,
  time-zero edge cases, raw `where('lapses_at > ?', now)` query via
- `test/jobs/retention_purge_job_test.rb`: Each model is `purge_at <= now` Only records in INFINITY
  will be deleted, records in INFINITY will remain, batch boundaries
- `test/migration/retention_consolidation_backfill_test.rb`: `LEAST(...)` in Phase B/C Make sure
  that backfill works correctly, especially for User/Customer.
  `deletable_at`+`shreddable_at`+`scheduled_purge_at` Triple integration, token of
  `revoked_at`+`expires_at`+`refresh_expires_at` Triple integration, chronicle system Validate
  `purge_at` rename of `expires_at`

**Existing renovation**:

- Rewrite `deletable_at` reference in all models test to `purge_at` (24+ models)
- Rewrite the `revoked_at` reference in all models test to `lapses_at` (occurrences, jump_links,
  tokens, verifications, auth_codes, sessions, single_use_tokens, preferences, secrets)
- All models test `expires_at` reference:
  - credential series (`*_verification`, `*_authorization_code`, `*_reauth_session`, `*_secret`,
    `organization_invitation`, `post_version`) → `lapses_at`
  - audit/chronicle → `purge_at`
  - **token series (`user_token`, `staff_token`, `customer_token`) remains unchanged**
- Merging `refresh_expires_at` / `expired_at` references in token test into `lapses_at`
- `shreddable_at` reference in User/Customer/Avatar/Member/Operator/Staff test to `purge_at`
- User/Customer test's `scheduled_purge_at` reference to `purge_at`
- single_use_token test `compromised_at` reference to `lapses_at`
- Check behavior after `include Retainable` for testing 24+ models (minimum `accessible?` /
  `purgeable?` (smoke test)
- contact / OAuth social sub-state column (`token_expires_at`, `verifier_expires_at`,
  `otp_expires_at`) is left unchanged so there is no need to change the test

### important file

**New**:

- `app/models/concerns/retainable.rb`
- `app/jobs/retention_purge_job.rb`
- `adr/retainable-concern-and-retention-purge.md` (using sentinel, `lapses_at`/`purge_at` Name,
  scope not adopted, sub-state column deferred reason to ADR)

**delete**:

- `app/models/concerns/token_deletable_sync.rb` (after functionality distribution in Phase D)

**Concern**:

- `app/models/concerns/refresh_tokenable.rb`: `refresh_expires_at` → `lapses_at`
- `app/models/concerns/token_status_management.rb`: `expired_at`/`revoked_at`/`refresh_expires_at`
  Remove fallback chain of `lapses_at` to single reference
- `app/models/concerns/occurrence.rb`, `occurrence_status.rb`: `revoked_at` defaults to `lapses_at`
  via
- `app/models/concerns/jump_linkable.rb`: `FAR_FUTURE` / `revoked_at` / `deletable_at` Delete,
  `Retainable` include
- `app/models/concerns/single_use_token.rb`: Integrate `revoked_at` / `compromised_at` into
  `lapses_at`
- `app/models/concerns/secret.rb`: `expires_at` → `lapses_at`
- 24+ Add `include Retainable` to model body and regenerate schema annotation

**Renovation (model)**:

- `app/models/{user,staff,customer}_verification.rb`
- `app/models/{user,staff}_authorization_code.rb`
- `app/models/{user,staff,customer}_reauth_session.rb`
- `app/models/{user,staff,customer}_secret.rb`
- `app/models/{user,staff,customer}_token.rb`
- `app/models/{user,customer}.rb` (User's line 159 scope is resolved naturally by rename)
- `app/models/{staff,operator,avatar,member}.rb`
- `app/models/{app,com,org}_jump_link.rb`
- `app/models/{app,com,org}_preference.rb`
- `app/models/*_occurrence.rb` (9 types in total)
- `app/models/post.rb`, `app/models/post_version.rb`
- `app/models/organization_invitation.rb`
- chronicle series: `app/models/{app,com,org}_contact_chronicle.rb`, `*_preference_chronicle.rb`,
  `staff/user_chronicle.rb`, `*_activity.rb` etc.

**Renovation (service / lib / controller / view)**:

- `app/services/auth/current_resource_resolver.rb`
- `app/services/oidc/single_logout_service.rb`, `oidc/token_exchange_service.rb`
- `app/services/sign/refresh_token_service.rb`
- `app/lib/sign/risk/enforcer.rb`
- `app/controllers/concerns/restricted_session_guard.rb`
- `app/controllers/concerns/verification/base.rb`
- `app/controllers/concerns/authentication/base/refresh_token_handlers.rb`
- `app/controllers/concerns/authentication/base/dbsc_helpers.rb`
- `app/controllers/sign/{app,com}/settings/withdrawals_controller.rb`
- `app/views/sign/{app,com}/settingss/edit.html.erb`
- `app/views/sign/{app,org}/settings/sessions/index.html.erb`

**Renovations (config)**:

- `config/recurring.yml`: Add `retention_purge`, remove `purge_expired_risk_occurrences`

**Migration group** (issued in 4 stages of Phase A → B → C → D for each DB, or compressed into one):

| DB                                                                  | Migration file                                                    | Main processing                                                                                                                                                                                                        |
| ------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| principals                                                          | `add_lapses_at_and_consolidate_retention_on_principals.rb`        | User/Customer: `+lapses_at` / `deletable_at→purge_at` / `shreddable_at` integration / `scheduled_purge_at` integration / `revoked_at`+`expires_at` (related) integration                                               |
| guests                                                              | `add_lapses_at_and_consolidate_retention_on_guests.rb`            | contacts (sub-state is left unchanged)                                                                                                                                                                                 |
| operators                                                           | `add_lapses_at_and_consolidate_retention_on_operators.rb`         | Staff: `+lapses_at` / `deletable_at→purge_at` / `shreddable_at` Integration                                                                                                                                            |
| chronicle (audit)                                                   | `rename_expires_at_to_purge_at_and_add_lapses_at_on_chronicle.rb` | audit/chronicle Total 13+ tables: `expires_at`(7yr) → `purge_at` rename / `+lapses_at`                                                                                                                                 |
| occurrences                                                         | `consolidate_retention_on_occurrences.rb`                         | 9 species \*\_occurrence: `+lapses_at` / `deletable_at→purge_at` / `revoked_at→lapses_at` integration                                                                                                                  |
| settings                                                            | `consolidate_retention_on_preferences.rb`                         | preferences (3): `+lapses_at` / `deletable_at→purge_at` / `expires_at`+`revoked_at` integration                                                                                                                        |
| redirector                                                          | `consolidate_retention_on_jump_links.rb`                          | jump_links (3): `9999` sentinel → `infinity` / `+lapses_at` / `deletable_at→purge_at` / `revoked_at→lapses_at`                                                                                                         |
| avatar                                                              | `consolidate_retention_on_avatars.rb`                             | Avatar/Member: `+lapses_at` / `shreddable_at→purge_at`                                                                                                                                                                 |
| token                                                               | `consolidate_retention_on_tokens.rb`                              | user/staff/customer_token: `+lapses_at` / `deletable_at→purge_at` / `refresh_expires_at→lapses_at` integration / `expired_at` drop / `revoked_at→lapses_at` integration (NOTE: token `expires_at` ​​remains unchanged) |
| mark / symbol (verifications, auth_codes, reauth_sessions, secrets) | `consolidate_retention_on_credentials.rb`                         | `+lapses_at` / `deletable_at→purge_at` / `expires_at→lapses_at` / `revoked_at→lapses_at`                                                                                                                               |

---

## Verification

### unit test

```bash
bin/rails test test/models/concerns/retainable_test.rb
bin/rails test test/jobs/retention_purge_job_test.rb
bin/rails test test/models/concerns/reference_record_test.rb  # Theme 1
```

### controller test all

```bash
bin/rails test test/controllers/
```

(After reinforcement of Theme 2, the test corresponding to approximately 287 GET routes should be
green)

### Migration dry-run + rollback

```bash
bin/rails db:migrate
bin/rails db:rollback STEP=N # N is the number of migration to be added this time
bin/rails db:migrate
```

Check separately in each DB (principals/guests/operators/chronicle/settings/redirector):

```bash
bin/rails db:migrate:status
```

### Solid Queue actual machine verification

```bash
bin/rails runner '
  u = User.create!(...)
  u.update!(purge_at: 1.minute.ago) # In the route that passes through validation
  RetentionPurgeJob.perform_now
  raise "purge failed" if User.exists?(u.id)
'
```

recurring schedule:

```bash
bin/rails solid_queue:start
# Check the logs to see `retention_purge` firing every 15 minutes
```

### C/D Integration Integrity Verification

```bash
bin/rails runner '
  # The old column has been completely deleted
  removed = {
    UserToken => %w[revoked_at expired_at refresh_expires_at deletable_at],
    UserVerification => %w[revoked_at expires_at deletable_at],
    UserAuthorizationCode => %w[revoked_at expires_at deletable_at],
    AppJumpLink => %w[revoked_at deletable_at],
    User => %w[deletable_at shreddable_at scheduled_purge_at],
    AppContactChronicle => %w[expires_at]
  }
  removed.each do |klass, cols|
    bad = cols.select { |c| klass.column_names.include?(c) }
    raise "#{klass}: old columns still present #{bad.inspect}" if bad.any?
  end

  # token sub-state remain
  raise "UserToken expires_at disappeared" unless UserToken.column_names.include?("expires_at")
  raise "AppContact token_expires_at disappeared" unless AppContact.column_names.include?("token_expires_at")
  raise "AppContactEmail verifier_expires_at disappeared" unless AppContactEmail.column_names.include?("verifier_expires_at")

  # The new columns must be lapses_at + purge_at
  [User, UserToken, UserVerification, UserAuthorizationCode, AppJumpLink,
   AreaOccurrence, AppPreference, AppContactChronicle].each do |klass|
    %w[lapses_at purge_at].each do |c|
      raise "#{klass}: #{c} is missing" unless klass.column_names.include?(c)
    end
  end
  puts "C/D consolidation integrity OK"
'
```

### Existing sentinel data integrity

```bash
bin/rails runner '
  models = [User, Customer, Staff, AppJumpLink, OrgJumpLink, ComJumpLink]
  models.each do |m|
    bad = m.where("purge_at < ?", "9999-01-01") # NOT NULL, so IS NULL is unnecessary
    puts "#{m.name}: #{bad.count} records" # 0 expected
  end
'
```

### global regression

```bash
bin/rails test
vp test # JS It shouldn't affect the side, but just in case
```

---

## open matters

1. **Handling of `NOTHING = 1` / `11` in Reference table** — If it is necessary to remap the
   existing FK value, release it to the Exception clause of ADR as outside the scope of this PR. The
   final decision will be made during the migration design phase.
2. **Decision to leave Token `expires_at` (access TTL)** — `lapses_at` (refresh outer maintains a
   two-tier structure with bound). To preserve OAuth/OIDC semantics. ADR "token" inside TTL as
   sub-state "`expires_at` will remain."
3. **Solid Queue cross-DB transactions** — 8+ A retry strategy in case of failure when cycling
   through models distributed in a DB in one job. 1 Catch failures in each model, leave only a log,
   and continue with other models error A swallowing pattern may be required (recommended).
4. **Forensic distinction loss of `compromised_at`** — `compromised_at` and `lapses_at` in
   single_use_token system When integrated with ``Compromised / The distinction between
   “revoke/natural expire” disappears from the DB. Alternatively, Single use When a token is
   compromised, the corresponding `\*\_occurrence` record (security event log) is specified in ADR.
5. **rename of `published_at`** — past participle + future time discomfort problem. Out of scope of
   this PR, issue [#789](https://github.com/seahal/umaxica-apps-global/issues/789) Separated into.
   This will not be discussed again in this conversation.
6. **Migration order (compress or split Phase A→B→C→D into 1 PR)** — If you want to minimize the
   downtime of production deployment, multiple PRs for each phase / Multiple releases are safe.
   However, since we have already decided on a "batch migration," we will first conduct a
   verification run in which all phases are run at once in a staging environment.
