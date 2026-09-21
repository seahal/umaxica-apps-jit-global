# Retainable Concern and Retention Purge Design

## situation

Accepted

## context

Applications require retention management in many models, but the current challenges include:

1. The columns representing physical deletion time are `deletable_at`, `shreddable_at`,
   `scheduled_purge_at` etc., and are not unified.
2. Columns representing logical deletion time also include `revoked_at`, `expires_at`,
   `refresh_expires_at`, `compromised_at` There are multiple such as
3. Each model manages these columns differently and is inconsistent

## decision

### Column unification

1. **`discard_at`** - Logical deletion time (time when access becomes impossible)
2. **`purge_eligible_at`** - Physical deletion candidate time (time when data can actually be deleted)

`discard_at` is intentionally a domain-specific retention name rather than a `discard` gem
integration. In order to maintain the time window semantics of the existing Retainable,
`discard_at = Float::INFINITY` is equivalent to the unrevoked sentinel, and
`discard_at <= Time.current` is treated as inaccessible. Switching to discard gem `NULL = kept`
semantics is a separate task after the time window usage has been separated into separate columns.

### Introducing Retainable Concern

Use `Retainable` concern, which is common to all models, to centrally manage the above two columns.

```ruby
module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :discard_at, :datetime, default: -> { SENTINEL }
    attribute :purge_eligible_at, :datetime, default: -> { SENTINEL }

    validates :discard_at, presence: true
    validates :purge_eligible_at, presence: true
    validate :retention_order_valid
    validate :retention_times_not_before_created_at, on: :update
  end

  def accessible?
    discard_at > Time.current
  end

  def lapsed?
    discard_at <= Time.current
  end

  def purgeable?
    purge_eligible_at <= Time.current
  end

  def schedule_retention!(discard_at:, purge_eligible_at:)
    raise ArgumentError, 'discard_at must be in the future' if discard_at <= Time.current
    raise ArgumentError, 'purge_eligible_at must be in the future' if purge_eligible_at <= Time.current
    raise ArgumentError, 'discard_at must be <= purge_eligible_at' if discard_at > purge_eligible_at
    update!(discard_at: discard_at, purge_eligible_at: purge_eligible_at)
  end
end
```

### Consolidated map of columns

#### Columns to be integrated into `discard_at`

- `revoked_at`
- `expires_at` (credential variant)
- `refresh_expires_at`
- `compromised_at`

#### Columns to be integrated into `purge_eligible_at`

- `deletable_at`
- `shreddable_at`
- `scheduled_purge_at`
- `expires_at` (audit/chronicle variant)

#### Column to delete

- `expired_at` (user_token, customer_token)

#### Column to be deferred (sub-state column)

- `token_expires_at`
- `verifier_expires_at` / `otp_expires_at`
- `expires_at` (token only: user/staff/customer_token)
- `consumed_at`
- `used_at`

### Solid Queue retention job

Create a RetentionPurgeJob to periodically delete records that are `purge_eligible_at` old.

```ruby
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = [
    User, Customer, Staff, AppPreference, OrgPreference, ComPreference,
    UserToken, OperatorToken, CustomerToken,
    UserVerification, OperatorVerification, CustomerVerification,
    UserAuthorizationCode, OperatorAuthorizationCode, CustomerAuthorizationCode,
    ClientStepUpSession, OperatorStepUpSession, VisitorStepUpSession,
    AreaOccurrence, UserOccurrence, OperatorOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence
  ].freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where('purge_eligible_at <= ?', now).in_batches(of: batch_size).delete_all
    end
  end
end
```

DB-backed JumpLink records were removed when redirect handling moved to the external Jump gateway
and signed `rt` tokens.

## reason

1. By unifying columns, the complexity of retention management is significantly reduced.
2. `discard_at` and `purge_eligible_at` make the two retention meanings explicit without
   coupling the schema to a discard-gem convention
3. `Retainable` concern provides consistent interface across all models
4. Efficiently perform physical deletion processing with Solid Queue job
5. `discard_at` / `purge_eligible_at` use `Float::INFINITY` as the sentinel value to simplify
   the query while preserving the existing time window semantics.

## influence

- Column name change and data migration required for models with 24 or more
- Change references in existing controllers and services to new column names
- The test code also needs to be adapted to the new column names.
- The existing implementation `lapses_at` is exposed as an alias for `discard_at`
- Because the schema is unreleased, existing Retainable columns were renamed directly to
  `discard_at` / `purge_eligible_at`; no compatibility columns or double writes are retained.
