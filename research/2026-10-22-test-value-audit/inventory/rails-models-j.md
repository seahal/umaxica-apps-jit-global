# rails-models-j: per-definition ledger

16 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/jump_link_retirement_test.rb`

[test/models/jump_link_retirement_test.rb](../../../test/models/jump_link_retirement_test.rb); SHA-256: `ff68e54a90e3ae36a2ba210597ccb660bcfad833e0d0e0b89c395d2fb87c9125`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07518"></a>T-07518 / [7](../../../test/models/jump_link_retirement_test.rb#L7) | "legacy DB-backed jump link models are not available"<br>Owner: `JumpLinkRetirementTest` | `assert_not Object.const_defined?(:AppJumpLink)`; `assert_not Object.const_defined?(:ComJumpLink)`; `assert_not Object.const_defined?(:OrgJumpLink)`; +1 further assertion lines | unresolved | S: static inventory; individual semantic review open | static-token-duplicate; [DUP-0074](../duplicates.md#dup-0074) |

## `test/models/jwt_anomaly_event_test.rb`

[test/models/jwt_anomaly_event_test.rb](../../../test/models/jwt_anomaly_event_test.rb); SHA-256: `26c9297ebc86c7126f54445b4ba9449377f9a59adfcc8a788b3b291a7cae705f`.

File-level implementation candidates (including setup/import context): [app/models/jwt_anomaly_event.rb:35](../../../app/models/jwt_anomaly_event.rb#L35).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07519"></a>T-07519 / [40](../../../test/models/jwt_anomaly_event_test.rb#L40) | "validates code presence"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:code], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07520"></a>T-07520 / [53](../../../test/models/jwt_anomaly_event_test.rb#L53) | "validates code maximum length"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:code], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07521"></a>T-07521 / [66](../../../test/models/jwt_anomaly_event_test.rb#L66) | "validates request_host maximum length"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:request_host], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07522"></a>T-07522 / [79](../../../test/models/jwt_anomaly_event_test.rb#L79) | "validates presence of metadata"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:metadata], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07523"></a>T-07523 / [92](../../../test/models/jwt_anomaly_event_test.rb#L92) | "validates presence of occurred_at"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:occurred_at], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07524"></a>T-07524 / [105](../../../test/models/jwt_anomaly_event_test.rb#L105) | "validates kid maximum length"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:kid], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07525"></a>T-07525 / [119](../../../test/models/jwt_anomaly_event_test.rb#L119) | "validates error_message maximum length"<br>Owner: `JwtAnomalyEventTest` | `assert_not_predicate event, :valid?`; `assert_predicate event.errors[:error_message], :present?` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07526"></a>T-07526 / [133](../../../test/models/jwt_anomaly_event_test.rb#L133) | "belongs_to jwt_occurrence"<br>Owner: `JwtAnomalyEventTest` | `assert event.jwt_occurrence`; `assert_equal jwt_occurrences(:auth_user_malformed_token), event.jwt_occurrence` | [JwtAnomalyEvent](../../../app/models/jwt_anomaly_event.rb#L35) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/jwt_occurrence_status_test.rb`

[test/models/jwt_occurrence_status_test.rb](../../../test/models/jwt_occurrence_status_test.rb); SHA-256: `59180d4714a0e78f7bdb06e52c72a4a74514a0c6cb846790f598b27b771ff087`.

File-level implementation candidates (including setup/import context): [app/models/jwt_occurrence_status.rb:12](../../../app/models/jwt_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07527"></a>T-07527 / [16](../../../test/models/jwt_occurrence_status_test.rb#L16) | "can load nothing status from db"<br>Owner: `JwtOccurrenceStatusTest` | `assert_not_nil nothing`; `assert_equal 0, nothing.id` | [JwtOccurrenceStatus](../../../app/models/jwt_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07528"></a>T-07528 / [23](../../../test/models/jwt_occurrence_status_test.rb#L23) | "accepts integer ids"<br>Owner: `JwtOccurrenceStatusTest` | `assert_predicate record, :valid?` | [JwtOccurrenceStatus](../../../app/models/jwt_occurrence_status.rb#L12) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07529"></a>T-07529 / [29](../../../test/models/jwt_occurrence_status_test.rb#L29) | "constants are defined"<br>Owner: `JwtOccurrenceStatusTest` | `assert_equal 0, JwtOccurrenceStatus::NOTHING`; `assert_equal 2, JwtOccurrenceStatus::ACTIVE`; `assert_equal 3, JwtOccurrenceStatus::INACTIVE`; +1 further assertion lines | [JwtOccurrenceStatus](../../../app/models/jwt_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07530"></a>T-07530 / [36](../../../test/models/jwt_occurrence_status_test.rb#L36) | "ensure_defaults! creates default records"<br>Owner: `JwtOccurrenceStatusTest` | `assert JwtOccurrenceStatus.exists?(id), "missing default jwt occurrence status #{id}"` | [JwtOccurrenceStatus](../../../app/models/jwt_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/jwt_occurrence_test.rb`

[test/models/jwt_occurrence_test.rb](../../../test/models/jwt_occurrence_test.rb); SHA-256: `39ac7a9a2556009e939571be855f0bea2f4d332dd9729d67f7f16bd282bca64b`.

File-level implementation candidates (including setup/import context): [app/models/jwt_occurrence.rb:31](../../../app/models/jwt_occurrence.rb#L31); [app/models/jwt_occurrence_status.rb:12](../../../app/models/jwt_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07531"></a>T-07531 / [35](../../../test/models/jwt_occurrence_test.rb#L35) | "defaults status_id to nothing"<br>Owner: `JwtOccurrenceTest` | `assert_equal JwtOccurrenceStatus::NOTHING, record.status_id` | [JwtOccurrence](../../../app/models/jwt_occurrence.rb#L31); [JwtOccurrenceStatus](../../../app/models/jwt_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07532"></a>T-07532 / [41](../../../test/models/jwt_occurrence_test.rb#L41) | "lifecycle timestamps default"<br>Owner: `JwtOccurrenceTest` | `assert_occurrence_lifecycle_defaults(record)` | [JwtOccurrence](../../../app/models/jwt_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07533"></a>T-07533 / [46](../../../test/models/jwt_occurrence_test.rb#L46) | "public_id is a fixed 21-character NanoID"<br>Owner: `JwtOccurrenceTest` | `assert_public_id_fixed_length(::JwtOccurrence)` | [JwtOccurrence](../../../app/models/jwt_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
