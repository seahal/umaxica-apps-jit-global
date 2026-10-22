# rails-models-d: per-definition ledger

63 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/database_consistency_test.rb`

[test/models/database_consistency_test.rb](../../../test/models/database_consistency_test.rb); SHA-256: `f43531e70f952d779cae1d3eaecdbf838a3f590f43d86c3935b9b46acfe28ea3`.

File-level implementation candidates (including setup/import context): [app/models/concerns/public_id.rb:7](../../../app/models/concerns/public_id.rb#L7); [app/models/client_email.rb:44](../../../app/models/client_email.rb#L44); [app/models/app_preference.rb:49](../../../app/models/app_preference.rb#L49); [app/models/app_preference_status.rb:12](../../../app/models/app_preference_status.rb#L12); [app/models/concerns/occurrence.rb:4](../../../app/models/concerns/occurrence.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07277"></a>T-07277 / [16](../../../test/models/database_consistency_test.rb#L16) | "ClientEmail requires unique public_id"<br>Owner: `DatabaseConsistencyTest` | `assert_predicate email, :valid?`; `assert_not duplicate.valid?`; `assert_includes duplicate.errors[:public_id], "はすでに存在します"` | [ClientEmail](../../../app/models/client_email.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07278"></a>T-07278 / [41](../../../test/models/database_consistency_test.rb#L41) | "ClientEmail auto-generates public_id when nil"<br>Owner: `DatabaseConsistencyTest` | `assert_not_nil email.public_id`; `assert_equal 21, email.public_id.length` | [ClientEmail](../../../app/models/client_email.rb#L44); [PublicId](../../../app/models/concerns/public_id.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07279"></a>T-07279 / [55](../../../test/models/database_consistency_test.rb#L55) | "AppPreference requires unique jti"<br>Owner: `DatabaseConsistencyTest` | `assert_not pref2.valid?`; `assert_includes pref2.errors[:jti], "はすでに存在します"` | [AppPreference](../../../app/models/app_preference.rb#L49); [AppPreferenceStatus](../../../app/models/app_preference_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07280"></a>T-07280 / [71](../../../test/models/database_consistency_test.rb#L71) | "ClientZipOccurrence requires unique combination of user_occurrence_id and zip_occurrence_id"<br>Owner: `DatabaseConsistencyTest` | `assert_not occurrence2.valid?`; `assert_includes occurrence2.errors[:user_occurrence_id], "はすでに存在します"` | [ClientOccurrence](../../../app/models/client_occurrence.rb#L34); [ClientOccurrenceStatus](../../../app/models/client_occurrence_status.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07281"></a>T-07281 / [97](../../../test/models/database_consistency_test.rb#L97) | "ClientEmail requires user association"<br>Owner: `DatabaseConsistencyTest` | `assert_not email.valid?`; `assert_includes email.errors[:user], "を入力してください"` | [ClientEmail](../../../app/models/client_email.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07282"></a>T-07282 / [111](../../../test/models/database_consistency_test.rb#L111) | "OperatorNotificationRecord requires operator association"<br>Owner: `DatabaseConsistencyTest` | `assert_not notification.valid?`; `assert_includes notification.errors[:operator], "を入力してください"` | [OperatorNotificationRecord](../../../app/models/operator_notification_record.rb#L20) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/database_pk_type_test.rb`

[test/models/database_pk_type_test.rb](../../../test/models/database_pk_type_test.rb); SHA-256: `9ec7a9d31d9756e23b27e5126b0daa2bb8fabcbebfb1f79231e2085136ed97ad`.

