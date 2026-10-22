# rails-models-b: per-definition ledger

10 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/branch_coverage_batch23_easy_arms_test.rb`

[test/models/branch_coverage_batch23_easy_arms_test.rb](../../../test/models/branch_coverage_batch23_easy_arms_test.rb); SHA-256: `1dff9a9bd7f7b636f16255bf32b2301e43acef3553010af1ff44e1098266ea7f`.

File-level implementation candidates (including setup/import context): [app/controllers/concerns/surface_inertia_page.rb:13](../../../app/controllers/concerns/surface_inertia_page.rb#L13); [app/models/operator_preference_date_format_option.rb:11](../../../app/models/operator_preference_date_format_option.rb#L11); [app/controllers/application_controller.rb:4](../../../app/controllers/application_controller.rb#L4); [app/resolvers/redirects_external_target_resolver.rb:4](../../../app/resolvers/redirects_external_target_resolver.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06077"></a>T-06077 / [12](../../../test/models/branch_coverage_batch23_easy_arms_test.rb#L12) | "OperatorPreferenceDateFormatOption#name covers the US arm"<br>Owner: `BranchCoverageBatch23EasyArmsTest` | `assert_equal "us", option.name` | [OperatorPreferenceDateFormatOption](../../../app/models/operator_preference_date_format_option.rb#L11) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-06078"></a>T-06078 / [19](../../../test/models/branch_coverage_batch23_easy_arms_test.rb#L19) | "SurfaceInertiaPage refuses a controller path without a family and surface"<br>Owner: `BranchCoverageBatch23EasyArmsTest` | `assert_raises(ArgumentError) do` | [ApplicationController](../../../app/controllers/application_controller.rb#L4); [SurfaceInertiaPage](../../../app/controllers/concerns/surface_inertia_page.rb#L13) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-06079"></a>T-06079 / [29](../../../test/models/branch_coverage_batch23_easy_arms_test.rb#L29) | "RedirectsExternalTargetResolver refuses unknown keys and relative targets"<br>Owner: `BranchCoverageBatch23EasyArmsTest` | `assert_equal "unknown_key", unknown.failure_reason`; `assert_equal "invalid_uri", blank_host.failure_reason`; `assert_includes %w(control_char invalid_uri origin_denied), control.failure_reason` | [RedirectsExternalTargetResolver](../../../app/resolvers/redirects_external_target_resolver.rb#L4) | S: static inventory; individual semantic review open | coverage-named |

## `test/models/branch_coverage_model_concerns_test.rb`

[test/models/branch_coverage_model_concerns_test.rb](../../../test/models/branch_coverage_model_concerns_test.rb); SHA-256: `12067abe74ac469797673c4c6ab69c06982978a494cdc7dbc29d9e4c79370061`.

File-level implementation candidates (including setup/import context): [app/models/acme_logout_transaction.rb:41](../../../app/models/acme_logout_transaction.rb#L41).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06080"></a>T-06080 / [7](../../../test/models/branch_coverage_model_concerns_test.rb#L7) | "AcmeLogoutTransaction covers finalized failed expired and validation arms"<br>Owner: `BranchCoverageModelConcernsTest` | `assert_same txn, txn.advance_step!("origin_cleared")`; `assert_same txn, txn.finalize!`; `assert_same failed, failed.advance_step!("origin_cleared")`; +4 further assertion lines | [AcmeLogoutTransaction](../../../app/models/acme_logout_transaction.rb#L41) | S: static inventory; individual semantic review open | coverage-named |

## `test/models/bureau_ownership_transfer_request_test.rb`

[test/models/bureau_ownership_transfer_request_test.rb](../../../test/models/bureau_ownership_transfer_request_test.rb); SHA-256: `f1a96e2154762328d9537cbabc64285767dbf83cbe0ad1b58ab5d718bd3e7f14`.

File-level implementation candidates (including setup/import context): [app/models/bureau_ownership_transfer_request.rb:4](../../../app/models/bureau_ownership_transfer_request.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06081"></a>T-06081 / [6](../../../test/models/bureau_ownership_transfer_request_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `BureauOwnershipTransferRequestTest` | `assert_public_id_fixed_length(::BureauOwnershipTransferRequest)` | [BureauOwnershipTransferRequest](../../../app/models/bureau_ownership_transfer_request.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/bureau_root_units_test.rb`

[test/models/bureau_root_units_test.rb](../../../test/models/bureau_root_units_test.rb); SHA-256: `005541297aba650d41a7edf1d09cd492b2f63de9f894437dfb0d132d35f1a265`.

File-level implementation candidates (including setup/import context): [app/models/bureau.rb:20](../../../app/models/bureau.rb#L20); [app/models/division.rb:27](../../../app/models/division.rb#L27); [app/models/bureau_unit.rb:31](../../../app/models/bureau_unit.rb#L31).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06082"></a>T-06082 / [7](../../../test/models/bureau_root_units_test.rb#L7) | "root_units returns only units without parent"<br>Owner: `BureauRootUnitsTest` | `assert_includes bureau.root_units, root`; `assert_not_includes bureau.root_units, _child` | [Bureau](../../../app/models/bureau.rb#L20); [Division](../../../app/models/division.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-06083"></a>T-06083 / [16](../../../test/models/bureau_root_units_test.rb#L16) | "root_units returns multiple root units"<br>Owner: `BureauRootUnitsTest` | `assert_equal 2, bureau.root_units.count`; `assert_includes bureau.root_units, root_a`; `assert_includes bureau.root_units, root_b` | [Bureau](../../../app/models/bureau.rb#L20); [Division](../../../app/models/division.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-06084"></a>T-06084 / [26](../../../test/models/bureau_root_units_test.rb#L26) | "root_units returns empty when no units exist"<br>Owner: `BureauRootUnitsTest` | `assert_empty bureau.root_units` | [Bureau](../../../app/models/bureau.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/bureau_test.rb`

[test/models/bureau_test.rb](../../../test/models/bureau_test.rb); SHA-256: `bf094f7ba95f8ce083c348a49be6857099183df067371f0cb48bcf8940fc7983`.

File-level implementation candidates (including setup/import context): [app/models/bureau.rb:20](../../../app/models/bureau.rb#L20).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06085"></a>T-06085 / [6](../../../test/models/bureau_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `BureauTest` | `assert_public_id_fixed_length(::Bureau)` | [Bureau](../../../app/models/bureau.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/bureau_unit_test.rb`

[test/models/bureau_unit_test.rb](../../../test/models/bureau_unit_test.rb); SHA-256: `577325a0754f1fc3aadd8cf79b2ec81c779360e647d953e9314acf84954aa409`.

File-level implementation candidates (including setup/import context): [app/models/bureau_unit.rb:31](../../../app/models/bureau_unit.rb#L31).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-06086"></a>T-06086 / [6](../../../test/models/bureau_unit_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `BureauUnitTest` | `assert_public_id_fixed_length(::BureauUnit)` | [BureauUnit](../../../app/models/bureau_unit.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
