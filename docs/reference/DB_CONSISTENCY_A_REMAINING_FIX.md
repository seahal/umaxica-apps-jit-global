# DB Consistency Priority A Fixes - Remaining Issues Resolution

This is a historical migration report, not current verification or operation authorization.
Revalidate its table/column names and results against the actual checkout/catalog. Current
identifier requirements belong to the [identifier ADR](../../adr/identifier-contract.md) and
[conventions](identifier-conventions.md); do not infer approval for destructive repair from this
report.

## Overview

This document details the fixes applied to resolve Priority A `database_consistency` issues. The
focus was on:

- Foreign key constraints
- ON DELETE rules
- NOT NULL constraints on specific columns
- Primary key type conversion to `bigint`

## Migrations Created

### 1. Principal Domain

#### `20260202200000_fix_clients_status_relations.rb`

- Adds `status_id` column to `clients` table (bigint, NOT NULL)
- Creates FK: `clients.status_id -> client_statuses.id`
- Enforces NOT NULL on `clients.public_id`

#### `20260202200100_fix_principal_public_id_not_null.rb`

- Enforces NOT NULL on `users.public_id`
- Enforces NOT NULL on `user_one_time_passwords.public_id`

### 2. Guest Domain

#### `20260202200000_fix_contact_fks_nullify.rb`

- Adds ON DELETE SET NULL to contact status FKs

#### `20260202200100_fix_contact_status_fks_nullify.rb`

- Replaces `org_contacts.status_id -> org_contact_statuses` FK with ON DELETE SET NULL

#### `20260202200200_fix_com_contact_status_fk_nullify.rb`

- Replaces `com_contacts.status_id -> com_contact_statuses` FK with ON DELETE SET NULL

### 3. Operator Domain

#### `20260202200000_fix_operator_fks_and_pks.rb`

- Recreates `department_statuses` with bigint PK
- Recreates `staff_secret_kinds` with bigint PK
- Converts `departments.department_status_id` to bigint
- Converts `staff_one_time_passwords.staff_one_time_password_status_id` to bigint
- Converts `staff_secrets.staff_secret_kind_id` to bigint
- Adds FK constraints for these columns
- Enforces NOT NULL on:
  - `operators.public_id`
  - `departments.name`
  - `staff_emails.staff_id`, `staff_emails.address`, `staff_emails.otp_counter`,
    `staff_emails.otp_private_key`
  - `staff_telephones.staff_id`, `staff_telephones.number`, `staff_telephones.otp_counter`,
    `staff_telephones.otp_private_key`
  - `staff_passkeys.external_id`, `staff_passkeys.public_key`, `staff_passkeys.sign_count`
  - `staff_secrets.name`

#### `20260202200100_fix_department_status_fk.rb`

- Ensures `departments.department_status_id -> department_statuses.id` FK exists

### 4. News Domain (Timeline)

#### `20260202200000_convert_timeline_masters_to_bigint.rb`

- Converts all timeline master table PKs from smallint to bigint:
  - `org_timeline_tag_masters`
  - `org_timeline_statuses`
  - `org_timeline_category_masters`
  - `com_timeline_tag_masters`
  - `com_timeline_statuses`
  - `com_timeline_category_masters`
  - `app_timeline_tag_masters`
  - `app_timeline_statuses`
  - `app_timeline_category_masters`
- Updates referencing FK columns to bigint
- Re-establishes FK constraints

#### `20260202200100_fix_timeline_masters_parent_id_not_null.rb`

#### `20260202200200_fix_remaining_consistency_issues.rb`

- Enforces NOT NULL on `parent_id` for:
  - `org_timeline_tag_masters`
  - `org_timeline_category_masters`
  - `com_timeline_tag_masters`
  - `com_timeline_category_masters`
  - `app_timeline_tag_masters`
  - `app_timeline_category_masters`

### 5. Document Domain

#### `20260202200000_fix_document_masters_parent_id.rb`

- Enforces NOT NULL on `parent_id` for:
  - `org_document_tag_masters`
  - `org_document_category_masters`
  - `com_document_tag_masters`
  - `com_document_category_masters`
  - `app_document_tag_masters`
  - `app_document_category_masters`
- Inserts ROOT rows where needed

### 6. Message Domain

#### `20260202200000_fix_message_cascade.rb`

- Replaces FKs with ON DELETE CASCADE:
  - `client_messages.user_message_id -> user_messages`
  - `admin_messages.staff_message_id -> staff_messages`
- Enforces NOT NULL on `public_id` for all message tables

### 7. Notification Domain

#### `20260202200000_fix_notification_cascade.rb`

- Replaces FKs with ON DELETE CASCADE:
  - `client_notifications.user_notification_id -> user_notifications`
  - `admin_notifications.staff_notification_id -> staff_notifications`

## Resolved Issues

### ForeignKeyChecker

- ✅ `clients.status_id` FK to `client_statuses`
- ✅ `staff_one_time_passwords.staff_one_time_password_status_id` FK
- ✅ Timeline master FKs

### ForeignKeyCascadeChecker

- ✅ `OrgContactStatus` / `ComContactStatus` with ON DELETE SET NULL
- ✅ `UserNotification` / `OperatorNotification` with ON DELETE CASCADE
- ✅ `UserMessage` / `StaffMessage` with ON DELETE CASCADE

### PrimaryKeyTypeChecker

- ✅ All timeline master tables converted to bigint
- ✅ `department_statuses` converted to bigint
- ✅ `staff_secret_kinds` converted to bigint

### ColumnPresenceChecker

- ✅ `public_id` NOT NULL for users, clients, operators, messages
- ✅ `parent_id` NOT NULL for document masters
- ✅ `parent_id` NOT NULL for timeline masters
- ✅ `departments.name` NOT NULL
- ✅ Staff field NOT NULL constraints

## Remaining Known Issues

### ColumnPresenceChecker: Contact status_id NOT NULL

The requirement for `org_contact_status` / `com_contact_status` FK columns to be NOT NULL conflicts
with the ON DELETE SET NULL behavior. We prioritized the ON DELETE SET NULL requirement from
`ForeignKeyCascadeChecker`, which means these columns must remain nullable.

## Additional Model Fixes

### DepartmentStatus Model

Created `/app/models/department_status.rb` to properly represent the `department_statuses` table.

### Department Model Update

Updated `belongs_to :department_status` to use `class_name: "DepartmentStatus"` instead of
`"OrganizationStatus"` to correctly reference the `department_statuses` table.

## How to Apply

```bash
SAFETY_ASSURED=1 bin/rails db:migrate
```

## How to Verify

```bash
bundle exec database_consistency | grep -E "(ForeignKey|PrimaryKeyType)"
```

Expected output should only show model-level issues, not DB-level FK or PK type issues.
