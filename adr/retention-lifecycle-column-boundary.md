# Boundary Between Retention and Lifecycle Columns

## Status

Accepted (2026-05-25)

## Context

`adr/retainable-concern-and-retention-purge.md` standardized retention on `discarded_at` for logical
discard and `purged_at` for physical-deletion eligibility. `Retainable` and `RetentionPurgeJob`
implement that decision. Several inconsistencies remained:

1. Only `clients` retained the obsolete `deletable_at` alongside `purged_at` and `discarded_at`.
   `RetentionPurgeJob` reads only `purged_at`, making `deletable_at` dead.
2. `SignUp::Cancellation` and `SignUp::ArtifactCleanup` retained defensive branches that wrote
   `deletable_at` solely for that dead column.
3. Client lifecycle timestamps such as `withdrawn_at`, `deactivated_at`, `terminated_at`, and
   `withdrawal_started_at` are not retention timestamps. Treating them as retention would mix
   withdrawal, suspension, and anonymization with deletion and risk unintended purges.
4. `RefreshTokenable#default_lapses_at` writes the domain concept `lapses_at` to `discarded_at`, but
   the relationship between domain aliases and database columns was undocumented.

The retention authority existed, but its boundary and alias policy did not, allowing vocabulary
drift.

## Decision

### 1. There Are Exactly Two Retention Columns

No other database column name may be introduced for retention:

| Column         | Meaning                                                                          | Type     | Default           | Nullability |
| -------------- | -------------------------------------------------------------------------------- | -------- | ----------------- | ----------- |
| `discarded_at` | Logical-discard time; the row is no longer referenced when `<= now`              | datetime | `Float::INFINITY` | NOT NULL    |
| `purged_at`    | Physical-deletion eligibility time consumed by `RetentionPurgeJob` when `<= now` | datetime | `Float::INFINITY` | NOT NULL    |

Enforce `discarded_at <= purged_at` with `chk_<table>_retention_order`. Model validation through
`Retainable#retention_times_not_before_created_at` enforces that both values are at or after
`created_at`.

### 2. Lifecycle Columns Remain Separate

These timestamps describe actor lifecycle, not retention:

| Column                  | Meaning                     | Relationship to retention                                                                |
| ----------------------- | --------------------------- | ---------------------------------------------------------------------------------------- |
| `withdrawn_at`          | Withdrawal completed        | Withdrawal is not logical deletion; legal retention may leave `discarded_at` at infinity |
| `withdrawal_started_at` | Withdrawal flow began       | Sequencing only; no retention effect                                                     |
| `deactivated_at`        | Administratively disabled   | Suspension is reversible and is not deletion                                             |
| `terminated_at`         | PII anonymization completed | A row remains until `purged_at <= now` even after anonymization                          |

New lifecycle columns must name a non-deletion event explicitly. Never implicitly derive
`discarded_at` or `purged_at` from these timestamps; for example, withdrawal must not automatically
set `discarded_at = now`.

### 3. Express Domain Aliases as Model Instance Methods

When a domain calls `discarded_at` by a more specific name, such as token lapse, verification
expiry, or authorization-code revocation, retain one database column and expose an instance-method
alias:

```ruby
class ClientRefreshToken < AppTicketRecord
  include Retainable

  def lapses_at         = discarded_at
  def lapses_at=(value) = self.discarded_at = value
end
```

Do not add another column. Additional columns fragment purge scans, duplicate constraints and index
policy, and bypass the single `Retainable` interface.

### 4. Index Policy

- Add a normal b-tree index for `discarded_at`.
- Add a partial b-tree index for `purged_at` with `WHERE purged_at < 'infinity'`; most rows remain
  at infinity, making a full index wasteful.
- Decide lifecycle-column indexes separately, normally as partial indexes where the column is not
  null.

### 5. One Physical-Deletion Worker

Only `RetentionPurgeJob` physically deletes rows. Services and controllers may schedule `purged_at`;
the worker alone selects `where(purged_at: ..now)` and calls `delete_all`.

Anonymizers such as `Withdrawal::PersonalDataAnonymizer` may be invoked by the worker before
deletion. This separates PII anonymization from row purging without distributing retention
eligibility logic.

### 6. Prohibited Retention Vocabulary

Do not introduce `deletable_at`, `shreddable_at`, `scheduled_purge_at`, or `expired_at` as retention
columns. Audit expiry uses `purged_at`; credential expiry uses `discarded_at`. `lapses_at` is
prohibited as a column but permitted as a domain instance-method alias.

### 7. Requirements for New Retainable Tables

Every migration adding a retainable table must include:

- `discarded_at` and `purged_at` datetimes with infinity defaults and NOT NULL;
- the ordered-retention CHECK constraint;
- a normal `discarded_at` index and partial `purged_at` index;
- `include Retainable` in the model; and
- the model in `RetentionPurgeJob::RETAINABLE_MODELS`.

## Consequences

- The earlier two-column retention, `Retainable`, and `RetentionPurgeJob` decisions remain in force;
  this ADR defines their boundary and operational rules.
- `clients.deletable_at` is a dead, noncompliant column tracked for removal in
  `plans/backlog/retention-vocabulary-drift-cleanup.md`.
- The defensive `has_attribute?(:deletable_at)` branches in sign-up cleanup are removed by that
  plan.
- `RefreshTokenable#default_lapses_at` remains as the approved domain-alias pattern and must be
  documented as an alias for `discarded_at`.
- Lifecycle timestamp behavior belongs in separate ADRs or plans; this ADR defines only its
  separation from retention.
- Translating and updating older ADR vocabulary is separate from this decision.
