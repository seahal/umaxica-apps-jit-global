# rails-migrations: per-definition ledger

2 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/migrations/processor_erasure_delivery_contract_rollback_test.rb`

[test/migrations/processor_erasure_delivery_contract_rollback_test.rb](../../../test/migrations/processor_erasure_delivery_contract_rollback_test.rb); SHA-256: `ee41a1a85c24e0df1fad4494accc6d12fb0ef4f5735eb7e140491e458923ab0a`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-05448"></a>T-05448 / [35](../../../test/migrations/processor_erasure_delivery_contract_rollback_test.rb#L35) | test_client_validation_rollback_removes_the_helper_constraint_it_adds<br>Owner: `ProcessorErasureDeliveryContractRollbackTest` | `assert_equal ["chk_client_proc_notif_idem_digest_nn"], probe.removed_constraints` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05449"></a>T-05449 / [44](../../../test/migrations/processor_erasure_delivery_contract_rollback_test.rb#L44) | test_visitor_validation_rollback_removes_the_helper_constraint_it_adds<br>Owner: `ProcessorErasureDeliveryContractRollbackTest` | `assert_equal ["chk_visitor_proc_notif_idem_digest_nn"], probe.removed_constraints` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
