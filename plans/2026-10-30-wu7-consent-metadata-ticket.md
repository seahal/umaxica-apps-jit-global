# WU-7 local test consent metadata removal

The owner authorized section 4.3 destructive migration and rebuilding non-production databases.
This execution is limited to `test_com_setting_db` on the local `primary` service. Production and
Neon are excluded.

Before: `com_preference_cookies` has nullable `consent_version` and `consented_at` columns.
After: those columns are removed; explicit new consent decisions use the independent
`com_preference_consent_receipts` row. The receipt version identifies a decision revision, not a
policy version. No legacy value is fabricated or migrated by this schema change.

The pre-execution query found two cookie rows, zero non-null values in either legacy column, one
consented row without a receipt, and zero receipts. That old row is retained, but current reads do
not treat it as affirmative consent because it has no receipt. The migration locks the cookie table
and refuses to proceed if either old column contains a value. The exclusive lock can block writers;
local timing cannot estimate production impact.

The pre-change local test database custom-format dump is
`/tmp/wu7-consent-metadata-20261030/test_com_setting_db.dump`, SHA-256
`3a9690e5d715c2e827fc2d6a2ac31f286e0cc026878d509cf4c13dec43d9776a`.
`pg_restore --list` succeeded; restoring this particular dump has not been rehearsed. Recovery is to
stop database users, restore the dump into a separate local database with `pg_restore --no-owner
--no-acl`, verify its schema and contents, and restore corresponding code before any authorized
replacement of the target. This backup does not form an atomic snapshot with the separate Chronicle
database. The migration itself is irreversible and its down path instructs restoration from backup.
