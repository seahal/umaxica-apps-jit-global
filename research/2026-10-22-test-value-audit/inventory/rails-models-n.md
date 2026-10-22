# rails-models-n: per-definition ledger

2 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/not_null_column_nil_validation_contract_test.rb`

[test/models/not_null_column_nil_validation_contract_test.rb](../../../test/models/not_null_column_nil_validation_contract_test.rb); SHA-256: `040a73ff7404a793728cdbc6c618861688a0a7435e567c9c11e692ed0ff1d72e`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07595"></a>T-07595 / [66](../../../test/models/not_null_column_nil_validation_contract_test.rb#L66) | "#{model.name} NOT NULL columns reject nil before SQL"<br>Owner: `NotNullColumnNilValidationContractTest` | `assert nil_errors?(model, attribute), "#{model.name}##{attribute} must reject nil"` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/numericality_check_constraint_contract_test.rb`

[test/models/numericality_check_constraint_contract_test.rb](../../../test/models/numericality_check_constraint_contract_test.rb); SHA-256: `45fa95ae894a964610cf4318263af25c8d5e9ca107d18ae66320612181c1010b`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07596"></a>T-07596 / [41](../../../test/models/numericality_check_constraint_contract_test.rb#L41) | "#{model.name} numericality minimums are database CHECK constraints"<br>Owner: `NumericalityCheckConstraintContractTest` | `assert expressions.any? { \|expression\| expression.match?(bound) },` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
