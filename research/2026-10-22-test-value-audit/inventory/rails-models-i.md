# rails-models-i: per-definition ledger

59 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/id_column_type_test.rb`

[test/models/id_column_type_test.rb](../../../test/models/id_column_type_test.rb); SHA-256: `dd5061d2830eaec504d40848decb003cc25ff45e17d75f52857ad014b42a5463`.

File-level implementation candidates (including setup/import context): [app/models/app_principal_record.rb:5](../../../app/models/app_principal_record.rb#L5); [app/models/client_membership.rb:27](../../../app/models/client_membership.rb#L27); [app/models/client_notification_record.rb:21](../../../app/models/client_notification_record.rb#L21); [app/models/operator_notification_record.rb:20](../../../app/models/operator_notification_record.rb#L20); [app/models/visitor_notification_record.rb:20](../../../app/models/visitor_notification_record.rb#L20).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07459"></a>T-07459 / [7](../../../test/models/id_column_type_test.rb#L7) | "roles and memberships use bigint foreign keys"<br>Owner: `IdColumnTypeTest` | `assert_bigint_table_column(AppPrincipalRecord.connection, :roles, "organization_id")`; `assert_bigint_column(ClientMembership, "workspace_id")` | [AppPrincipalRecord](../../../app/models/app_principal_record.rb#L5); [ClientMembership](../../../app/models/client_membership.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07460"></a>T-07460 / [12](../../../test/models/id_column_type_test.rb#L12) | "notification public_id columns are strings"<br>Owner: `IdColumnTypeTest` | `assert_string_column(model, "public_id")` | [ClientNotificationRecord](../../../app/models/client_notification_record.rb#L21); [OperatorNotificationRecord](../../../app/models/operator_notification_record.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/identity_dead_history_erasure_test.rb`

[test/models/identity_dead_history_erasure_test.rb](../../../test/models/identity_dead_history_erasure_test.rb); SHA-256: `76c7e7c756bf413e1c40b19725989e8434e5ac0bf558dcb0c44577239f7cac36`.

