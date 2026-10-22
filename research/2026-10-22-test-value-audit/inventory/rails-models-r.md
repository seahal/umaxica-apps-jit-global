# rails-models-r: per-definition ledger

123 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/r5_protocol_foundation_test.rb`

[test/models/r5_protocol_foundation_test.rb](../../../test/models/r5_protocol_foundation_test.rb); SHA-256: `7eb1a76573ba6696349d5ed4f6dd995ed1c5dd09b1a3735b88f918a1603f017d`.

File-level implementation candidates (including setup/import context): [app/models/op_app_protocol_epoch.rb:4](../../../app/models/op_app_protocol_epoch.rb#L4); [app/models/op_app_consumed_jti.rb:4](../../../app/models/op_app_consumed_jti.rb#L4); [app/models/op_app_logout_flow.rb:4](../../../app/models/op_app_logout_flow.rb#L4); [app/models/op_app_logout_flow_participant.rb:4](../../../app/models/op_app_logout_flow_participant.rb#L4); [app/models/op_app_logout_receipt.rb:4](../../../app/models/op_app_logout_receipt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08683"></a>T-08683 / [42](../../../test/models/r5_protocol_foundation_test.rb#L42) | "each realm has an initialized current contract epoch and separated protocol tables"<br>Owner: `R5ProtocolFoundationTest` | `assert_equal 1, entry.fetch(:epoch).find(1).contract_epoch`; `assert_equal entry.fetch(:realm), entry.fetch(:epoch).find(1).realm`; `assert_equal "op_consumed_jtis", entry.fetch(:consumed_jti).table_name`; +5 further assertion lines | [OpAppProtocolEpoch](../../../app/models/op_app_protocol_epoch.rb#L4); [OpAppConsumedJti](../../../app/models/op_app_consumed_jti.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08684"></a>T-08684 / [55](../../../test/models/r5_protocol_foundation_test.rb#L55) | "each realm consumed JTI record is once-only for its scoped purpose"<br>Owner: `R5ProtocolFoundationTest` | `assert model.consume!(**attributes)`; `assert_not model.consume!(**attributes)`; `assert_equal 1, model.where(jti_digest: model.digest_jti(attributes.fetch(:jti))).count` | [OpAppProtocolEpoch](../../../app/models/op_app_protocol_epoch.rb#L4); [OpAppConsumedJti](../../../app/models/op_app_consumed_jti.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08685"></a>T-08685 / [72](../../../test/models/r5_protocol_foundation_test.rb#L72) | "realm model validations reject cross-realm and negative delivery state"<br>Owner: `R5ProtocolFoundationTest` | `assert_not_predicate flow, :valid?`; `assert flow.errors.of_kind?(:realm, :inclusion)`; `assert_not_predicate participant, :valid?`; +1 further assertion lines | [OpAppLogoutFlow](../../../app/models/op_app_logout_flow.rb#L4); [OpAppLogoutFlowParticipant](../../../app/models/op_app_logout_flow_participant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/realm_identifier_encryption_test.rb`

[test/models/realm_identifier_encryption_test.rb](../../../test/models/realm_identifier_encryption_test.rb); SHA-256: `b703fd320831833354ba4af0584668fa3e3e3d6d428a1b2e9d6028979850ee0b`.

