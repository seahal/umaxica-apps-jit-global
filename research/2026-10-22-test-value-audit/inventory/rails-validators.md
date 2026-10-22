# rails-validators: per-definition ledger

4 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/validators/recovery_identity_required_validator_test.rb`

[test/validators/recovery_identity_required_validator_test.rb](../../../test/validators/recovery_identity_required_validator_test.rb); SHA-256: `caba26b07ca250c53e7ca4a2ac4d54f91d1779bac0bc0f53404f19b165fb0aa1`.

File-level implementation candidates (including setup/import context): [app/validators/recovery_identity_required_validator.rb:4](../../../app/validators/recovery_identity_required_validator.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13357"></a>T-13357 / [36](../../../test/validators/recovery_identity_required_validator_test.rb#L36) | "adds error when owner lacks verified recovery identity with symbol message"<br>Owner: `RecoveryIdentityRequiredValidatorTest` | `assert_includes record.errors[:base], "Custom recovery message constant"` | [RecoveryIdentityRequiredValidator](../../../app/validators/recovery_identity_required_validator.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13358"></a>T-13358 / [43](../../../test/validators/recovery_identity_required_validator_test.rb#L43) | "uses string message directly when message option is not a symbol"<br>Owner: `RecoveryIdentityRequiredValidatorTest` | `assert_includes record.errors[:base], "String message"` | [RecoveryIdentityRequiredValidator](../../../app/validators/recovery_identity_required_validator.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13359"></a>T-13359 / [50](../../../test/validators/recovery_identity_required_validator_test.rb#L50) | "does not add error when owner has verified recovery identity"<br>Owner: `RecoveryIdentityRequiredValidatorTest` | `assert_empty record.errors[:base]` | [RecoveryIdentityRequiredValidator](../../../app/validators/recovery_identity_required_validator.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13360"></a>T-13360 / [57](../../../test/validators/recovery_identity_required_validator_test.rb#L57) | "adds error when owner is nil (safe navigation returns nil, not early return)"<br>Owner: `RecoveryIdentityRequiredValidatorTest` | `assert_includes record.errors[:base], "Custom recovery message constant"` | [RecoveryIdentityRequiredValidator](../../../app/validators/recovery_identity_required_validator.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
