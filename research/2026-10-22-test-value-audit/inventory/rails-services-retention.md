# rails-services-retention: per-definition ledger

3 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/services/retention/cross_database_child_purge_test.rb`

[test/services/retention/cross_database_child_purge_test.rb](../../../test/services/retention/cross_database_child_purge_test.rb); SHA-256: `2f3b4393aedf0d799de0ee8851e16aafc034fa0f8a9b3285201e3135e5e30156`.

File-level implementation candidates (including setup/import context): [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/concerns/public_id.rb:7](../../../app/models/concerns/public_id.rb#L7); [app/models/client_status.rb:11](../../../app/models/client_status.rb#L11); [app/models/client_notification_record.rb:21](../../../app/models/client_notification_record.rb#L21); [app/models/avatar_capability.rb:12](../../../app/models/avatar_capability.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-12270"></a>T-12270 / [10](../../../test/services/retention/cross_database_child_purge_test.rb#L10) | "deletes non-audit cross-database children but retains chronicle audit"<br>Owner: `Retention::CrossDatabaseChildPurgeTest` | `assert_not ClientNotificationRecord.exists?(notification.id),`; `assert_not AvatarAssignment.exists?(assignment.id),`; `assert ClientChronicle.exists?(chronicle.id),` | [Client](../../../app/models/client.rb#L76); [PublicId](../../../app/models/concerns/public_id.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-12271"></a>T-12271 / [38](../../../test/services/retention/cross_database_child_purge_test.rb#L38) | "client purge retries the remaining database after a partial failure"<br>Owner: `Retention::CrossDatabaseChildPurgeTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_not ClientNotificationRecord.exists?(notification.id)`; `assert AvatarAssignment.exists?(assignment.id)`; +3 further assertion lines | [Client](../../../app/models/client.rb#L76); [PublicId](../../../app/models/concerns/public_id.rb#L7) | S: static inventory; individual semantic review open | stubbed-boundary |
| <a id="t-12272"></a>T-12272 / [66](../../../test/services/retention/cross_database_child_purge_test.rb#L66) | "is a no-op for unknown actor types"<br>Owner: `Retention::CrossDatabaseChildPurgeTest` | `assert_nothing_raised do` | [RetentionCrossDatabaseChildPurge](../../../app/services/retention_cross_database_child_purge.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