File-level implementation candidates (including setup/import context): [lib/realm_identifier_encryption_key_provider.rb:3](../../../lib/realm_identifier_encryption_key_provider.rb#L3); [app/models/client_email.rb:44](../../../app/models/client_email.rb#L44); [app/models/visitor_email.rb:43](../../../app/models/visitor_email.rb#L43); [app/models/operator_email.rb:38](../../../app/models/operator_email.rb#L38); [app/models/client_telephone.rb:37](../../../app/models/client_telephone.rb#L37).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08686"></a>T-08686 / [6](../../../test/models/realm_identifier_encryption_test.rb#L6) | "realm derivation keeps ciphertext isolated even if configured key and salt values accidentally coincide"<br>Owner: `RealmIdentifierEncryptionTest` | `assert_equal "realm@example.com", ActiveRecord::Encryption.encryptor.decrypt(ciphertext, key_provider: provider)`; `assert_raises(ActiveRecord::Encryption::Errors::Decryption) do` | [RealmIdentifierEncryptionKeyProvider](../../../lib/realm_identifier_encryption_key_provider.rb#L3) | S: static inventory; individual semantic review open | environment-reference |
| <a id="t-08687"></a>T-08687 / [28](../../../test/models/realm_identifier_encryption_test.rb#L28) | "identifier models reject ciphertext encrypted under the non-identifier global keyring"<br>Owner: `RealmIdentifierEncryptionTest` | `assert_raises(ActiveRecord::Encryption::Errors::Decryption) do`; `assert_raises(ActiveRecord::Encryption::Errors::Decryption) do` | [ClientEmail](../../../app/models/client_email.rb#L44); [VisitorEmail](../../../app/models/visitor_email.rb#L43) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08688"></a>T-08688 / [44](../../../test/models/realm_identifier_encryption_test.rb#L44) | "each realm keyring reads previous ciphertext and encrypts with only the current key"<br>Owner: `RealmIdentifierEncryptionTest` | `assert_equal "previous@example.com",`; `assert_raises(ActiveRecord::Encryption::Errors::Decryption) do` | [RealmIdentifierEncryptionKeyProvider](../../../lib/realm_identifier_encryption_key_provider.rb#L3) | S: static inventory; individual semantic review open | environment-reference |
| <a id="t-08689"></a>T-08689 / [74](../../../test/models/realm_identifier_encryption_test.rb#L74) | "APP COM and ORG email ciphertext is readable only by its owning realm"<br>Owner: `RealmIdentifierEncryptionTest` | `assert_equal "realm-encryption@example.com", ClientEmail.type_for_attribute("address").deserialize(app)`; `assert_equal "realm-encryption@example.com", VisitorEmail.type_for_attribute("address").deserialize(com)`; `assert_equal "realm-encryption@example.com", OperatorEmail.type_for_attribute("address").deserialize(org)`; +6 further assertion lines | [ClientEmail](../../../app/models/client_email.rb#L44); [VisitorEmail](../../../app/models/visitor_email.rb#L43) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08690"></a>T-08690 / [102](../../../test/models/realm_identifier_encryption_test.rb#L102) | "APP COM and ORG telephone ciphertext is readable only by its owning realm"<br>Owner: `RealmIdentifierEncryptionTest` | `assert_equal "+819012345678", ClientTelephone.type_for_attribute("number").deserialize(app)`; `assert_equal "+819012345678", VisitorTelephone.type_for_attribute("number").deserialize(com)`; `assert_equal "+819012345678", OperatorTelephone.type_for_attribute("number").deserialize(org)`; +6 further assertion lines | [ClientTelephone](../../../app/models/client_telephone.rb#L37); [VisitorTelephone](../../../app/models/visitor_telephone.rb#L36) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/reference_defaults_test.rb`

[test/models/reference_defaults_test.rb](../../../test/models/reference_defaults_test.rb); SHA-256: `8d004b3e1ed57d2037e9fbf38b7033929dce211636e272f134e498985cfe4b91`.

File-level implementation candidates (including setup/import context): [app/models/area_occurrence_status.rb:12](../../../app/models/area_occurrence_status.rb#L12); [app/models/visitor_occurrence_status.rb:12](../../../app/models/visitor_occurrence_status.rb#L12); [app/models/domain_occurrence_status.rb:12](../../../app/models/domain_occurrence_status.rb#L12); [app/models/email_occurrence_status.rb:12](../../../app/models/email_occurrence_status.rb#L12); [app/models/ip_occurrence_status.rb:12](../../../app/models/ip_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08691"></a>T-08691 / [25](../../../test/models/reference_defaults_test.rb#L25) | "reference models ensure their fixed ids exist"<br>Owner: `ReferenceDefaultsTest` | `assert_empty model::DEFAULTS - model.where(id: model::DEFAULTS).pluck(:id)` | [AreaOccurrenceStatus](../../../app/models/area_occurrence_status.rb#L12); [VisitorOccurrenceStatus](../../../app/models/visitor_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/refresh_token_concurrency_test.rb`

[test/models/refresh_token_concurrency_test.rb](../../../test/models/refresh_token_concurrency_test.rb); SHA-256: `482def90d356a7e126e87499dc6fd19a48957c18d193cf0213a75f6400c69f9d`.

File-level implementation candidates (including setup/import context): [app/models/client_token.rb:89](../../../app/models/client_token.rb#L89); [app/models/client_status.rb:11](../../../app/models/client_status.rb#L11); [app/models/client_visibility.rb:11](../../../app/models/client_visibility.rb#L11); [app/models/client_mfa_level.rb:11](../../../app/models/client_mfa_level.rb#L11); [app/models/client_mfa_status.rb:11](../../../app/models/client_mfa_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08692"></a>T-08692 / [6](../../../test/models/refresh_token_concurrency_test.rb#L6) | "concurrent refresh attempts cannot both rotate the same client token"<br>Owner: `RefreshTokenConcurrencyTest` | `assert_equal 2, results.size`; `assert_equal 1, results.count { \|result\| result.fetch(:status) == :rotated }, results.inspect`; `assert_equal 1, results.count { \|result\| result.fetch(:status).in?(%i(replay invalid)) }, results.inspect`; +3 further assertion lines | [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/required_attribute_not_null_contract_test.rb`

[test/models/required_attribute_not_null_contract_test.rb](../../../test/models/required_attribute_not_null_contract_test.rb); SHA-256: `3e7a03953b1cb4e35f36744ace197161bc89629448a89d19eb4e8322aca2bb86`.

File-level implementation candidates (including setup/import context): [app/models/client_profile.rb:33](../../../app/models/client_profile.rb#L33); [app/models/member.rb:34](../../../app/models/member.rb#L34); [app/models/operator_workspace_account.rb:27](../../../app/models/operator_workspace_account.rb#L27).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08693"></a>T-08693 / [52](../../../test/models/required_attribute_not_null_contract_test.rb#L52) | "#{model.name} always-required attributes are NOT NULL in the database"<br>Owner: `RequiredAttributeNotNullContractTest` | `assert_not model.columns_hash.fetch(column).null, "#{model.name}##{column} must be NOT NULL"` | [ClientProfile](../../../app/models/client_profile.rb#L33); [Member](../../../app/models/member.rb#L34) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/resource_authority_uniqueness_test.rb`

[test/models/resource_authority_uniqueness_test.rb](../../../test/models/resource_authority_uniqueness_test.rb); SHA-256: `6668a1fd1e3b6b53401e2555de13fce02bb66b09218a8611aa431c5fc1156e21`.

File-level implementation candidates (including setup/import context): [app/models/enterprise_ownership.rb:4](../../../app/models/enterprise_ownership.rb#L4); [app/models/enterprise_lifecycle.rb:4](../../../app/models/enterprise_lifecycle.rb#L4); [app/values/authority_resource_lifecycle_state_value.rb:5](../../../app/values/authority_resource_lifecycle_state_value.rb#L5); [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/client_status.rb:11](../../../app/models/client_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08694"></a>T-08694 / [10](../../../test/models/resource_authority_uniqueness_test.rb#L10) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `EnterpriseAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.enterprise_id`; `assert_equal second_resource.id, second.reload.enterprise_id`; +3 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08695"></a>T-08695 / [35](../../../test/models/resource_authority_uniqueness_test.rb#L35) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `EnterpriseAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:enterprise_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08696"></a>T-08696 / [61](../../../test/models/resource_authority_uniqueness_test.rb#L61) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `EnterpriseAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08697"></a>T-08697 / [92](../../../test/models/resource_authority_uniqueness_test.rb#L92) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `ClientPersonaAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.client_persona_id`; `assert_equal second_resource.id, second.reload.client_persona_id`; +3 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08698"></a>T-08698 / [126](../../../test/models/resource_authority_uniqueness_test.rb#L126) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `ClientPersonaAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:client_persona_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08699"></a>T-08699 / [161](../../../test/models/resource_authority_uniqueness_test.rb#L161) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `ClientPersonaAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08700"></a>T-08700 / [201](../../../test/models/resource_authority_uniqueness_test.rb#L201) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `CompanyAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.company_id`; `assert_equal second_resource.id, second.reload.company_id`; +3 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08701"></a>T-08701 / [226](../../../test/models/resource_authority_uniqueness_test.rb#L226) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `CompanyAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:company_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08702"></a>T-08702 / [252](../../../test/models/resource_authority_uniqueness_test.rb#L252) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `CompanyAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08703"></a>T-08703 / [283](../../../test/models/resource_authority_uniqueness_test.rb#L283) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `IndividualAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.individual_id`; `assert_equal second_resource.id, second.reload.individual_id`; +3 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08704"></a>T-08704 / [317](../../../test/models/resource_authority_uniqueness_test.rb#L317) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `IndividualAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:individual_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08705"></a>T-08705 / [352](../../../test/models/resource_authority_uniqueness_test.rb#L352) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `IndividualAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08706"></a>T-08706 / [392](../../../test/models/resource_authority_uniqueness_test.rb#L392) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `BureauAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.bureau_id`; `assert_equal second_resource.id, second.reload.bureau_id`; +3 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08707"></a>T-08707 / [417](../../../test/models/resource_authority_uniqueness_test.rb#L417) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `BureauAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:bureau_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08708"></a>T-08708 / [443](../../../test/models/resource_authority_uniqueness_test.rb#L443) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `BureauAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08709"></a>T-08709 / [474](../../../test/models/resource_authority_uniqueness_test.rb#L474) | "#{model.name} retains DB one-row ownership and ordinary updates"<br>Owner: `AgentAuthorityUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.agent_id`; `assert_equal second_resource.id, second.reload.agent_id`; +3 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08710"></a>T-08710 / [508](../../../test/models/resource_authority_uniqueness_test.rb#L508) | "#{model.name} rejects duplicate and reassigned resource keys before SQL"<br>Owner: `AgentAuthorityUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:agent_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +4 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08711"></a>T-08711 / [543](../../../test/models/resource_authority_uniqueness_test.rb#L543) | "#{model.name} adds one resource probe and skips an unchanged persisted key"<br>Owner: `AgentAuthorityUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate first, :valid?`; `assert_equal 1, queries.size` | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/resource_grant_uniqueness_test.rb`

[test/models/resource_grant_uniqueness_test.rb](../../../test/models/resource_grant_uniqueness_test.rb); SHA-256: `d49d58a6d70318bfafd620cd38ac787195ef09a81c7ec6df1f525c1c8a9b6b0f`.

File-level implementation candidates (including setup/import context): [app/models/enterprise_administration_grant.rb:4](../../../app/models/enterprise_administration_grant.rb#L4); [app/models/enterprise_delegation_grant.rb:4](../../../app/models/enterprise_delegation_grant.rb#L4); [app/models/enterprise_view_grant.rb:4](../../../app/models/enterprise_view_grant.rb#L4); [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/client_status.rb:11](../../../app/models/client_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08712"></a>T-08712 / [9](../../../test/models/resource_grant_uniqueness_test.rb#L9) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `EnterpriseGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.enterprise_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08713"></a>T-08713 / [43](../../../test/models/resource_grant_uniqueness_test.rb#L43) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `EnterpriseGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:enterprise_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08714"></a>T-08714 / [65](../../../test/models/resource_grant_uniqueness_test.rb#L65) | "#{model.name} distinguishes missing foreign keys from the existing zero client"<br>Owner: `EnterpriseGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_predicate absent_principal, :valid?`; `assert_not absent_principal.valid?`; +2 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08715"></a>T-08715 / [87](../../../test/models/resource_grant_uniqueness_test.rb#L87) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `EnterpriseGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08716"></a>T-08716 / [115](../../../test/models/resource_grant_uniqueness_test.rb#L115) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `ClientPersonaGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.client_persona_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08717"></a>T-08717 / [158](../../../test/models/resource_grant_uniqueness_test.rb#L158) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `ClientPersonaGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:client_persona_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08718"></a>T-08718 / [189](../../../test/models/resource_grant_uniqueness_test.rb#L189) | "#{model.name} distinguishes missing foreign keys from the existing zero client"<br>Owner: `ClientPersonaGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_predicate absent_principal, :valid?`; `assert_not absent_principal.valid?`; +2 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08719"></a>T-08719 / [220](../../../test/models/resource_grant_uniqueness_test.rb#L220) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `ClientPersonaGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08720"></a>T-08720 / [256](../../../test/models/resource_grant_uniqueness_test.rb#L256) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `CompanyGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.company_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08721"></a>T-08721 / [290](../../../test/models/resource_grant_uniqueness_test.rb#L290) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `CompanyGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:company_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08722"></a>T-08722 / [312](../../../test/models/resource_grant_uniqueness_test.rb#L312) | "#{model.name} keeps missing and sentinel foreign keys invalid"<br>Owner: `CompanyGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_not absent_principal.valid?`; `assert_predicate absent_resource, :new_record?`; +1 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08723"></a>T-08723 / [328](../../../test/models/resource_grant_uniqueness_test.rb#L328) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `CompanyGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08724"></a>T-08724 / [355](../../../test/models/resource_grant_uniqueness_test.rb#L355) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `IndividualGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.individual_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08725"></a>T-08725 / [398](../../../test/models/resource_grant_uniqueness_test.rb#L398) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `IndividualGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:individual_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08726"></a>T-08726 / [429](../../../test/models/resource_grant_uniqueness_test.rb#L429) | "#{model.name} keeps missing and sentinel foreign keys invalid"<br>Owner: `IndividualGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_not absent_principal.valid?`; `assert_predicate absent_resource, :new_record?`; +1 further assertion lines | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08727"></a>T-08727 / [454](../../../test/models/resource_grant_uniqueness_test.rb#L454) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `IndividualGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Visitor](../../../app/models/visitor.rb#L63); [VisitorStatus](../../../app/models/visitor_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08728"></a>T-08728 / [490](../../../test/models/resource_grant_uniqueness_test.rb#L490) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `BureauGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.bureau_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08729"></a>T-08729 / [524](../../../test/models/resource_grant_uniqueness_test.rb#L524) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `BureauGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:bureau_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08730"></a>T-08730 / [546](../../../test/models/resource_grant_uniqueness_test.rb#L546) | "#{model.name} keeps missing and sentinel foreign keys invalid"<br>Owner: `BureauGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_not absent_principal.valid?`; `assert_predicate absent_resource, :new_record?`; +1 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08731"></a>T-08731 / [562](../../../test/models/resource_grant_uniqueness_test.rb#L562) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `BureauGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08732"></a>T-08732 / [589](../../../test/models/resource_grant_uniqueness_test.rb#L589) | "#{model.name} preserves pair scope DB enforcement and ownership boundaries"<br>Owner: `AgentGrantUniquenessTest` | `assert_predicate first, :valid?`; `assert_equal first_resource.id, first.reload.agent_id`; `assert_not_equal first.id, other_principal.id`; +6 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08733"></a>T-08733 / [632](../../../test/models/resource_grant_uniqueness_test.rb#L632) | "#{model.name} rejects duplicates and colliding scope changes before SQL"<br>Owner: `AgentGrantUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:agent_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }`; +6 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08734"></a>T-08734 / [663](../../../test/models/resource_grant_uniqueness_test.rb#L663) | "#{model.name} keeps missing and sentinel foreign keys invalid"<br>Owner: `AgentGrantUniquenessTest` | `assert_not absent_resource.valid?`; `assert_not absent_principal.valid?`; `assert_predicate absent_resource, :new_record?`; +1 further assertion lines | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08735"></a>T-08735 / [688](../../../test/models/resource_grant_uniqueness_test.rb#L688) | "#{model.name} adds one pair probe and skips unchanged existing keys"<br>Owner: `AgentGrantUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size` | [Operator](../../../app/models/operator.rb#L59); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_app_principal_test.rb`

[test/models/rp_base_app_principal_test.rb](../../../test/models/rp_base_app_principal_test.rb); SHA-256: `0a9bcce7ee7bec5e3f2f1e7e2ba43ce099a5e33e5bd96a9f3328b6e32091d72f`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_app_principal.rb:4](../../../app/models/rp_base_app_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08736"></a>T-08736 / [6](../../../test/models/rp_base_app_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseAppPrincipalTest` | `assert_public_id_fixed_length(::RpBaseAppPrincipal)` | [RpBaseAppPrincipal](../../../app/models/rp_base_app_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_app_refresh_attempt_test.rb`

[test/models/rp_base_app_refresh_attempt_test.rb](../../../test/models/rp_base_app_refresh_attempt_test.rb); SHA-256: `f0f69cba9e6c776de5f4017b91a3b1231da72cdb65b1c11d286cdf9c8b1df25b`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_app_refresh_attempt.rb:4](../../../app/models/rp_base_app_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08737"></a>T-08737 / [6](../../../test/models/rp_base_app_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseAppRefreshAttemptTest` | `assert_public_id_fixed_length(::RpBaseAppRefreshAttempt)` | [RpBaseAppRefreshAttempt](../../../app/models/rp_base_app_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_app_session_test.rb`

[test/models/rp_base_app_session_test.rb](../../../test/models/rp_base_app_session_test.rb); SHA-256: `31e2325a458047d1bb509ad43adb6bbc21e93f458ebe8cbd2a97d322f91a77d9`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_app_session.rb:4](../../../app/models/rp_base_app_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08738"></a>T-08738 / [6](../../../test/models/rp_base_app_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseAppSessionTest` | `assert_public_id_fixed_length(::RpBaseAppSession)` | [RpBaseAppSession](../../../app/models/rp_base_app_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_com_principal_test.rb`

[test/models/rp_base_com_principal_test.rb](../../../test/models/rp_base_com_principal_test.rb); SHA-256: `946f6329f60d706b19b5752432656ba3f6e819cf185177878040bdd52c11d5e1`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_com_principal.rb:4](../../../app/models/rp_base_com_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08739"></a>T-08739 / [6](../../../test/models/rp_base_com_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseComPrincipalTest` | `assert_public_id_fixed_length(::RpBaseComPrincipal)` | [RpBaseComPrincipal](../../../app/models/rp_base_com_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_com_refresh_attempt_test.rb`

[test/models/rp_base_com_refresh_attempt_test.rb](../../../test/models/rp_base_com_refresh_attempt_test.rb); SHA-256: `55439da507f9acf9d82163587621c79fbf9a80b0a8936052edde7db5b8d014d5`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_com_refresh_attempt.rb:4](../../../app/models/rp_base_com_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08740"></a>T-08740 / [6](../../../test/models/rp_base_com_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseComRefreshAttemptTest` | `assert_public_id_fixed_length(::RpBaseComRefreshAttempt)` | [RpBaseComRefreshAttempt](../../../app/models/rp_base_com_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_com_session_test.rb`

[test/models/rp_base_com_session_test.rb](../../../test/models/rp_base_com_session_test.rb); SHA-256: `31ca6a3654389beb91d02edcc2de713b17669006015a52f2beda72a1095e748d`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_com_session.rb:4](../../../app/models/rp_base_com_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08741"></a>T-08741 / [6](../../../test/models/rp_base_com_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseComSessionTest` | `assert_public_id_fixed_length(::RpBaseComSession)` | [RpBaseComSession](../../../app/models/rp_base_com_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_org_principal_test.rb`

[test/models/rp_base_org_principal_test.rb](../../../test/models/rp_base_org_principal_test.rb); SHA-256: `69c06986dabc14786d4a7046ecec37ff39416f6622627f6648e26e3f99fa0e64`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_org_principal.rb:4](../../../app/models/rp_base_org_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08742"></a>T-08742 / [6](../../../test/models/rp_base_org_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseOrgPrincipalTest` | `assert_public_id_fixed_length(::RpBaseOrgPrincipal)` | [RpBaseOrgPrincipal](../../../app/models/rp_base_org_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_org_refresh_attempt_test.rb`

[test/models/rp_base_org_refresh_attempt_test.rb](../../../test/models/rp_base_org_refresh_attempt_test.rb); SHA-256: `b9b80a0852ce839ad8f5a1e3a3c4575d3edee3af1f1b1ce9e922cefd3a8290f6`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_org_refresh_attempt.rb:4](../../../app/models/rp_base_org_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08743"></a>T-08743 / [6](../../../test/models/rp_base_org_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseOrgRefreshAttemptTest` | `assert_public_id_fixed_length(::RpBaseOrgRefreshAttempt)` | [RpBaseOrgRefreshAttempt](../../../app/models/rp_base_org_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_base_org_session_test.rb`

[test/models/rp_base_org_session_test.rb](../../../test/models/rp_base_org_session_test.rb); SHA-256: `dceab956e979ba516d9441dda98950b5dd785c0874bed94093feea8b9d900308`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_org_session.rb:4](../../../app/models/rp_base_org_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08744"></a>T-08744 / [6](../../../test/models/rp_base_org_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpBaseOrgSessionTest` | `assert_public_id_fixed_length(::RpBaseOrgSession)` | [RpBaseOrgSession](../../../app/models/rp_base_org_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_app_principal_test.rb`

[test/models/rp_core_app_principal_test.rb](../../../test/models/rp_core_app_principal_test.rb); SHA-256: `1727337fea711d84dfd52bd5bb90b132e1ac69e6b89feb4dbc1f181e8200007e`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_app_principal.rb:4](../../../app/models/rp_core_app_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08745"></a>T-08745 / [6](../../../test/models/rp_core_app_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreAppPrincipalTest` | `assert_public_id_fixed_length(::RpCoreAppPrincipal)` | [RpCoreAppPrincipal](../../../app/models/rp_core_app_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_app_refresh_attempt_test.rb`

[test/models/rp_core_app_refresh_attempt_test.rb](../../../test/models/rp_core_app_refresh_attempt_test.rb); SHA-256: `3488a6a7e8385bf9ca73ad875a72cf14c1ee2bf561429798a10610adfdd16972`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_app_refresh_attempt.rb:4](../../../app/models/rp_core_app_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08746"></a>T-08746 / [6](../../../test/models/rp_core_app_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreAppRefreshAttemptTest` | `assert_public_id_fixed_length(::RpCoreAppRefreshAttempt)` | [RpCoreAppRefreshAttempt](../../../app/models/rp_core_app_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_app_session_test.rb`

[test/models/rp_core_app_session_test.rb](../../../test/models/rp_core_app_session_test.rb); SHA-256: `48adb87289e1b8392ccd542b2f7a7bdc8eb77a2d5b99d9fb8412be84b411a59c`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_app_session.rb:4](../../../app/models/rp_core_app_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08747"></a>T-08747 / [6](../../../test/models/rp_core_app_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreAppSessionTest` | `assert_public_id_fixed_length(::RpCoreAppSession)` | [RpCoreAppSession](../../../app/models/rp_core_app_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_com_principal_test.rb`

[test/models/rp_core_com_principal_test.rb](../../../test/models/rp_core_com_principal_test.rb); SHA-256: `2cf4fe2b87fb15ad7a089fed28e4316c2d54a3a242c529b1680d571d3fbc40d0`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_com_principal.rb:4](../../../app/models/rp_core_com_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08748"></a>T-08748 / [6](../../../test/models/rp_core_com_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreComPrincipalTest` | `assert_public_id_fixed_length(::RpCoreComPrincipal)` | [RpCoreComPrincipal](../../../app/models/rp_core_com_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_com_refresh_attempt_test.rb`

[test/models/rp_core_com_refresh_attempt_test.rb](../../../test/models/rp_core_com_refresh_attempt_test.rb); SHA-256: `4bf3b952ab3d8ea2adedf4e707c2181b69375f5e9fcdd10bad93bbd8d80cf525`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_com_refresh_attempt.rb:4](../../../app/models/rp_core_com_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08749"></a>T-08749 / [6](../../../test/models/rp_core_com_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreComRefreshAttemptTest` | `assert_public_id_fixed_length(::RpCoreComRefreshAttempt)` | [RpCoreComRefreshAttempt](../../../app/models/rp_core_com_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_com_session_test.rb`

[test/models/rp_core_com_session_test.rb](../../../test/models/rp_core_com_session_test.rb); SHA-256: `3328c57ecdbf525454cc8d8e4fc0aacb2d344ec252b24f4fc202646cb2b2ef01`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_com_session.rb:4](../../../app/models/rp_core_com_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08750"></a>T-08750 / [6](../../../test/models/rp_core_com_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreComSessionTest` | `assert_public_id_fixed_length(::RpCoreComSession)` | [RpCoreComSession](../../../app/models/rp_core_com_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_org_principal_test.rb`

[test/models/rp_core_org_principal_test.rb](../../../test/models/rp_core_org_principal_test.rb); SHA-256: `1fca24d7cdcd671a471110327e49866bedab0e1e5d332463499cb009989ff8fd`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_org_principal.rb:4](../../../app/models/rp_core_org_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08751"></a>T-08751 / [6](../../../test/models/rp_core_org_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreOrgPrincipalTest` | `assert_public_id_fixed_length(::RpCoreOrgPrincipal)` | [RpCoreOrgPrincipal](../../../app/models/rp_core_org_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_org_refresh_attempt_test.rb`

[test/models/rp_core_org_refresh_attempt_test.rb](../../../test/models/rp_core_org_refresh_attempt_test.rb); SHA-256: `5af9e1d985ba276ebf57848ba7a5f7c06e9264fd3160d4a9d660d159b8f473ae`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_org_refresh_attempt.rb:4](../../../app/models/rp_core_org_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08752"></a>T-08752 / [6](../../../test/models/rp_core_org_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreOrgRefreshAttemptTest` | `assert_public_id_fixed_length(::RpCoreOrgRefreshAttempt)` | [RpCoreOrgRefreshAttempt](../../../app/models/rp_core_org_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_core_org_session_test.rb`

[test/models/rp_core_org_session_test.rb](../../../test/models/rp_core_org_session_test.rb); SHA-256: `c9ee3f76963f3cc09305186d53f9a57bb7b82429e73b1e33757fbe1763c4924c`.

File-level implementation candidates (including setup/import context): [app/models/rp_core_org_session.rb:4](../../../app/models/rp_core_org_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08753"></a>T-08753 / [6](../../../test/models/rp_core_org_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpCoreOrgSessionTest` | `assert_public_id_fixed_length(::RpCoreOrgSession)` | [RpCoreOrgSession](../../../app/models/rp_core_org_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_edit_org_principal_test.rb`

[test/models/rp_edit_org_principal_test.rb](../../../test/models/rp_edit_org_principal_test.rb); SHA-256: `8bcb7d8aa0760ecff665251d28fc7bb7427813897a0d26029dc697c9cc019d6c`.

File-level implementation candidates (including setup/import context): [app/models/rp_edit_org_principal.rb:4](../../../app/models/rp_edit_org_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08754"></a>T-08754 / [6](../../../test/models/rp_edit_org_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpEditOrgPrincipalTest` | `assert_public_id_fixed_length(::RpEditOrgPrincipal)` | [RpEditOrgPrincipal](../../../app/models/rp_edit_org_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_edit_org_refresh_attempt_test.rb`

[test/models/rp_edit_org_refresh_attempt_test.rb](../../../test/models/rp_edit_org_refresh_attempt_test.rb); SHA-256: `0d98c2665fa341c44402f560aee89aebe05f38ee77bec97d66ca6a6cb05f819b`.

File-level implementation candidates (including setup/import context): [app/models/rp_edit_org_refresh_attempt.rb:4](../../../app/models/rp_edit_org_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08755"></a>T-08755 / [6](../../../test/models/rp_edit_org_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpEditOrgRefreshAttemptTest` | `assert_public_id_fixed_length(::RpEditOrgRefreshAttempt)` | [RpEditOrgRefreshAttempt](../../../app/models/rp_edit_org_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_edit_org_session_test.rb`

[test/models/rp_edit_org_session_test.rb](../../../test/models/rp_edit_org_session_test.rb); SHA-256: `f4418f35feae4d546b22c6020450b2ad127fceaa140ecf4ea3820b349f94e819`.

File-level implementation candidates (including setup/import context): [app/models/rp_edit_org_session.rb:4](../../../app/models/rp_edit_org_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08756"></a>T-08756 / [6](../../../test/models/rp_edit_org_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpEditOrgSessionTest` | `assert_public_id_fixed_length(::RpEditOrgSession)` | [RpEditOrgSession](../../../app/models/rp_edit_org_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_live_session_uniqueness_test.rb`

[test/models/rp_live_session_uniqueness_test.rb](../../../test/models/rp_live_session_uniqueness_test.rb); SHA-256: `66a52c148085995262c0989e9d254ea91b8eb0091906a275203b47eb70622bbb`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_app_session.rb:4](../../../app/models/rp_base_app_session.rb#L4); [app/models/rp_base_app_op_session_binding.rb:4](../../../app/models/rp_base_app_op_session_binding.rb#L4); [app/models/rp_base_app_identity_binding.rb:4](../../../app/models/rp_base_app_identity_binding.rb#L4); [app/models/rp_base_app_principal.rb:4](../../../app/models/rp_base_app_principal.rb#L4); [app/models/rp_base_com_session.rb:4](../../../app/models/rp_base_com_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08757"></a>T-08757 / [22](../../../test/models/rp_live_session_uniqueness_test.rb#L22) | "#{session_class.name} preserves revoked history anchor scope and the DB partial index"<br>Owner: `RpLiveSessionUniquenessTest` | `assert_not history.active?(now: now)`; `assert_predicate other, :persisted?`; `assert_nil expired.reload.revoked_at`; +3 further assertion lines | [RpBaseAppSession](../../../app/models/rp_base_app_session.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08758"></a>T-08758 / [75](../../../test/models/rp_live_session_uniqueness_test.rb#L75) | "#{session_class.name} rejects an unrevoked duplicate even when the existing session expired"<br>Owner: `RpLiveSessionUniquenessTest` | `assert_not candidate.valid?`; `assert candidate.errors.of_kind?(:op_session_binding_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }`; +3 further assertion lines | [RpBaseAppSession](../../../app/models/rp_base_app_session.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_local_schema_contract_test.rb`

[test/models/rp_local_schema_contract_test.rb](../../../test/models/rp_local_schema_contract_test.rb); SHA-256: `51238174dec3422bf96de1f1e18f4d1ac1ebab93d56b1f1f14c9c4204dc87673`.

File-level implementation candidates (including setup/import context): [app/controllers/concerns/session.rb:14](../../../app/controllers/concerns/session.rb#L14); [app/values/rp_cell_binding.rb:6](../../../app/values/rp_cell_binding.rb#L6); [app/models/rp_core_app_principal.rb:4](../../../app/models/rp_core_app_principal.rb#L4); [app/models/rp_core_app_identity_binding.rb:4](../../../app/models/rp_core_app_identity_binding.rb#L4); [app/models/rp_core_app_op_session_binding.rb:4](../../../app/models/rp_core_app_op_session_binding.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08759"></a>T-08759 / [19](../../../test/models/rp_local_schema_contract_test.rb#L19) | "every configured cell has a fixed record connection and disjoint database"<br>Owner: `RpLocalSchemaContractTest` | `assert_equal cell.connection, record_class.connection_db_config.name`; `assert_equal cell.connection, model.connection_db_config.name`; `assert_equal cell.realm, model::REALM`; +2 further assertion lines | [RpCellBinding](../../../app/values/rp_cell_binding.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08760"></a>T-08760 / [41](../../../test/models/rp_local_schema_contract_test.rb#L41) | "client lookup cannot select an unknown or request-derived cell"<br>Owner: `RpLocalSchemaContractTest` | `assert_equal "rp_core_app", RpCellBinding.for_client("core-app-jp").connection`; `assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.fetch("rp_core_app_jp") }`; `assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client("core-app-us") }` | [RpCellBinding](../../../app/values/rp_cell_binding.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08761"></a>T-08761 / [47](../../../test/models/rp_local_schema_contract_test.rb#L47) | "local models reject a cross-cell identity binding"<br>Owner: `RpLocalSchemaContractTest` | `assert_not_predicate identity_binding, :valid?`; `assert identity_binding.errors.of_kind?(:realm, :inclusion)` | [RpCoreAppPrincipal](../../../app/models/rp_core_app_principal.rb#L4); [RpCoreAppIdentityBinding](../../../app/models/rp_core_app_identity_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08762"></a>T-08762 / [61](../../../test/models/rp_local_schema_contract_test.rb#L61) | "database cell constraint rejects an invalid tombstone shape"<br>Owner: `RpLocalSchemaContractTest` | `assert_raises(ActiveRecord::StatementInvalid) { tombstone.save!(validate: false) }` | [RpCoreAppOpSessionBinding](../../../app/models/rp_core_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08763"></a>T-08763 / [72](../../../test/models/rp_local_schema_contract_test.rb#L72) | "one live local session exists per OP binding and a revocation is absorbing"<br>Owner: `RpLocalSchemaContractTest` | `assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }`; `assert_equal revoked_at, op_binding.reload.revoked_at`; `assert_not_predicate first_session.reload, :active?` | [RpCoreAppPrincipal](../../../app/models/rp_core_app_principal.rb#L4); [RpCoreAppIdentityBinding](../../../app/models/rp_core_app_identity_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_palm_app_principal_test.rb`

[test/models/rp_palm_app_principal_test.rb](../../../test/models/rp_palm_app_principal_test.rb); SHA-256: `a6a575f342bcba8ad31155ba1c9f02be7436352e307beb344cdff84c76175ba6`.

File-level implementation candidates (including setup/import context): [app/models/rp_palm_app_principal.rb:4](../../../app/models/rp_palm_app_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08764"></a>T-08764 / [6](../../../test/models/rp_palm_app_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpPalmAppPrincipalTest` | `assert_public_id_fixed_length(::RpPalmAppPrincipal)` | [RpPalmAppPrincipal](../../../app/models/rp_palm_app_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_palm_app_refresh_attempt_test.rb`

[test/models/rp_palm_app_refresh_attempt_test.rb](../../../test/models/rp_palm_app_refresh_attempt_test.rb); SHA-256: `669d5c50f2ea56fc22df645841d4ac24d03328d6a369d83b9226ccfa6a8ffc7f`.

File-level implementation candidates (including setup/import context): [app/models/rp_palm_app_refresh_attempt.rb:4](../../../app/models/rp_palm_app_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08765"></a>T-08765 / [6](../../../test/models/rp_palm_app_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpPalmAppRefreshAttemptTest` | `assert_public_id_fixed_length(::RpPalmAppRefreshAttempt)` | [RpPalmAppRefreshAttempt](../../../app/models/rp_palm_app_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_palm_app_session_test.rb`

[test/models/rp_palm_app_session_test.rb](../../../test/models/rp_palm_app_session_test.rb); SHA-256: `c4330f9af15c9f947d9f276f5ef425bdfca14be4e22327c15272120e9e68be9e`.

File-level implementation candidates (including setup/import context): [app/models/rp_palm_app_session.rb:4](../../../app/models/rp_palm_app_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08766"></a>T-08766 / [6](../../../test/models/rp_palm_app_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpPalmAppSessionTest` | `assert_public_id_fixed_length(::RpPalmAppSession)` | [RpPalmAppSession](../../../app/models/rp_palm_app_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_sender_key_uniqueness_test.rb`

[test/models/rp_sender_key_uniqueness_test.rb](../../../test/models/rp_sender_key_uniqueness_test.rb); SHA-256: `a90aa54a23706cb462f93cde7bfa087b47aa6055070c7eaf4e8d3b9732c2d80e`.

File-level implementation candidates (including setup/import context): [app/models/rp_base_app_event_receipt.rb:4](../../../app/models/rp_base_app_event_receipt.rb#L4); [app/models/rp_base_app_op_session_binding.rb:4](../../../app/models/rp_base_app_op_session_binding.rb#L4); [app/models/rp_base_app_identity_binding.rb:4](../../../app/models/rp_base_app_identity_binding.rb#L4); [app/models/rp_base_app_principal.rb:4](../../../app/models/rp_base_app_principal.rb#L4); [app/models/rp_base_com_event_receipt.rb:4](../../../app/models/rp_base_com_event_receipt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08767"></a>T-08767 / [22](../../../test/models/rp_sender_key_uniqueness_test.rb#L22) | "#{anchor_class.name} scopes SID by issuer and retains DB enforcement"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_predicate anchor_class.create!(keys.merge(sid: "other")), :persisted?`; `assert_predicate anchor_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?`; `assert_predicate first.reload, :revoked?`; +1 further assertion lines | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08768"></a>T-08768 / [39](../../../test/models/rp_sender_key_uniqueness_test.rb#L39) | "#{anchor_class.name} preflights the complete SID key on creation"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:sid, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }` | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08769"></a>T-08769 / [52](../../../test/models/rp_sender_key_uniqueness_test.rb#L52) | "#{identity_class.name} scopes subjects by issuer and retains the immutable identity mapping"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_predicate identity_class.create!(keys.merge(subject: "other")), :persisted?`; `assert_predicate identity_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?`; `assert_equal principal.id, first.reload.principal_id`; +3 further assertion lines | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08770"></a>T-08770 / [75](../../../test/models/rp_sender_key_uniqueness_test.rb#L75) | "#{identity_class.name} preflights the complete subject key on creation"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:subject, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }` | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08771"></a>T-08771 / [90](../../../test/models/rp_sender_key_uniqueness_test.rb#L90) | "#{receipt_class.name} retains sender event and JTI scope with raw DB replay enforcement"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_predicate receipt_class.create!(keys.merge(jti_digest: Digest::SHA256.digest("other"))), :persisted?`; `assert_predicate receipt_class.create!(keys.merge(event_type: "other")), :persisted?`; `assert_predicate receipt_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?`; +1 further assertion lines | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08772"></a>T-08772 / [114](../../../test/models/rp_sender_key_uniqueness_test.rb#L114) | "#{receipt_class.name} preflights sender event and JTI together on creation"<br>Owner: `RpSenderKeyUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:jti_digest, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }` | [RpBaseAppEventReceipt](../../../app/models/rp_base_app_event_receipt.rb#L4); [RpBaseAppOpSessionBinding](../../../app/models/rp_base_app_op_session_binding.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_session_retirement_window_test.rb`

[test/models/rp_session_retirement_window_test.rb](../../../test/models/rp_session_retirement_window_test.rb); SHA-256: `1323929d78c98a0d9032628da916380be78aad327e76b2b430f00fb31f23b2ff`.

File-level implementation candidates (including setup/import context): [app/controllers/concerns/session.rb:14](../../../app/controllers/concerns/session.rb#L14); [app/models/op_app_grant.rb:4](../../../app/models/op_app_grant.rb#L4); [app/models/client_token.rb:89](../../../app/models/client_token.rb#L89); [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/values/security_token_lifetimes.rb:9](../../../app/values/security_token_lifetimes.rb#L9).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08773"></a>T-08773 / [21](../../../test/models/rp_session_retirement_window_test.rb#L21) | "a session that is not revoked is still pending retirement"<br>Owner: `RpSessionRetirementWindowTest` | `assert @session.retirement_pending?(@access_expires_at + 1.year)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08774"></a>T-08774 / [25](../../../test/models/rp_session_retirement_window_test.rb#L25) | "a revoked session with no recorded Access JWT expiry stays pending because nothing proves retirement"<br>Owner: `RpSessionRetirementWindowTest` | `assert_nil @session.reload.oidc_access_token_max_expires_at`; `assert @session.retirement_pending?(@access_expires_at + 1.year)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08775"></a>T-08775 / [32](../../../test/models/rp_session_retirement_window_test.rb#L32) | "a revoked session is pending one second before the leeway after its last Access JWT expiry"<br>Owner: `RpSessionRetirementWindowTest` | `assert @session.retirement_pending?(@access_expires_at + @leeway - 1.second)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08776"></a>T-08776 / [39](../../../test/models/rp_session_retirement_window_test.rb#L39) | "a revoked session is retired exactly at the leeway after its last Access JWT expiry"<br>Owner: `RpSessionRetirementWindowTest` | `assert_not @session.retirement_pending?(@access_expires_at + @leeway)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08777"></a>T-08777 / [46](../../../test/models/rp_session_retirement_window_test.rb#L46) | "a revoked session is retired one second after the leeway after its last Access JWT expiry"<br>Owner: `RpSessionRetirementWindowTest` | `assert_not @session.retirement_pending?(@access_expires_at + @leeway + 1.second)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08778"></a>T-08778 / [53](../../../test/models/rp_session_retirement_window_test.rb#L53) | "recording a shorter Access JWT expiry cannot shorten the retirement window"<br>Owner: `RpSessionRetirementWindowTest` | `assert_equal @access_expires_at, recorded`; `assert_equal @access_expires_at, @session.reload.oidc_access_token_max_expires_at` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08779"></a>T-08779 / [62](../../../test/models/rp_session_retirement_window_test.rb#L62) | "recording an equal Access JWT expiry keeps the stored value"<br>Owner: `RpSessionRetirementWindowTest` | `assert_equal @access_expires_at, @session.record_access_token_expiry!(@access_expires_at)` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08780"></a>T-08780 / [68](../../../test/models/rp_session_retirement_window_test.rb#L68) | "recording a longer Access JWT expiry extends the retirement window"<br>Owner: `RpSessionRetirementWindowTest` | `assert_equal @access_expires_at + 1.second, recorded`; `assert_equal @access_expires_at + 1.second, @session.reload.oidc_access_token_max_expires_at` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08781"></a>T-08781 / [77](../../../test/models/rp_session_retirement_window_test.rb#L77) | "recording an expiry that is not a time is rejected and stores nothing"<br>Owner: `RpSessionRetirementWindowTest` | `assert_raises(ArgumentError) { @session.record_access_token_expiry!(nil) }`; `assert_raises(ArgumentError) { @session.record_access_token_expiry!(0) }`; `assert_nil @session.reload.oidc_access_token_max_expires_at` | [Session](../../../app/controllers/concerns/session.rb#L14); [OpAppGrant](../../../app/models/op_app_grant.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_session_test.rb`

[test/models/rp_session_test.rb](../../../test/models/rp_session_test.rb); SHA-256: `2375f9589a70c0f2003e9d971ef5cde5ad5c19e37ce3ca7828552a2f13796eb5`.

File-level implementation candidates (including setup/import context): [app/models/op_app_grant.rb:4](../../../app/models/op_app_grant.rb#L4); [app/models/client_token.rb:89](../../../app/models/client_token.rb#L89); [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/op_org_grant.rb:4](../../../app/models/op_org_grant.rb#L4); [app/models/operator_token.rb:87](../../../app/models/operator_token.rb#L87).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08782"></a>T-08782 / [48](../../../test/models/rp_session_test.rb#L48) | "#{rp_session_case[:name]} RP parent idle window #{label} expiry preserves Root authority"<br>Owner: `RpSessionTest` | `assert_equal usable, session.parent_token_active?(decision_time)`; `assert_equal usable, session.active?(decision_time)`; `assert_predicate session.issue_refresh_token!(now: decision_time), :present?`; +3 further assertion lines | [SecurityTokenLifetimes](../../../app/values/security_token_lifetimes.rb#L9); [RpSession::IssuanceRejected](../../../app/models/concerns/rp_session.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08783"></a>T-08783 / [81](../../../test/models/rp_session_test.rb#L81) | "#{rp_session_case[:name]} rp session generates a public id and validates parent and rp identity"<br>Owner: `RpSessionTest` | `assert_predicate session.public_id, :present?`; `assert_equal 21, session.public_id.length`; `assert_predicate session.public_id, :ascii_only?`; +3 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08784"></a>T-08784 / [98](../../../test/models/rp_session_test.rb#L98) | "#{rp_session_case[:name]} rp session enforces active parent and RP uniqueness"<br>Owner: `RpSessionTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_predicate replacement, :persisted?`; `assert_equal root.id, replacement.public_send(rp_session_case[:parent_key])`; +1 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08785"></a>T-08785 / [130](../../../test/models/rp_session_test.rb#L130) | "#{rp_session_case[:name]} rp session remains when the rotating root row is physically deleted"<br>Owner: `RpSessionTest` | `assert_no_difference -&gt; { rp_session_case[:model].count } do`; `assert rp_session_case[:model].exists?(session.id)`; `assert_not session.reload.active?` | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08786"></a>T-08786 / [147](../../../test/models/rp_session_test.rb#L147) | "#{rp_session_case[:name]} rp session stays usable when the root token rotates to a new row"<br>Owner: `RpSessionTest` | `assert_equal :rotated, result.fetch(:status)`; `assert_not_equal root.id, replacement.id`; `assert_equal replacement.id, replacement.device_session.reload.current_refresh_token_id`; +3 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08787"></a>T-08787 / [171](../../../test/models/rp_session_test.rb#L171) | "#{rp_session_case[:name]} rp session rotates refresh tokens without exposing raw secrets"<br>Owner: `RpSessionTest` | `assert_predicate raw_refresh_token, :present?`; `assert_predicate session.refresh_token_digest, :present?`; `assert_predicate session.refresh_token_digest, :ascii_only?`; +2 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08788"></a>T-08788 / [189](../../../test/models/rp_session_test.rb#L189) | "#{rp_session_case[:name]} rp session refresh expiry cannot exceed its root session"<br>Owner: `RpSessionTest` | `assert_operator session.reload.refresh_token_expires_at, :&lt;=, absolute_expiry`; `assert_equal absolute_expiry.to_i, session.refresh_token_expires_at.to_i`; `assert_operator session.reload.refresh_token_expires_at, :&lt;=, absolute_expiry`; +1 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08789"></a>T-08789 / [211](../../../test/models/rp_session_test.rb#L211) | "#{rp_session_case[:name]} RP session rejects a missing or infinite parent or child expiry"<br>Owner: `RpSessionTest` | `assert_not_predicate session.reload, :active?`; `assert_raises(RpSession::IssuanceRejected) { session.issue_refresh_token! }`; `assert_not_predicate session.reload, :active?`; +5 further assertion lines | [RpSession::IssuanceRejected](../../../app/models/concerns/rp_session.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08790"></a>T-08790 / [242](../../../test/models/rp_session_test.rb#L242) | "#{rp_session_case[:name]} rp session detects a replay of the digest superseded by rotation"<br>Owner: `RpSessionTest` | `assert_not session.previous_refresh_token_digest_matches?(superseded_verifier)`; `assert session.previous_refresh_token_digest_matches?(superseded_verifier)`; `assert_not session.previous_refresh_token_digest_matches?(current_verifier)`; +2 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08791"></a>T-08791 / [264](../../../test/models/rp_session_test.rb#L264) | "#{rp_session_case[:name]} rp session refuses access-token expiry recording after revoke"<br>Owner: `RpSessionTest` | `assert_raises(RpSession::IssuanceRejected) do`; `assert_nil session.reload.oidc_access_token_max_expires_at` | [RpSession::IssuanceRejected](../../../app/models/concerns/rp_session.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08792"></a>T-08792 / [280](../../../test/models/rp_session_test.rb#L280) | "#{rp_session_case[:name]} rp session refuses refresh issuance after revoke"<br>Owner: `RpSessionTest` | `assert_raises(RpSession::IssuanceRejected) do`; `assert_nil session.reload.refresh_token_digest` | [RpSession::IssuanceRejected](../../../app/models/concerns/rp_session.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08793"></a>T-08793 / [296](../../../test/models/rp_session_test.rb#L296) | "#{rp_session_case[:name]} rp session uses the writer database clock for lifecycle changes"<br>Owner: `RpSessionTest` | `assert_equal database_time.to_i, issued.last_used_at.to_i`; `assert_equal database_time.to_i, rotated.last_used_at.to_i`; `assert_equal database_time.to_i, rotated.refresh_token_rotated_at.to_i`; +3 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [ClientToken](../../../app/models/client_token.rb#L89) | S: static inventory; individual semantic review open | stubbed-boundary |

## `test/models/rp_tech_org_principal_test.rb`

[test/models/rp_tech_org_principal_test.rb](../../../test/models/rp_tech_org_principal_test.rb); SHA-256: `8dd99b8495de1daf33d4e822041c7b5844e87da2f61c92c61003d09efcdb3329`.

File-level implementation candidates (including setup/import context): [app/models/rp_tech_org_principal.rb:4](../../../app/models/rp_tech_org_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08794"></a>T-08794 / [6](../../../test/models/rp_tech_org_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpTechOrgPrincipalTest` | `assert_public_id_fixed_length(::RpTechOrgPrincipal)` | [RpTechOrgPrincipal](../../../app/models/rp_tech_org_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_tech_org_refresh_attempt_test.rb`

[test/models/rp_tech_org_refresh_attempt_test.rb](../../../test/models/rp_tech_org_refresh_attempt_test.rb); SHA-256: `2c0f44abfce76aa909fd0cdfb2f29c296af58e5175898946011af00b96f8be78`.

File-level implementation candidates (including setup/import context): [app/models/rp_tech_org_refresh_attempt.rb:4](../../../app/models/rp_tech_org_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08795"></a>T-08795 / [6](../../../test/models/rp_tech_org_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpTechOrgRefreshAttemptTest` | `assert_public_id_fixed_length(::RpTechOrgRefreshAttempt)` | [RpTechOrgRefreshAttempt](../../../app/models/rp_tech_org_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_tech_org_session_test.rb`

[test/models/rp_tech_org_session_test.rb](../../../test/models/rp_tech_org_session_test.rb); SHA-256: `acd6fddb891c8d37364342bdfccacf875c133e51c16378a83d228e864d60e1ed`.

File-level implementation candidates (including setup/import context): [app/models/rp_tech_org_session.rb:4](../../../app/models/rp_tech_org_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08796"></a>T-08796 / [6](../../../test/models/rp_tech_org_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpTechOrgSessionTest` | `assert_public_id_fixed_length(::RpTechOrgSession)` | [RpTechOrgSession](../../../app/models/rp_tech_org_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_app_principal_test.rb`

[test/models/rp_warp_app_principal_test.rb](../../../test/models/rp_warp_app_principal_test.rb); SHA-256: `d422af4db4ad48e72b0a73729cba984f47eede1e0f5bf446d423a676a48ebbaf`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_app_principal.rb:4](../../../app/models/rp_warp_app_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08797"></a>T-08797 / [6](../../../test/models/rp_warp_app_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpAppPrincipalTest` | `assert_public_id_fixed_length(::RpWarpAppPrincipal)` | [RpWarpAppPrincipal](../../../app/models/rp_warp_app_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_app_refresh_attempt_test.rb`

[test/models/rp_warp_app_refresh_attempt_test.rb](../../../test/models/rp_warp_app_refresh_attempt_test.rb); SHA-256: `3f36994151e62c31257b5d7d5aed7a553b5181269d0fe7be612a340aece8949a`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_app_refresh_attempt.rb:4](../../../app/models/rp_warp_app_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08798"></a>T-08798 / [6](../../../test/models/rp_warp_app_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpAppRefreshAttemptTest` | `assert_public_id_fixed_length(::RpWarpAppRefreshAttempt)` | [RpWarpAppRefreshAttempt](../../../app/models/rp_warp_app_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_app_session_test.rb`

[test/models/rp_warp_app_session_test.rb](../../../test/models/rp_warp_app_session_test.rb); SHA-256: `fb5d5c55837b5f7072478cad72c48af600377af0246343fddccedf7c95d18919`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_app_session.rb:4](../../../app/models/rp_warp_app_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08799"></a>T-08799 / [6](../../../test/models/rp_warp_app_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpAppSessionTest` | `assert_public_id_fixed_length(::RpWarpAppSession)` | [RpWarpAppSession](../../../app/models/rp_warp_app_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_com_principal_test.rb`

[test/models/rp_warp_com_principal_test.rb](../../../test/models/rp_warp_com_principal_test.rb); SHA-256: `b1babc5782cb7e274097a46d0836fbbbce6d08f57de1a561978dfd01d8b41541`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_com_principal.rb:4](../../../app/models/rp_warp_com_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08800"></a>T-08800 / [6](../../../test/models/rp_warp_com_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpComPrincipalTest` | `assert_public_id_fixed_length(::RpWarpComPrincipal)` | [RpWarpComPrincipal](../../../app/models/rp_warp_com_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_com_refresh_attempt_test.rb`

[test/models/rp_warp_com_refresh_attempt_test.rb](../../../test/models/rp_warp_com_refresh_attempt_test.rb); SHA-256: `3d7e5a57fa16beb6a998af3dd375efafa9087777e3660f88eb0b8b2196ce7f4a`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_com_refresh_attempt.rb:4](../../../app/models/rp_warp_com_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08801"></a>T-08801 / [6](../../../test/models/rp_warp_com_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpComRefreshAttemptTest` | `assert_public_id_fixed_length(::RpWarpComRefreshAttempt)` | [RpWarpComRefreshAttempt](../../../app/models/rp_warp_com_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_com_session_test.rb`

[test/models/rp_warp_com_session_test.rb](../../../test/models/rp_warp_com_session_test.rb); SHA-256: `ee3c809610571a7f7f4a36bbb4c7cdd6881ba78836803ed7f0ce430b477ce602`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_com_session.rb:4](../../../app/models/rp_warp_com_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08802"></a>T-08802 / [6](../../../test/models/rp_warp_com_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpComSessionTest` | `assert_public_id_fixed_length(::RpWarpComSession)` | [RpWarpComSession](../../../app/models/rp_warp_com_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_org_principal_test.rb`

[test/models/rp_warp_org_principal_test.rb](../../../test/models/rp_warp_org_principal_test.rb); SHA-256: `1021a080317e855380e3f2eb3777c85e0dcc151648e458ff73458c5b60d555c3`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_org_principal.rb:4](../../../app/models/rp_warp_org_principal.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08803"></a>T-08803 / [6](../../../test/models/rp_warp_org_principal_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpOrgPrincipalTest` | `assert_public_id_fixed_length(::RpWarpOrgPrincipal)` | [RpWarpOrgPrincipal](../../../app/models/rp_warp_org_principal.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_org_refresh_attempt_test.rb`

[test/models/rp_warp_org_refresh_attempt_test.rb](../../../test/models/rp_warp_org_refresh_attempt_test.rb); SHA-256: `d8e7272f4cd6b7bb8a60a9e51c07e5d18d646e7507bab9df670a787ae08530a6`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_org_refresh_attempt.rb:4](../../../app/models/rp_warp_org_refresh_attempt.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08804"></a>T-08804 / [6](../../../test/models/rp_warp_org_refresh_attempt_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpOrgRefreshAttemptTest` | `assert_public_id_fixed_length(::RpWarpOrgRefreshAttempt)` | [RpWarpOrgRefreshAttempt](../../../app/models/rp_warp_org_refresh_attempt.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/rp_warp_org_session_test.rb`

[test/models/rp_warp_org_session_test.rb](../../../test/models/rp_warp_org_session_test.rb); SHA-256: `6b9902db450b46aba962d5aa7a5f61c01ab499e556cb61a512bd8f7a5d8a89e3`.

File-level implementation candidates (including setup/import context): [app/models/rp_warp_org_session.rb:4](../../../app/models/rp_warp_org_session.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08805"></a>T-08805 / [6](../../../test/models/rp_warp_org_session_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `RpWarpOrgSessionTest` | `assert_public_id_fixed_length(::RpWarpOrgSession)` | [RpWarpOrgSession](../../../app/models/rp_warp_org_session.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
