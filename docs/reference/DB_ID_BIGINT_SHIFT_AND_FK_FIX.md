# Database Refactoring: ID Unification and Consistency Fixes

This is a historical implementation report, not the current identifier or migration contract. Its
UUIDv7 recommendation and destructive/raw-SQL techniques do not authorize new work. Use the
[accepted identifier ADR](../../adr/identifier-contract.md),
[current conventions](identifier-conventions.md) and applicable migration approval boundaries.
Historical success statements below do not establish current catalog or acceptance results.

## Overview

This document details the refactoring of database schemas to unify ID types to `bigint` and resolve
`database_consistency` Priority A issues (Foreign Keys, Cascade options, Column Presence).

## Changes Made

### 1. ID Unification (Integer -> Bigint)

We converted primary keys and foreign keys from `integer` (or `smallint`) to `bigint` across
multiple domains.

- **Audit Domain**: `*_audit_events`, `*_audit_levels`, and reference columns in `*_audits` tables.
- **Principal Domain**: `user_identity_audit_events`, `user_identity_audit_levels`,
  `user_identity_audits` FKs. `clients.status_id` (smallint) was removed in favor of
  `client_status_id` (bigint).
- **Token Domain**: `staff_token_kinds`, `staff_token_statuses`, `user_token_kinds`,
  `user_token_statuses` tables were recreated with proper keys, and `*_tokens` tables updated.
- **Preference Domain**: `status_id` (converted from string "NEYO" to bigint 0), `option_id`.
- **Occurrence Domain**: `status_id` (converted from string to bigint).

### 2. Foreign Key Fixes

- Added missing Foreign Keys in `Token` domain (`staff_tokens` -> kind/status).
- Updated Foreign Keys in `Preference`, `Audit`, `Principal`, `Occurrence` domains to match new
  `bigint` columns.
- Enforced `ON DELETE SET NULL` (`:nullify`) for `Contact` domain statuses (`org_contacts`,
  `com_contacts`, `app_contacts` -> statuses).

### 3. Constraint Fixes

- Enforced `NOT NULL` on `public_id` (UUIDv7) and `status_id` columns where appropriate (backfilling
  with defaults or deleting invalid rows).
- Enabled `citext` extension in `Token` and `Principal` databases to support case-insensitive codes
  for reference tables.

### 4. Technical Approach

- Using `safety_assured` and `disable_ddl_transaction!` to handle large-scale changes.
- Using raw SQL (`ALTER TABLE`, `TRUNCATE`, `DROP DEFAULT`) to bypass rigid `StrongMigrations`
  checks and type casting issues (e.g., String default blocking Integer cast).
- Recreating reference tables (`*_kinds`, `*_statuses`, `*_events`) to ensure clean state with
  `citext` codes and `bigint` IDs.

## Remaining Issues (Potential)

- `database_consistency` might still flag issues if `db/schema.rb` dump is incomplete or cached.
- `AnnotateRb` post-migration hook might fail on some environments due to schema introspection
  issues, but migrations themselves are committed.

## Migrations

- `db/activity_migrate/20260202180000_fix_audit_pks_and_fks.rb`
- `db/preferences_migrate/20260202181000_fix_preference_fks.rb`
- `db/tokens_migrate/20260202182000_fix_token_pks.rb`
- `db/tokens_migrate/20260202190000_ensure_token_tables.rb`
- `db/occurrences_migrate/20260202183000_fix_occurrence_fks.rb`
- `db/defaults_migrate/20260202184000_fix_contact_fks.rb`
- `db/principals_migrate/20260202185000_fix_principal_consistency.rb`