File-level implementation candidates (including setup/import context): [app/models/concerns/identity.rb:6](../../../app/models/concerns/identity.rb#L6); [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/client_email_history.rb:3](../../../app/models/client_email_history.rb#L3); [app/models/client_telephone_history.rb:3](../../../app/models/client_telephone_history.rb#L3); [app/models/client_email.rb:44](../../../app/models/client_email.rb#L44).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07461"></a>T-07461 / [28](../../../test/models/identity_dead_history_erasure_test.rb#L28) | "#{realm} permitted physical Identity erasure removes only its dead histories"<br>Owner: `IdentityDeadHistoryErasureTest` | `assert_not owner_model.exists?(owner.id)`; `histories.each { \|history\| assert_not history.class.exists?(history.id) }`; `assert email_history.exists?(peer_history.id)`; +5 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07462"></a>T-07462 / [70](../../../test/models/identity_dead_history_erasure_test.rb#L70) | "#{realm} database transport failure preserves Identity and history for an identical retry"<br>Owner: `IdentityDeadHistoryErasureTest` | `assert_raises(ActiveRecord::StatementInvalid) { owner.destroy! }`; `assert owner_model.exists?(owner.id)`; `assert email_history.exists?(history.id)`; +2 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | stubbed-boundary |
| <a id="t-07463"></a>T-07463 / [100](../../../test/models/identity_dead_history_erasure_test.rb#L100) | "#{realm} physical Identity erasure refuses an active legal hold without deleting history"<br>Owner: `IdentityDeadHistoryErasureTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }`; `assert owner_model.exists?(owner.id)`; `assert email_history.exists?(history.id)`; +1 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07464"></a>T-07464 / [120](../../../test/models/identity_dead_history_erasure_test.rb#L120) | "#{realm} protected Contact rolls back physical Identity erasure and prior Source archive"<br>Owner: `IdentityDeadHistoryErasureTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }`; `assert owner_model.exists?(owner.id)`; `assert email_model.exists?(original.id)`; +3 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientEmail](../../../app/models/client_email.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07465"></a>T-07465 / [149](../../../test/models/identity_dead_history_erasure_test.rb#L149) | "#{realm} recoverable Identity cannot physically delete its dead histories"<br>Owner: `IdentityDeadHistoryErasureTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }`; `assert owner_model.exists?(owner.id)`; `assert email_history.exists?(history.id)` | [Client](../../../app/models/client.rb#L76); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/individual_assignment_test.rb`

[test/models/individual_assignment_test.rb](../../../test/models/individual_assignment_test.rb); SHA-256: `ec7fdcdf726f49eef114f50395b3f1181156ed1210b3ec9b378cad8456800f7f`.

File-level implementation candidates (including setup/import context): [app/models/visitor_identity_state.rb:11](../../../app/models/visitor_identity_state.rb#L11); [app/models/individual_assignment.rb:30](../../../app/models/individual_assignment.rb#L30); [app/models/visitor_identity.rb:32](../../../app/models/visitor_identity.rb#L32); [app/models/individual.rb:27](../../../app/models/individual.rb#L27).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07466"></a>T-07466 / [11](../../../test/models/individual_assignment_test.rb#L11) | "creates active assignment with public id and assigned at"<br>Owner: `IndividualAssignmentTest` | `assert_predicate assignment.public_id, :present?`; `assert_predicate assignment.assigned_at, :present?`; `assert_predicate assignment, :active?`; +1 further assertion lines | [IndividualAssignment](../../../app/models/individual_assignment.rb#L30) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07467"></a>T-07467 / [22](../../../test/models/individual_assignment_test.rb#L22) | "revoke marks assignment as revoked"<br>Owner: `IndividualAssignmentTest` | `assert_predicate assignment, :revoked?`; `assert_not_predicate assignment, :active?`; `assert_equal Time.utc(2026, 6, 27, 12, 0, 0), assignment.revoked_at` | [IndividualAssignment](../../../app/models/individual_assignment.rb#L30) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07468"></a>T-07468 / [33](../../../test/models/individual_assignment_test.rb#L33) | "rejects duplicate active assignment for the same pair"<br>Owner: `IndividualAssignmentTest` | `assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }` | [IndividualAssignment](../../../app/models/individual_assignment.rb#L30) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07469"></a>T-07469 / [43](../../../test/models/individual_assignment_test.rb#L43) | "allows a new active assignment after revoking the old one"<br>Owner: `IndividualAssignmentTest` | `assert_predicate second, :active?`; `assert_equal 2, IndividualAssignment.where(individual: individual, visitor_identity: identity).count` | [IndividualAssignment](../../../app/models/individual_assignment.rb#L30) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07470"></a>T-07470 / [55](../../../test/models/individual_assignment_test.rb#L55) | "public_id is a fixed 21-character NanoID"<br>Owner: `IndividualAssignmentTest` | `assert_public_id_fixed_length(::IndividualAssignment)` | [IndividualAssignment](../../../app/models/individual_assignment.rb#L30) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/individual_company_model_layer_test.rb`

[test/models/individual_company_model_layer_test.rb](../../../test/models/individual_company_model_layer_test.rb); SHA-256: `2159e65cfdacd0258e151042fcb69cbbdc322a9ecd5faa3a25f8054ac39028d8`.

File-level implementation candidates (including setup/import context): [app/models/visitor_identity_state.rb:11](../../../app/models/visitor_identity_state.rb#L11); [app/models/individual_membership_kind.rb:11](../../../app/models/individual_membership_kind.rb#L11); [app/models/individual_membership_state.rb:11](../../../app/models/individual_membership_state.rb#L11); [app/models/individual_membership_revoke_reason.rb:11](../../../app/models/individual_membership_revoke_reason.rb#L11); [app/models/individual.rb:27](../../../app/models/individual.rb#L27).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07471"></a>T-07471 / [14](../../../test/models/individual_company_model_layer_test.rb#L14) | "persona and organization concerns are included"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_includes Individual.included_modules, Persona`; `assert_includes Company.included_modules, Organization` | [Individual](../../../app/models/individual.rb#L27); [Persona](../../../app/models/concerns/persona.rb#L9) | S: static inventory; individual semantic review open | metadata-oracle |
| <a id="t-07472"></a>T-07472 / [19](../../../test/models/individual_company_model_layer_test.rb#L19) | "root and child unit closure rows are maintained"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_equal 0, CompanyUnitClosure.find_by!(ancestor: root, descendant: root).depth`; `assert_equal 0, CompanyUnitClosure.find_by!(ancestor: child, descendant: child).depth`; `assert_equal 1, CompanyUnitClosure.find_by!(ancestor: root, descendant: child).depth`; +2 further assertion lines | [Company](../../../app/models/company.rb#L20); [CompanyUnit](../../../app/models/company_unit.rb#L31) | S: static inventory; individual semantic review open | metadata-oracle |
| <a id="t-07473"></a>T-07473 / [31](../../../test/models/individual_company_model_layer_test.rb#L31) | "unit parent must belong to same company and cannot be changed"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_not invalid.valid?`; `assert invalid.errors.of_kind?(:parent, :invalid)`; `assert_not sibling.valid?`; +1 further assertion lines | [Company](../../../app/models/company.rb#L20); [CompanyUnit](../../../app/models/company_unit.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07474"></a>T-07474 / [47](../../../test/models/individual_company_model_layer_test.rb#L47) | "membership validates company and active primary uniqueness"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:primary, :taken)`; `assert_not mismatch.valid?`; +1 further assertion lines | [Individual](../../../app/models/individual.rb#L27); [Company](../../../app/models/company.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07475"></a>T-07475 / [85](../../../test/models/individual_company_model_layer_test.rb#L85) | "persona exposes current membership and organization protocol"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_equal :individual_memberships, Individual.membership_association_name`; `assert_equal membership, individual.primary_membership`; `assert_equal membership, individual.current_membership`; +8 further assertion lines | [Individual](../../../app/models/individual.rb#L27); [Company](../../../app/models/company.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07476"></a>T-07476 / [111](../../../test/models/individual_company_model_layer_test.rb#L111) | "database rejects identity and company hierarchy integrity violations"<br>Owner: `IndividualCompanyModelLayerTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_raises(ActiveRecord::InvalidForeignKey) do` | [Individual](../../../app/models/individual.rb#L27); [Company](../../../app/models/company.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/individual_membership_kind_test.rb`

[test/models/individual_membership_kind_test.rb](../../../test/models/individual_membership_kind_test.rb); SHA-256: `502676bf6e568f0ad84def650c8253da940939ccd085a8fc4828c0608b4d6358`.

File-level implementation candidates (including setup/import context): [app/models/individual_membership_kind.rb:11](../../../app/models/individual_membership_kind.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07477"></a>T-07477 / [15](../../../test/models/individual_membership_kind_test.rb#L15) | "accepts integer ids"<br>Owner: `IndividualMembershipKindTest` | `assert_predicate kind, :valid?` | [IndividualMembershipKind](../../../app/models/individual_membership_kind.rb#L11) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07478"></a>T-07478 / [21](../../../test/models/individual_membership_kind_test.rb#L21) | "constants are defined"<br>Owner: `IndividualMembershipKindTest` | `assert_equal 0, IndividualMembershipKind::NOTHING`; `assert_equal 1, IndividualMembershipKind::OWNER`; `assert_equal 2, IndividualMembershipKind::MEMBER`; +1 further assertion lines | [IndividualMembershipKind](../../../app/models/individual_membership_kind.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07479"></a>T-07479 / [28](../../../test/models/individual_membership_kind_test.rb#L28) | "defaults are defined"<br>Owner: `IndividualMembershipKindTest` | `assert_equal [0, 1, 2, 3], IndividualMembershipKind::DEFAULTS` | [IndividualMembershipKind](../../../app/models/individual_membership_kind.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07480"></a>T-07480 / [32](../../../test/models/individual_membership_kind_test.rb#L32) | "nothing_id returns NOTHING constant"<br>Owner: `IndividualMembershipKindTest` | `assert_equal IndividualMembershipKind::NOTHING, IndividualMembershipKind.nothing_id` | [IndividualMembershipKind](../../../app/models/individual_membership_kind.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07481"></a>T-07481 / [36](../../../test/models/individual_membership_kind_test.rb#L36) | "has many individual_memberships"<br>Owner: `IndividualMembershipKindTest` | `assert_equal :has_many, IndividualMembershipKind.reflect_on_association(:individual_memberships).macro` | [IndividualMembershipKind](../../../app/models/individual_membership_kind.rb#L11) | S: static inventory; individual semantic review open | metadata-oracle |

## `test/models/individual_membership_revoke_reason_test.rb`

[test/models/individual_membership_revoke_reason_test.rb](../../../test/models/individual_membership_revoke_reason_test.rb); SHA-256: `b2d580ea23134e2002e62e0bf8a147cbe038fea5855c0d7ec67e05cbc8c3f9d7`.

File-level implementation candidates (including setup/import context): [app/models/individual_membership_revoke_reason.rb:11](../../../app/models/individual_membership_revoke_reason.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07482"></a>T-07482 / [15](../../../test/models/individual_membership_revoke_reason_test.rb#L15) | "accepts integer ids"<br>Owner: `IndividualMembershipRevokeReasonTest` | `assert_predicate reason, :valid?` | [IndividualMembershipRevokeReason](../../../app/models/individual_membership_revoke_reason.rb#L11) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07483"></a>T-07483 / [21](../../../test/models/individual_membership_revoke_reason_test.rb#L21) | "constants are defined"<br>Owner: `IndividualMembershipRevokeReasonTest` | `assert_equal 0, IndividualMembershipRevokeReason::NOTHING`; `assert_equal 1, IndividualMembershipRevokeReason::MANUAL`; `assert_equal 2, IndividualMembershipRevokeReason::EXPIRED`; +1 further assertion lines | [IndividualMembershipRevokeReason](../../../app/models/individual_membership_revoke_reason.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07484"></a>T-07484 / [28](../../../test/models/individual_membership_revoke_reason_test.rb#L28) | "defaults are defined"<br>Owner: `IndividualMembershipRevokeReasonTest` | `assert_equal [0, 1, 2, 3], IndividualMembershipRevokeReason::DEFAULTS` | [IndividualMembershipRevokeReason](../../../app/models/individual_membership_revoke_reason.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07485"></a>T-07485 / [32](../../../test/models/individual_membership_revoke_reason_test.rb#L32) | "nothing_id returns NOTHING constant"<br>Owner: `IndividualMembershipRevokeReasonTest` | `assert_equal IndividualMembershipRevokeReason::NOTHING, IndividualMembershipRevokeReason.nothing_id` | [IndividualMembershipRevokeReason](../../../app/models/individual_membership_revoke_reason.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07486"></a>T-07486 / [36](../../../test/models/individual_membership_revoke_reason_test.rb#L36) | "has many individual_memberships"<br>Owner: `IndividualMembershipRevokeReasonTest` | `assert_equal :has_many, IndividualMembershipRevokeReason.reflect_on_association(:individual_memberships).macro` | [IndividualMembershipRevokeReason](../../../app/models/individual_membership_revoke_reason.rb#L11) | S: static inventory; individual semantic review open | metadata-oracle |

## `test/models/individual_membership_state_test.rb`

[test/models/individual_membership_state_test.rb](../../../test/models/individual_membership_state_test.rb); SHA-256: `1ca162750befd757f8d0adb9ec172e8d0f86fe9e5ad42b5bbb25a73e33b8fbb0`.

File-level implementation candidates (including setup/import context): [app/models/individual_membership_state.rb:11](../../../app/models/individual_membership_state.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07487"></a>T-07487 / [15](../../../test/models/individual_membership_state_test.rb#L15) | "accepts integer ids"<br>Owner: `IndividualMembershipStateTest` | `assert_predicate state, :valid?` | [IndividualMembershipState](../../../app/models/individual_membership_state.rb#L11) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07488"></a>T-07488 / [21](../../../test/models/individual_membership_state_test.rb#L21) | "constants are defined"<br>Owner: `IndividualMembershipStateTest` | `assert_equal 0, IndividualMembershipState::NOTHING`; `assert_equal 1, IndividualMembershipState::ACTIVE`; `assert_equal 2, IndividualMembershipState::PENDING`; +3 further assertion lines | [IndividualMembershipState](../../../app/models/individual_membership_state.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07489"></a>T-07489 / [30](../../../test/models/individual_membership_state_test.rb#L30) | "defaults are defined"<br>Owner: `IndividualMembershipStateTest` | `assert_equal [0, 1, 2, 3, 4, 5], IndividualMembershipState::DEFAULTS` | [IndividualMembershipState](../../../app/models/individual_membership_state.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07490"></a>T-07490 / [34](../../../test/models/individual_membership_state_test.rb#L34) | "nothing_id returns NOTHING constant"<br>Owner: `IndividualMembershipStateTest` | `assert_equal IndividualMembershipState::NOTHING, IndividualMembershipState.nothing_id` | [IndividualMembershipState](../../../app/models/individual_membership_state.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07491"></a>T-07491 / [38](../../../test/models/individual_membership_state_test.rb#L38) | "has many individual_memberships"<br>Owner: `IndividualMembershipStateTest` | `assert_equal :has_many, IndividualMembershipState.reflect_on_association(:individual_memberships).macro` | [IndividualMembershipState](../../../app/models/individual_membership_state.rb#L11) | S: static inventory; individual semantic review open | metadata-oracle |

## `test/models/individual_ownership_transfer_request_test.rb`

[test/models/individual_ownership_transfer_request_test.rb](../../../test/models/individual_ownership_transfer_request_test.rb); SHA-256: `5c0158b5fff81ab55c8f182ef9bf30266dc738db27f57f191d619d6a8d91deb8`.

File-level implementation candidates (including setup/import context): [app/models/individual_ownership_transfer_request.rb:4](../../../app/models/individual_ownership_transfer_request.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07492"></a>T-07492 / [6](../../../test/models/individual_ownership_transfer_request_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `IndividualOwnershipTransferRequestTest` | `assert_public_id_fixed_length(::IndividualOwnershipTransferRequest)` | [IndividualOwnershipTransferRequest](../../../app/models/individual_ownership_transfer_request.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/individual_test.rb`

[test/models/individual_test.rb](../../../test/models/individual_test.rb); SHA-256: `544e149cac8aba99101296844b0e65ec673c741387b6101ae6572236503b781e`.

File-level implementation candidates (including setup/import context): [app/models/individual.rb:27](../../../app/models/individual.rb#L27).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07493"></a>T-07493 / [6](../../../test/models/individual_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `IndividualTest` | `assert_public_id_fixed_length(::Individual)` | [Individual](../../../app/models/individual.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_client_occurrence_test.rb`

[test/models/ip_client_occurrence_test.rb](../../../test/models/ip_client_occurrence_test.rb); SHA-256: `ea4833172343c26f9674212755a09c9c81b864d11d32db3b63ac5f40558f5c4f`.

File-level implementation candidates (including setup/import context): [app/models/ip_client_occurrence.rb:26](../../../app/models/ip_client_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07494"></a>T-07494 / [29](../../../test/models/ip_client_occurrence_test.rb#L29) | "class is defined"<br>Owner: `IpClientOccurrenceTest` | `assert_equal "IpClientOccurrence", IpClientOccurrence.name` | [IpClientOccurrence](../../../app/models/ip_client_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_occurrence_status_test.rb`

[test/models/ip_occurrence_status_test.rb](../../../test/models/ip_occurrence_status_test.rb); SHA-256: `7eee5c0dc42ae9e28139fbdd255e4f83a669ddda3bf87be7265122a49c43dc19`.

File-level implementation candidates (including setup/import context): [app/models/ip_occurrence_status.rb:12](../../../app/models/ip_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07495"></a>T-07495 / [15](../../../test/models/ip_occurrence_status_test.rb#L15) | "can load nothing status from db"<br>Owner: `IpOccurrenceStatusTest` | `assert_not_nil nothing`; `assert_equal 0, nothing.id` | [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07496"></a>T-07496 / [22](../../../test/models/ip_occurrence_status_test.rb#L22) | "accepts integer ids"<br>Owner: `IpOccurrenceStatusTest` | `assert_predicate record, :valid?` | [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07497"></a>T-07497 / [28](../../../test/models/ip_occurrence_status_test.rb#L28) | "constants are defined"<br>Owner: `IpOccurrenceStatusTest` | `assert_equal 1, IpOccurrenceStatus::ACTIVE`; `assert_equal 0, IpOccurrenceStatus::NOTHING` | [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07498"></a>T-07498 / [33](../../../test/models/ip_occurrence_status_test.rb#L33) | "has occurrences association"<br>Owner: `IpOccurrenceStatusTest` | `assert_status_association(IpOccurrenceStatus, :ip_occurrences)` | [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07499"></a>T-07499 / [37](../../../test/models/ip_occurrence_status_test.rb#L37) | "ensure_defaults! creates default records"<br>Owner: `IpOccurrenceStatusTest` | `assert IpOccurrenceStatus.exists?(id), "missing default ip occurrence status #{id}"` | [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | [LV-012](../findings.md#lv-012) confirmed | none detected (not a quality approval) |

## `test/models/ip_occurrence_test.rb`

[test/models/ip_occurrence_test.rb](../../../test/models/ip_occurrence_test.rb); SHA-256: `de036838402add7639c84217b98f5abd55a306199fef814f07a2849596cab320`.

File-level implementation candidates (including setup/import context): [app/models/ip_occurrence.rb:32](../../../app/models/ip_occurrence.rb#L32); [app/models/ip_occurrence_status.rb:12](../../../app/models/ip_occurrence_status.rb#L12); [app/models/area_ip_occurrence.rb:26](../../../app/models/area_ip_occurrence.rb#L26); [app/models/area_occurrence.rb:31](../../../app/models/area_occurrence.rb#L31).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07500"></a>T-07500 / [37](../../../test/models/ip_occurrence_test.rb#L37) | "defaults status_id to nothing"<br>Owner: `IpOccurrenceTest` | `assert_equal IpOccurrenceStatus::NOTHING, record.status_id` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32); [IpOccurrenceStatus](../../../app/models/ip_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07501"></a>T-07501 / [43](../../../test/models/ip_occurrence_test.rb#L43) | "public_id length"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07502"></a>T-07502 / [49](../../../test/models/ip_occurrence_test.rb#L49) | "public_id format"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07503"></a>T-07503 / [55](../../../test/models/ip_occurrence_test.rb#L55) | "public_id uniqueness"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07504"></a>T-07504 / [62](../../../test/models/ip_occurrence_test.rb#L62) | "body presence"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :body)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07505"></a>T-07505 / [68](../../../test/models/ip_occurrence_test.rb#L68) | "body uniqueness"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :body)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07506"></a>T-07506 / [75](../../../test/models/ip_occurrence_test.rb#L75) | "status_id presence"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :status_id)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07507"></a>T-07507 / [81](../../../test/models/ip_occurrence_test.rb#L81) | "memo length"<br>Owner: `IpOccurrenceTest` | `assert_invalid_attribute(record, :memo)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07508"></a>T-07508 / [87](../../../test/models/ip_occurrence_test.rb#L87) | "public_id auto generated on create"<br>Owner: `IpOccurrenceTest` | `assert_public_id_generated(record)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07509"></a>T-07509 / [93](../../../test/models/ip_occurrence_test.rb#L93) | "public_id preserved when provided"<br>Owner: `IpOccurrenceTest` | `assert_public_id_preserved(record, custom_public_id)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07510"></a>T-07510 / [100](../../../test/models/ip_occurrence_test.rb#L100) | "lifecycle timestamps default"<br>Owner: `IpOccurrenceTest` | `assert_occurrence_lifecycle_defaults(record)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07511"></a>T-07511 / [106](../../../test/models/ip_occurrence_test.rb#L106) | "association deletion: destroys joining relations"<br>Owner: `IpOccurrenceTest` | `assert_raise(ActiveRecord::RecordNotFound) { join.reload }` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32); [AreaIpOccurrence](../../../app/models/area_ip_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07512"></a>T-07512 / [121](../../../test/models/ip_occurrence_test.rb#L121) | "public_id is a fixed 21-character NanoID"<br>Owner: `IpOccurrenceTest` | `assert_public_id_fixed_length(::IpOccurrence)` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_staff_occurrence_test.rb`

[test/models/ip_staff_occurrence_test.rb](../../../test/models/ip_staff_occurrence_test.rb); SHA-256: `e8e3eb2e5c14c01799d07c4fcc60b8d0beff5ce7bb78d4dfe9bb413b6b1f89fd`.

File-level implementation candidates (including setup/import context): [app/models/ip_operator_occurrence.rb:26](../../../app/models/ip_operator_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07513"></a>T-07513 / [29](../../../test/models/ip_staff_occurrence_test.rb#L29) | "class is defined"<br>Owner: `IpOperatorOccurrenceTest` | `assert_equal "IpOperatorOccurrence", IpOperatorOccurrence.name` | [IpOperatorOccurrence](../../../app/models/ip_operator_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_telephone_occurrence_test.rb`

[test/models/ip_telephone_occurrence_test.rb](../../../test/models/ip_telephone_occurrence_test.rb); SHA-256: `f4368d384e7035a465b9ff0938a509fff586d5d9bc3ab10d59af9f07d311751d`.

File-level implementation candidates (including setup/import context): [app/models/ip_telephone_occurrence.rb:26](../../../app/models/ip_telephone_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07514"></a>T-07514 / [29](../../../test/models/ip_telephone_occurrence_test.rb#L29) | "class is defined"<br>Owner: `IpTelephoneOccurrenceTest` | `assert_equal "IpTelephoneOccurrence", IpTelephoneOccurrence.name` | [IpTelephoneOccurrence](../../../app/models/ip_telephone_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_visitor_occurrence_test.rb`

[test/models/ip_visitor_occurrence_test.rb](../../../test/models/ip_visitor_occurrence_test.rb); SHA-256: `38c67bc070d2c7253c341d188744e56578b1a0f1ffa0c304c251d694dc071d36`.

File-level implementation candidates (including setup/import context): [app/models/visitor_occurrence_status.rb:12](../../../app/models/visitor_occurrence_status.rb#L12); [app/models/ip_occurrence.rb:32](../../../app/models/ip_occurrence.rb#L32); [app/models/visitor_occurrence.rb:33](../../../app/models/visitor_occurrence.rb#L33); [app/models/ip_visitor_occurrence.rb:25](../../../app/models/ip_visitor_occurrence.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07515"></a>T-07515 / [32](../../../test/models/ip_visitor_occurrence_test.rb#L32) | "associations"<br>Owner: `IpVisitorOccurrenceTest` | `assert record.save!`; `assert_equal ip, record.ip_occurrence`; `assert_equal visitor, record.visitor_occurrence` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32); [VisitorOccurrence](../../../app/models/visitor_occurrence.rb#L33) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07516"></a>T-07516 / [45](../../../test/models/ip_visitor_occurrence_test.rb#L45) | "uniqueness validation"<br>Owner: `IpVisitorOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:ip_occurrence_id]` | [IpOccurrence](../../../app/models/ip_occurrence.rb#L32); [VisitorOccurrence](../../../app/models/visitor_occurrence.rb#L33) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/ip_zip_occurrence_test.rb`

[test/models/ip_zip_occurrence_test.rb](../../../test/models/ip_zip_occurrence_test.rb); SHA-256: `6e71b1a68b9eaa9ca7da3eca185937275d573f09dbf4d0104a4b3633318589cc`.

File-level implementation candidates (including setup/import context): [app/models/ip_zip_occurrence.rb:26](../../../app/models/ip_zip_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07517"></a>T-07517 / [29](../../../test/models/ip_zip_occurrence_test.rb#L29) | "class is defined"<br>Owner: `IpZipOccurrenceTest` | `assert_equal "IpZipOccurrence", IpZipOccurrence.name` | [IpZipOccurrence](../../../app/models/ip_zip_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