File-level implementation candidates (including setup/import context): [app/models/operator_workspace_account_status.rb:11](../../../app/models/operator_workspace_account_status.rb#L11); [app/models/operator_status.rb:12](../../../app/models/operator_status.rb#L12); [app/models/organization_status.rb:11](../../../app/models/organization_status.rb#L11); [app/models/client_status.rb:11](../../../app/models/client_status.rb#L11); [app/models/member_status.rb:13](../../../app/models/member_status.rb#L13).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07283"></a>T-07283 / [10](../../../test/models/database_pk_type_test.rb#L10) | "operator schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(OperatorWorkspaceAccountStatus)`; `assert_bigint_pk(OperatorStatus)`; `assert_bigint_pk(OrganizationStatus)` | [OperatorWorkspaceAccountStatus](../../../app/models/operator_workspace_account_status.rb#L11); [OperatorStatus](../../../app/models/operator_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07284"></a>T-07284 / [16](../../../test/models/database_pk_type_test.rb#L16) | "principal schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(ClientStatus)`; `assert_bigint_pk(MemberStatus)`; `assert_bigint_pk(ClientSecretCredential)` | [ClientStatus](../../../app/models/client_status.rb#L11); [MemberStatus](../../../app/models/member_status.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07285"></a>T-07285 / [22](../../../test/models/database_pk_type_test.rb#L22) | "avatar schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(HandleStatus)`; `assert_bigint_pk(AvatarCapability)` | [HandleStatus](../../../app/models/handle_status.rb#L11); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07286"></a>T-07286 / [27](../../../test/models/database_pk_type_test.rb#L27) | "occurrence schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(AreaOccurrenceStatus)`; `assert_bigint_pk(EmailOccurrenceStatus)` | [AreaOccurrenceStatus](../../../app/models/area_occurrence_status.rb#L12); [EmailOccurrenceStatus](../../../app/models/email_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07287"></a>T-07287 / [32](../../../test/models/database_pk_type_test.rb#L32) | "config, option, and setting schemas tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(ComPreferenceStatus)`; `assert_bigint_pk(ComPreferenceLanguageOption)`; `assert_bigint_pk(ComPreference)` | [ComPreferenceStatus](../../../app/models/com_preference_status.rb#L12); [ComPreferenceLanguageOption](../../../app/models/com_preference_language_option.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07288"></a>T-07288 / [38](../../../test/models/database_pk_type_test.rb#L38) | "guest schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(VisitorStatus)`; `assert_bigint_pk(VisitorSecretCredentialKind)` | [VisitorStatus](../../../app/models/visitor_status.rb#L12); [VisitorSecretCredentialKind](../../../app/models/visitor_secret_credential_kind.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07289"></a>T-07289 / [43](../../../test/models/database_pk_type_test.rb#L43) | "chronicle schema tables use bigint primary keys"<br>Owner: `DatabasePkTypeTest` | `assert_bigint_pk(OperatorChronicleEvent)`; `assert_bigint_pk(ClientChronicleLevel)` | [OperatorChronicleEvent](../../../app/models/operator_chronicle_event.rb#L12); [ClientChronicleLevel](../../../app/models/client_chronicle_level.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07290"></a>T-07290 / [48](../../../test/models/database_pk_type_test.rb#L48) | "models with code column use citext"<br>Owner: `DatabasePkTypeTest` | `assert true, "No models with code column found (migrated to fixed IDs)"`; `models.each { \|model\| assert_code_is_citext(model) }` | [OperatorTokenKind](../../../app/models/operator_token_kind.rb#L12); [OperatorTokenStatus](../../../app/models/operator_token_status.rb#L12) | [LV-008](../findings.md#lv-008) confirmed | literal-pass |

## `test/models/dead_identifier_destroy_test.rb`

[test/models/dead_identifier_destroy_test.rb](../../../test/models/dead_identifier_destroy_test.rb); SHA-256: `77af29613a984efa2836b89a7838da2d486c1a4f323a6dc74aff8a940c2169cc`.

File-level implementation candidates (including setup/import context): [app/models/client_email.rb:44](../../../app/models/client_email.rb#L44); [app/models/client_email_history.rb:3](../../../app/models/client_email_history.rb#L3); [app/models/visitor_email.rb:43](../../../app/models/visitor_email.rb#L43); [app/models/visitor_email_history.rb:3](../../../app/models/visitor_email_history.rb#L3); [app/models/operator_email.rb:38](../../../app/models/operator_email.rb#L38).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07291"></a>T-07291 / [7](../../../test/models/dead_identifier_destroy_test.rb#L7) | "#{realm} physical email destruction atomically archives the database identifier rather than unsaved PII"<br>Owner: `DeadIdentifierDestroyTest` | `assert_equal count + 1, history_model.count`; `assert_not model.exists?(record.id)`; `assert history.matches_identifier?(address)`; +1 further assertion lines | [ClientEmail](../../../app/models/client_email.rb#L44); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07292"></a>T-07292 / [37](../../../test/models/dead_identifier_destroy_test.rb#L37) | "#{realm} telephone destruction atomically archives database PII rather than unsaved PII"<br>Owner: `DeadIdentifierDestroyTest` | `assert_equal count + 1, history_model.count`; `assert_not model.exists?(record.id)`; `assert history.matches_identifier?(number)`; +1 further assertion lines | [ClientTelephone](../../../app/models/client_telephone.rb#L37); [ClientTelephoneHistory](../../../app/models/client_telephone_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07293"></a>T-07293 / [70](../../../test/models/dead_identifier_destroy_test.rb#L70) | "#{realm} ordinary identifier removal bypasses dead history explicitly"<br>Owner: `DeadIdentifierDestroyTest` | `assert_not model.exists?(record.id)`; `assert_equal count, history_model.count` | [ClientEmail](../../../app/models/client_email.rb#L44); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07294"></a>T-07294 / [92](../../../test/models/dead_identifier_destroy_test.rb#L92) | "#{realm} ordinary telephone removal bypasses dead history explicitly"<br>Owner: `DeadIdentifierDestroyTest` | `assert_not model.exists?(record.id)`; `assert_equal count, history_model.count` | [ClientTelephone](../../../app/models/client_telephone.rb#L37); [ClientTelephoneHistory](../../../app/models/client_telephone_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07295"></a>T-07295 / [115](../../../test/models/dead_identifier_destroy_test.rb#L115) | "unmarked irreversible destruction refuses to create dead history"<br>Owner: `DeadIdentifierDestroyTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { record.destroy! }`; `assert ClientEmail.exists?(record.id)`; `assert_equal count, ClientEmailHistory.count` | [ClientEmail](../../../app/models/client_email.rb#L44); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07296"></a>T-07296 / [127](../../../test/models/dead_identifier_destroy_test.rb#L127) | "a live owner's legal hold refuses ordinary email and telephone destruction without histories"<br>Owner: `DeadIdentifierDestroyTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }`; `assert_raises(ActiveRecord::RecordNotDestroyed) { telephone.destroy! }`; `assert_equal email_count, ClientEmailHistory.count`; +3 further assertion lines | [ClientRetentionHold](../../../app/models/client_retention_hold.rb#L4); [ClientEmail](../../../app/models/client_email.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07297"></a>T-07297 / [145](../../../test/models/dead_identifier_destroy_test.rb#L145) | "a later email destruction refusal rolls back the archive insertion and exposes no receipt"<br>Owner: `DeadIdentifierDestroyTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }`; `assert_equal count, ClientEmailHistory.count`; `assert ClientEmail.exists?(email.id)`; +1 further assertion lines | [ClientEmail](../../../app/models/client_email.rb#L44); [ClientEmailHistory](../../../app/models/client_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07298"></a>T-07298 / [159](../../../test/models/dead_identifier_destroy_test.rb#L159) | "#{realm} recoverable email and telephone cannot bypass retention through ordinary destruction"<br>Owner: `DeadIdentifierDestroyTest` | `assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }`; `assert_raises(ActiveRecord::RecordNotDestroyed) { telephone.destroy! }`; `assert_equal email_count, email_history.count`; +3 further assertion lines | [ClientEmail](../../../app/models/client_email.rb#L44); [ClientTelephone](../../../app/models/client_telephone.rb#L37) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/dead_identifier_history_contract_test.rb`

[test/models/dead_identifier_history_contract_test.rb](../../../test/models/dead_identifier_history_contract_test.rb); SHA-256: `230aa6843901aa0c60e6c9a42298b468fced247d4b584575d82fdd31408d956e`.

File-level implementation candidates (including setup/import context): [app/models/client_email_history.rb:3](../../../app/models/client_email_history.rb#L3); [app/models/visitor_email_history.rb:3](../../../app/models/visitor_email_history.rb#L3); [app/models/operator_email_history.rb:3](../../../app/models/operator_email_history.rb#L3); [app/models/client_telephone_history.rb:3](../../../app/models/client_telephone_history.rb#L3); [app/models/visitor_telephone_history.rb:3](../../../app/models/visitor_telephone_history.rb#L3).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07299"></a>T-07299 / [6](../../../test/models/dead_identifier_history_contract_test.rb#L6) | "each email history contains only identity fingerprint and lifecycle facts"<br>Owner: `DeadIdentifierHistoryContractTest` | `assert_equal %W(id #{owner_key} fingerprint attached_at detached_at created_at).sort, model.column_names.sort`; `assert_not model.connection.indexes(model.table_name).any? { \|index\| index.columns == ["fingerprint"] }`; `assert_not model.connection.indexes(model.table_name).any? { \|index\|` | [ClientEmailHistory](../../../app/models/client_email_history.rb#L3); [VisitorEmailHistory](../../../app/models/visitor_email_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07300"></a>T-07300 / [17](../../../test/models/dead_identifier_history_contract_test.rb#L17) | "each telephone history contains only identity fingerprint and lifecycle facts"<br>Owner: `DeadIdentifierHistoryContractTest` | `assert_equal %W(id #{owner_key} fingerprint attached_at detached_at created_at).sort, model.column_names.sort`; `assert_not model.connection.indexes(model.table_name).any? { \|index\| index.columns == ["fingerprint"] }`; `assert_not model.connection.indexes(model.table_name).any? { \|index\|` | [ClientTelephoneHistory](../../../app/models/client_telephone_history.rb#L3); [VisitorTelephoneHistory](../../../app/models/visitor_telephone_history.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/department_status_test.rb`

[test/models/department_status_test.rb](../../../test/models/department_status_test.rb); SHA-256: `14a839856c87afcfb1afda845bedab719a9ffc52353daf812b84781720db12a1`.

File-level implementation candidates (including setup/import context): [app/models/department_status.rb:12](../../../app/models/department_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07301"></a>T-07301 / [14](../../../test/models/department_status_test.rb#L14) | "class is defined"<br>Owner: `DepartmentStatusTest` | `assert_equal "DepartmentStatus", DepartmentStatus.name` | [DepartmentStatus](../../../app/models/department_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/department_test.rb`

[test/models/department_test.rb](../../../test/models/department_test.rb); SHA-256: `b6c602cadda232ccfeb183a9899c89a08a021590f993df3653dd2ef0c2ea6494`.

File-level implementation candidates (including setup/import context): [app/models/department.rb:30](../../../app/models/department.rb#L30); [app/models/department_status.rb:12](../../../app/models/department_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07302"></a>T-07302 / [40](../../../test/models/department_test.rb#L40) | "should be valid"<br>Owner: `DepartmentTest` | `assert_predicate department, :valid?, department.errors.full_messages.to_sentence` | [Department](../../../app/models/department.rb#L30); [DepartmentStatus](../../../app/models/department_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07303"></a>T-07303 / [50](../../../test/models/department_test.rb#L50) | "requires name"<br>Owner: `DepartmentTest` | `assert_not department.valid?`; `assert_includes department.errors[:name], "を入力してください"` | [Department](../../../app/models/department.rb#L30); [DepartmentStatus](../../../app/models/department_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07304"></a>T-07304 / [57](../../../test/models/department_test.rb#L57) | "links parent and children"<br>Owner: `DepartmentTest` | `assert_equal parent, child.parent`; `assert_includes parent.children, child` | [Department](../../../app/models/department.rb#L30); [DepartmentStatus](../../../app/models/department_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07305"></a>T-07305 / [74](../../../test/models/department_test.rb#L74) | "validates status uniqueness within the same parent"<br>Owner: `DepartmentTest` | `assert_equal :parent_id, validator.options[:scope]` | [Department](../../../app/models/department.rb#L30) | S: static inventory; individual semantic review open | metadata-oracle |

## `test/models/division_status_test.rb`

[test/models/division_status_test.rb](../../../test/models/division_status_test.rb); SHA-256: `6109539ea3069fbecc6a387d7b067c2c9887c4d03bd9efbe468ac73a2f69a714`.

File-level implementation candidates (including setup/import context): [app/models/division_status.rb:11](../../../app/models/division_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07306"></a>T-07306 / [19](../../../test/models/division_status_test.rb#L19) | "accepts integer ids"<br>Owner: `DivisionStatusTest` | `assert_predicate record, :valid?` | [DivisionStatus](../../../app/models/division_status.rb#L11) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07307"></a>T-07307 / [25](../../../test/models/division_status_test.rb#L25) | "constants are defined"<br>Owner: `DivisionStatusTest` | `assert_equal 1, DivisionStatus::NOTHING`; `assert_equal 2, DivisionStatus::ACTIVE`; `assert_equal 3, DivisionStatus::INACTIVE`; +1 further assertion lines | [DivisionStatus](../../../app/models/division_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/division_test.rb`

[test/models/division_test.rb](../../../test/models/division_test.rb); SHA-256: `7b2df18ad187ebc30d7aaab9bf808fd2fafdb06b4e185a5b0da75b7a80de213f`.

File-level implementation candidates (including setup/import context): [app/models/division.rb:27](../../../app/models/division.rb#L27); [app/models/concerns/organization.rb:8](../../../app/models/concerns/organization.rb#L8).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07308"></a>T-07308 / [32](../../../test/models/division_test.rb#L32) | "class is defined"<br>Owner: `DivisionTest` | `assert_equal "Division", Division.name` | [Division](../../../app/models/division.rb#L27) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07309"></a>T-07309 / [36](../../../test/models/division_test.rb#L36) | "fixture is valid"<br>Owner: `DivisionTest` | `assert_predicate divisions(:one), :valid?` | [Division](../../../app/models/division.rb#L27); [Organization](../../../app/models/concerns/organization.rb#L8) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07310"></a>T-07310 / [40](../../../test/models/division_test.rb#L40) | "organization is required"<br>Owner: `DivisionTest` | `assert_not_predicate division, :valid?`; `assert_not_empty division.errors[:organization]` | [Division](../../../app/models/division.rb#L27); [Organization](../../../app/models/concerns/organization.rb#L8) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07311"></a>T-07311 / [47](../../../test/models/division_test.rb#L47) | "organization with divisions cannot be destroyed"<br>Owner: `DivisionTest` | `assert_not organization.destroy`; `assert_not_empty organization.errors[:base]` | [Division](../../../app/models/division.rb#L27); [Organization](../../../app/models/concerns/organization.rb#L8) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_client_occurrence_test.rb`

[test/models/domain_client_occurrence_test.rb](../../../test/models/domain_client_occurrence_test.rb); SHA-256: `851832b3880c47a50ad7069063577a934be09e00af08f26aa0b4827f6aab11a2`.

File-level implementation candidates (including setup/import context): [app/models/client_occurrence.rb:34](../../../app/models/client_occurrence.rb#L34); [app/models/domain_client_occurrence.rb:26](../../../app/models/domain_client_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07312"></a>T-07312 / [31](../../../test/models/domain_client_occurrence_test.rb#L31) | "associations"<br>Owner: `DomainClientOccurrenceTest` | `assert record.save!`; `assert_equal domain, record.domain_occurrence`; `assert_equal user, record.user_occurrence` | [ClientOccurrence](../../../app/models/client_occurrence.rb#L34); [DomainClientOccurrence](../../../app/models/domain_client_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07313"></a>T-07313 / [44](../../../test/models/domain_client_occurrence_test.rb#L44) | "uniqueness validation"<br>Owner: `DomainClientOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:domain_occurrence_id]` | [ClientOccurrence](../../../app/models/client_occurrence.rb#L34); [DomainClientOccurrence](../../../app/models/domain_client_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_email_occurrence_test.rb`

[test/models/domain_email_occurrence_test.rb](../../../test/models/domain_email_occurrence_test.rb); SHA-256: `43d60081b6bd419028357b320b9ef486f79496955f0f740cdc82e7fb43d38770`.

File-level implementation candidates (including setup/import context): [app/models/email_occurrence.rb:32](../../../app/models/email_occurrence.rb#L32); [app/models/domain_email_occurrence.rb:26](../../../app/models/domain_email_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07314"></a>T-07314 / [31](../../../test/models/domain_email_occurrence_test.rb#L31) | "associations"<br>Owner: `DomainEmailOccurrenceTest` | `assert record.save!`; `assert_equal domain, record.domain_occurrence`; `assert_equal email, record.email_occurrence` | [EmailOccurrence](../../../app/models/email_occurrence.rb#L32); [DomainEmailOccurrence](../../../app/models/domain_email_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07315"></a>T-07315 / [44](../../../test/models/domain_email_occurrence_test.rb#L44) | "uniqueness validation"<br>Owner: `DomainEmailOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:domain_occurrence_id]` | [EmailOccurrence](../../../app/models/email_occurrence.rb#L32); [DomainEmailOccurrence](../../../app/models/domain_email_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_ip_occurrence_test.rb`

[test/models/domain_ip_occurrence_test.rb](../../../test/models/domain_ip_occurrence_test.rb); SHA-256: `2b1b861ca5e59b25ebb29d9fc46b9acda1b70cf24cb85cc00bbbda1cb91f0075`.

File-level implementation candidates (including setup/import context): [app/models/domain_ip_occurrence.rb:26](../../../app/models/domain_ip_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07316"></a>T-07316 / [29](../../../test/models/domain_ip_occurrence_test.rb#L29) | "class is defined"<br>Owner: `DomainIpOccurrenceTest` | `assert_equal "DomainIpOccurrence", DomainIpOccurrence.name` | [DomainIpOccurrence](../../../app/models/domain_ip_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_occurrence_status_test.rb`

[test/models/domain_occurrence_status_test.rb](../../../test/models/domain_occurrence_status_test.rb); SHA-256: `f40b5f00ba4141c07702538cde1894fbc695e0b1cfbd47f7fa4f9472da013902`.

File-level implementation candidates (including setup/import context): [app/models/domain_occurrence_status.rb:12](../../../app/models/domain_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07317"></a>T-07317 / [15](../../../test/models/domain_occurrence_status_test.rb#L15) | "can load nothing status from db"<br>Owner: `DomainOccurrenceStatusTest` | `assert_not_nil nothing`; `assert_equal 0, nothing.id` | [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07318"></a>T-07318 / [22](../../../test/models/domain_occurrence_status_test.rb#L22) | "accepts integer ids"<br>Owner: `DomainOccurrenceStatusTest` | `assert_predicate record, :valid?` | [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07319"></a>T-07319 / [28](../../../test/models/domain_occurrence_status_test.rb#L28) | "constants are defined"<br>Owner: `DomainOccurrenceStatusTest` | `assert_equal 1, DomainOccurrenceStatus::ACTIVE`; `assert_equal 2, DomainOccurrenceStatus::DELETED`; `assert_equal 3, DomainOccurrenceStatus::INACTIVE`; +2 further assertion lines | [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07320"></a>T-07320 / [36](../../../test/models/domain_occurrence_status_test.rb#L36) | "has occurrences association"<br>Owner: `DomainOccurrenceStatusTest` | `assert_status_association(DomainOccurrenceStatus, :domain_occurrences)` | [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07321"></a>T-07321 / [40](../../../test/models/domain_occurrence_status_test.rb#L40) | "ensure_defaults! creates default records"<br>Owner: `DomainOccurrenceStatusTest` | `assert DomainOccurrenceStatus.exists?(id), "missing default domain occurrence status #{id}"` | [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_occurrence_test.rb`

[test/models/domain_occurrence_test.rb](../../../test/models/domain_occurrence_test.rb); SHA-256: `15a91a81dd57a7532ca41ddeef7b157c39a1a79b82e5eca6e56ca5cde51b081c`.

File-level implementation candidates (including setup/import context): [app/models/domain_occurrence.rb:31](../../../app/models/domain_occurrence.rb#L31); [app/models/domain_occurrence_status.rb:12](../../../app/models/domain_occurrence_status.rb#L12).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07322"></a>T-07322 / [37](../../../test/models/domain_occurrence_test.rb#L37) | "defaults status_id to nothing"<br>Owner: `DomainOccurrenceTest` | `assert_equal DomainOccurrenceStatus::NOTHING, record.status_id` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31); [DomainOccurrenceStatus](../../../app/models/domain_occurrence_status.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07323"></a>T-07323 / [43](../../../test/models/domain_occurrence_test.rb#L43) | "public_id length"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07324"></a>T-07324 / [49](../../../test/models/domain_occurrence_test.rb#L49) | "public_id format"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07325"></a>T-07325 / [55](../../../test/models/domain_occurrence_test.rb#L55) | "public_id uniqueness"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :public_id)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07326"></a>T-07326 / [62](../../../test/models/domain_occurrence_test.rb#L62) | "body presence"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :body)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07327"></a>T-07327 / [68](../../../test/models/domain_occurrence_test.rb#L68) | "body uniqueness"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :body)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07328"></a>T-07328 / [75](../../../test/models/domain_occurrence_test.rb#L75) | "status_id presence"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :status_id)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07329"></a>T-07329 / [81](../../../test/models/domain_occurrence_test.rb#L81) | "memo length"<br>Owner: `DomainOccurrenceTest` | `assert_invalid_attribute(record, :memo)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07330"></a>T-07330 / [87](../../../test/models/domain_occurrence_test.rb#L87) | "public_id auto generated on create"<br>Owner: `DomainOccurrenceTest` | `assert_public_id_generated(record)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07331"></a>T-07331 / [93](../../../test/models/domain_occurrence_test.rb#L93) | "public_id preserved when provided"<br>Owner: `DomainOccurrenceTest` | `assert_public_id_preserved(record, custom_public_id)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07332"></a>T-07332 / [100](../../../test/models/domain_occurrence_test.rb#L100) | "lifecycle timestamps default"<br>Owner: `DomainOccurrenceTest` | `assert_occurrence_lifecycle_defaults(record)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07333"></a>T-07333 / [105](../../../test/models/domain_occurrence_test.rb#L105) | "public_id is a fixed 21-character NanoID"<br>Owner: `DomainOccurrenceTest` | `assert_public_id_fixed_length(::DomainOccurrence)` | [DomainOccurrence](../../../app/models/domain_occurrence.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_staff_occurrence_test.rb`

[test/models/domain_staff_occurrence_test.rb](../../../test/models/domain_staff_occurrence_test.rb); SHA-256: `2cb91451517a0c6d9ecc406d2ecc37530ff97c4c86e67f14ea45f7509130b67e`.

File-level implementation candidates (including setup/import context): [app/models/operator_occurrence.rb:34](../../../app/models/operator_occurrence.rb#L34); [app/models/domain_operator_occurrence.rb:26](../../../app/models/domain_operator_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07334"></a>T-07334 / [31](../../../test/models/domain_staff_occurrence_test.rb#L31) | "associations"<br>Owner: `DomainOperatorOccurrenceTest` | `assert record.save!`; `assert_equal domain, record.domain_occurrence`; `assert_equal staff, record.staff_occurrence` | [OperatorOccurrence](../../../app/models/operator_occurrence.rb#L34); [DomainOperatorOccurrence](../../../app/models/domain_operator_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07335"></a>T-07335 / [44](../../../test/models/domain_staff_occurrence_test.rb#L44) | "uniqueness validation"<br>Owner: `DomainOperatorOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:domain_occurrence_id]` | [OperatorOccurrence](../../../app/models/operator_occurrence.rb#L34); [DomainOperatorOccurrence](../../../app/models/domain_operator_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_telephone_occurrence_test.rb`

[test/models/domain_telephone_occurrence_test.rb](../../../test/models/domain_telephone_occurrence_test.rb); SHA-256: `1ad71f82bab9fbe2023f15a5addc72bcc896e15a3a8a1c1e49bc96de51f75ce8`.

File-level implementation candidates (including setup/import context): [app/models/domain_telephone_occurrence.rb:26](../../../app/models/domain_telephone_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07336"></a>T-07336 / [31](../../../test/models/domain_telephone_occurrence_test.rb#L31) | "associations"<br>Owner: `DomainTelephoneOccurrenceTest` | `assert record.save!`; `assert_equal domain_occurrences(:one), record.domain_occurrence`; `assert_equal telephone_occurrences(:one), record.telephone_occurrence` | [DomainTelephoneOccurrence](../../../app/models/domain_telephone_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07337"></a>T-07337 / [42](../../../test/models/domain_telephone_occurrence_test.rb#L42) | "uniqueness validation"<br>Owner: `DomainTelephoneOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:domain_occurrence_id]` | [DomainTelephoneOccurrence](../../../app/models/domain_telephone_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/domain_zip_occurrence_test.rb`

[test/models/domain_zip_occurrence_test.rb](../../../test/models/domain_zip_occurrence_test.rb); SHA-256: `16f37cd87219965776041f276368f03a4cc9f278ec54eac6b68d895206e8897c`.

File-level implementation candidates (including setup/import context): [app/models/domain_zip_occurrence.rb:26](../../../app/models/domain_zip_occurrence.rb#L26).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07338"></a>T-07338 / [31](../../../test/models/domain_zip_occurrence_test.rb#L31) | "associations"<br>Owner: `DomainZipOccurrenceTest` | `assert record.save!`; `assert_equal domain_occurrences(:one), record.domain_occurrence`; `assert_equal zip_occurrences(:one), record.zip_occurrence` | [DomainZipOccurrence](../../../app/models/domain_zip_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07339"></a>T-07339 / [42](../../../test/models/domain_zip_occurrence_test.rb#L42) | "uniqueness validation"<br>Owner: `DomainZipOccurrenceTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:domain_occurrence_id]` | [DomainZipOccurrence](../../../app/models/domain_zip_occurrence.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
