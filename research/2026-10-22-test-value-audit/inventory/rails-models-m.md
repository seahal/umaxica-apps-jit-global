# rails-models-m: per-definition ledger

42 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/member_avatar_access_test.rb`

[test/models/member_avatar_access_test.rb](../../../test/models/member_avatar_access_test.rb); SHA-256: `2d6b94550127318092220b050f3327f9b98928885078a8dd62f461d6fd30612c`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_access.rb:25](../../../app/models/member_avatar_access.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07553"></a>T-07553 / [28](../../../test/models/member_avatar_access_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarAccessTest` | `assert_equal "MemberAvatarAccess", MemberAvatarAccess.name` | [MemberAvatarAccess](../../../app/models/member_avatar_access.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_deletion_test.rb`

[test/models/member_avatar_deletion_test.rb](../../../test/models/member_avatar_deletion_test.rb); SHA-256: `8bf9c19a378cc8e64cf79afbee47b791ea1b3997e403fe98a9239effb1b34ad9`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_deletion.rb:25](../../../app/models/member_avatar_deletion.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07554"></a>T-07554 / [28](../../../test/models/member_avatar_deletion_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarDeletionTest` | `assert_equal "MemberAvatarDeletion", MemberAvatarDeletion.name` | [MemberAvatarDeletion](../../../app/models/member_avatar_deletion.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_extraction_test.rb`

[test/models/member_avatar_extraction_test.rb](../../../test/models/member_avatar_extraction_test.rb); SHA-256: `b8165f036b1f067f19cba68e6e2d8142a3cc1156d12ec48ec4948a8cf38ae420`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_extraction.rb:25](../../../app/models/member_avatar_extraction.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07555"></a>T-07555 / [28](../../../test/models/member_avatar_extraction_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarExtractionTest` | `assert_equal "MemberAvatarExtraction", MemberAvatarExtraction.name` | [MemberAvatarExtraction](../../../app/models/member_avatar_extraction.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_impersonation_test.rb`

[test/models/member_avatar_impersonation_test.rb](../../../test/models/member_avatar_impersonation_test.rb); SHA-256: `61e11d069a6da29e133d7a5552f70c038bd93afde008755338f7ca86f22475ac`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_impersonation.rb:25](../../../app/models/member_avatar_impersonation.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07556"></a>T-07556 / [28](../../../test/models/member_avatar_impersonation_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarImpersonationTest` | `assert_equal "MemberAvatarImpersonation", MemberAvatarImpersonation.name` | [MemberAvatarImpersonation](../../../app/models/member_avatar_impersonation.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_oversight_test.rb`

[test/models/member_avatar_oversight_test.rb](../../../test/models/member_avatar_oversight_test.rb); SHA-256: `3737f5db2d811316a8adf4335701b7125a0ea1593b1ec7ab6de6a243f3688c67`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_oversight.rb:25](../../../app/models/member_avatar_oversight.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07557"></a>T-07557 / [28](../../../test/models/member_avatar_oversight_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarOversightTest` | `assert_equal "MemberAvatarOversight", MemberAvatarOversight.name` | [MemberAvatarOversight](../../../app/models/member_avatar_oversight.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_suspension_test.rb`

[test/models/member_avatar_suspension_test.rb](../../../test/models/member_avatar_suspension_test.rb); SHA-256: `6fe0f6218e1bab272fbb47049461fde76123e143e364af675625b8f68f3bb490`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_suspension.rb:25](../../../app/models/member_avatar_suspension.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07558"></a>T-07558 / [28](../../../test/models/member_avatar_suspension_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarSuspensionTest` | `assert_equal "MemberAvatarSuspension", MemberAvatarSuspension.name` | [MemberAvatarSuspension](../../../app/models/member_avatar_suspension.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_avatar_visibility_test.rb`

[test/models/member_avatar_visibility_test.rb](../../../test/models/member_avatar_visibility_test.rb); SHA-256: `9ad871440b8893c6743189e6daaefd4cc5d3e5a001431e82fd76705677670f3e`.

File-level implementation candidates (including setup/import context): [app/models/member_avatar_visibility.rb:25](../../../app/models/member_avatar_visibility.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07559"></a>T-07559 / [28](../../../test/models/member_avatar_visibility_test.rb#L28) | "class is defined"<br>Owner: `MemberAvatarVisibilityTest` | `assert_equal "MemberAvatarVisibility", MemberAvatarVisibility.name` | [MemberAvatarVisibility](../../../app/models/member_avatar_visibility.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_notification_test.rb`

[test/models/member_notification_test.rb](../../../test/models/member_notification_test.rb); SHA-256: `f2ac9b40b0aa2eab61cfde51fa3570abba8f8e11822782001bb7d772b713a826`.

File-level implementation candidates (including setup/import context): [app/models/member_notification.rb:25](../../../app/models/member_notification.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07560"></a>T-07560 / [6](../../../test/models/member_notification_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `MemberNotificationTest` | `assert_public_id_fixed_length(::MemberNotification)` | [MemberNotification](../../../app/models/member_notification.rb#L25) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_public_id_uniqueness_test.rb`

[test/models/member_public_id_uniqueness_test.rb](../../../test/models/member_public_id_uniqueness_test.rb); SHA-256: `60d7621af545749506acb52c18d848317b25afdae6bccb9310ce64683a353d73`.

File-level implementation candidates (including setup/import context): [app/models/member.rb:34](../../../app/models/member.rb#L34).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07561"></a>T-07561 / [6](../../../test/models/member_public_id_uniqueness_test.rb#L6) | "member IDs remain globally unique in the DB across different owners"<br>Owner: `MemberPublicIdUniquenessTest` | `assert_equal "member-contract-first", first.reload.public_id`; `assert_equal "member-contract-second", second.reload.public_id`; `assert_raises(ActiveRecord::RecordNotUnique) do`; +2 further assertion lines | [Member](../../../app/models/member.rb#L34) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07562"></a>T-07562 / [27](../../../test/models/member_public_id_uniqueness_test.rb#L27) | "member duplicate ID validation rejects another owner without modifying the original"<br>Owner: `MemberPublicIdUniquenessTest` | `assert_not candidate.valid?`; `assert candidate.errors.of_kind?(:public_id, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }`; +2 further assertion lines | [Member](../../../app/models/member.rb#L34) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_status_test.rb`

[test/models/member_status_test.rb](../../../test/models/member_status_test.rb); SHA-256: `827e24a5aafb41dd2e7ef7fa5bf592e4f7ef64d4571b716fa1430c9a6bf26e10`.

File-level implementation candidates (including setup/import context): [app/models/member_status.rb:13](../../../app/models/member_status.rb#L13).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07563"></a>T-07563 / [16](../../../test/models/member_status_test.rb#L16) | "has correct constant values"<br>Owner: `MemberStatusTest` | `assert_equal 1, MemberStatus::ACTIVE`; `assert_equal 2, MemberStatus::INACTIVE`; `assert_equal 3, MemberStatus::PENDING`; +2 further assertion lines | [MemberStatus](../../../app/models/member_status.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/member_test.rb`

[test/models/member_test.rb](../../../test/models/member_test.rb); SHA-256: `ee44c2068f6ee0e7df836945196fdb48a6dd32435ea22187bd00956ceb88ec17`.

File-level implementation candidates (including setup/import context): [app/models/member.rb:34](../../../app/models/member.rb#L34).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07564"></a>T-07564 / [37](../../../test/models/member_test.rb#L37) | "class is defined"<br>Owner: `MemberTest` | `assert_equal "Member", Member.name` | [Member](../../../app/models/member.rb#L34) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/model_load_test.rb`

[test/models/model_load_test.rb](../../../test/models/model_load_test.rb); SHA-256: `a889b8058aeda5fbca88f775eb089b278317c7c3fcf3cbb7240ae6b5a131193d`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07565"></a>T-07565 / [6](../../../test/models/model_load_test.rb#L6) | "all model files load successfully"<br>Owner: `ModelLoadTest` | `assert defined?(klass), "#{class_name} should be defined"` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/model_only_line_coverage_test.rb`

[test/models/model_only_line_coverage_test.rb](../../../test/models/model_only_line_coverage_test.rb); SHA-256: `c290547e998f543d1992d4d501215c613430d147f62ea901cd32676457176156`.

File-level implementation candidates (including setup/import context): [app/models/actor/configuration.rb:12](../../../app/models/actor/configuration.rb#L12); [app/models/actor/preference.rb:17](../../../app/models/actor/preference.rb#L17); [app/models/client_privacy_request.rb:4](../../../app/models/client_privacy_request.rb#L4); [app/models/app_preference.rb:49](../../../app/models/app_preference.rb#L49); [app/models/client_preference_adult_content_gate.rb:25](../../../app/models/client_preference_adult_content_gate.rb#L25).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07566"></a>T-07566 / [7](../../../test/models/model_only_line_coverage_test.rb#L7) | "actor configuration null values and dynamic access preserve value semantics"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_withheld { null_value.nil? }`; `assert_equal null_value, Actor::Configuration::NullValue.new`; `assert_respond_to null_value, :anything`; +6 further assertion lines | [Actor::Configuration](../../../app/models/actor/configuration.rb#L12) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07567"></a>T-07567 / [23](../../../test/models/model_only_line_coverage_test.rb#L23) | "actor preferences track explicit fields hashes and cookie input forms"<br>Owner: `ModelOnlyLineCoverageTest` | `assert preference.explicit?(:language)`; `assert_predicate preference, :language_explicit?`; `assert_equal preference, same`; +4 further assertion lines | [Actor::Preference](../../../app/models/actor/preference.rb#L17) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07568"></a>T-07568 / [52](../../../test/models/model_only_line_coverage_test.rb#L52) | "privacy request defaults scopes cancellation and legal hold are executable"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_not request.valid?`; `assert_equal "erasure", request.request_kind`; `assert_equal "self_service", request.request_source`; +7 further assertion lines | [ClientPrivacyRequest](../../../app/models/client_privacy_request.rb#L4) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07569"></a>T-07569 / [75](../../../test/models/model_only_line_coverage_test.rb#L75) | "retainable discard now validates duration and clamps to persisted creation"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_raises(ArgumentError) { record.discard_now!(purge_after: 10) }`; `assert_equal record.created_at, updates.last[:discard_at]`; `assert_operator updates.last[:purge_eligible_at], :&gt;, updates.last[:discard_at]` | [AppPreference](../../../app/models/app_preference.rb#L49) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07570"></a>T-07570 / [90](../../../test/models/model_only_line_coverage_test.rb#L90) | "preference value records apply their default option ids"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_predicate record.option_id, :present?, "#{model_class} should assign a default option"` | [ClientPreferenceAdultContentGate](../../../app/models/client_preference_adult_content_gate.rb#L25); [ClientPreferenceDateFormat](../../../app/models/client_preference_date_format.rb#L25) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07571"></a>T-07571 / [112](../../../test/models/model_only_line_coverage_test.rb#L112) | "preference reference records ensure their fixed defaults"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal model_class::DEFAULTS.sort, model_class.where(id: model_class::DEFAULTS).pluck(:id).sort` | [ClientPreferenceDateFormatOption](../../../app/models/client_preference_date_format_option.rb#L11); [ClientPreferenceDensityOption](../../../app/models/client_preference_density_option.rb#L11) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07572"></a>T-07572 / [133](../../../test/models/model_only_line_coverage_test.rb#L133) | "withdrawal occurrence records an allowlisted context for each supported surface"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal 1, created_attributes[:status_id]`; `assert_equal "requested", created_attributes[:event_type]`; `assert_equal "app", created_attributes[:context]["surface"]`; +5 further assertion lines | [Client](../../../app/models/client.rb#L76); [WithdrawalOccurrenceRecording](../../../app/models/concerns/withdrawal_occurrence_recording.rb#L4) | S: static inventory; individual semantic review open | redefined-subject-or-double, stubbed-boundary, coverage-named |
| <a id="t-07573"></a>T-07573 / [165](../../../test/models/model_only_line_coverage_test.rb#L165) | "session limit transaction creates finds and completes every remaining state"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_predicate record, :pending?`; `assert_equal record.id, ClientSessionLimitResolutionTransaction.find_active_by_challenge(issuance.challenge).id`; `assert_equal token.public_id, record.reload.selected_session_ref`; +5 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientStatus](../../../app/models/client_status.rb#L11) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07574"></a>T-07574 / [219](../../../test/models/model_only_line_coverage_test.rb#L219) | "oidc token usage scope and rotation update the refresh token family"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_kind_of ActiveRecord::Relation, OpAppGrant.currently_usable_at(Time.current)`; `assert_not_equal previous, rotated`; `assert_equal digest, usage.reload.previous_refresh_token_digest`; +3 further assertion lines | [OpAppGrant](../../../app/models/op_app_grant.rb#L4); [Client](../../../app/models/client.rb#L76) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07575"></a>T-07575 / [241](../../../test/models/model_only_line_coverage_test.rb#L241) | "avatar group and memberships expose state and timestamp validation"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_not group.active?`; `assert_not group.archived?`; `assert_not group.valid?`; +9 further assertion lines | [AvatarGroup](../../../app/models/avatar_group.rb#L4); [GroupAvatarMembership](../../../app/models/group_avatar_membership.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07576"></a>T-07576 / [271](../../../test/models/model_only_line_coverage_test.rb#L271) | "retention hold and processor notification defaults and transitions are complete"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_not hold.valid?`; `assert_equal "legal_hold", hold.hold_kind`; `assert_equal "legal_hold", hold.reason_code`; +10 further assertion lines | [ClientRetentionHold](../../../app/models/client_retention_hold.rb#L4); [ClientProcessorErasureNotification](../../../app/models/client_processor_erasure_notification.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07577"></a>T-07577 / [302](../../../test/models/model_only_line_coverage_test.rb#L302) | "dbsc model mappings and downgrade use each model's fixed reference classes"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal AppPreferenceBindingMethod, AppPreference.dbsc_binding_method_class`; `assert_equal AppPreferenceDbscStatus, AppPreference.dbsc_status_class`; `assert_equal ClientTokenBindingMethod, ClientToken.dbsc_binding_method_classes.fetch("ClientToken")`; +2 further assertion lines | [AppPreferenceBindingMethod](../../../app/models/app_preference_binding_method.rb#L11); [AppPreference](../../../app/models/app_preference.rb#L49) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07578"></a>T-07578 / [317](../../../test/models/model_only_line_coverage_test.rb#L317) | "mfa level compatibility reads both normalized and legacy attributes"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_not_predicate client, :mfa_level_enabled?`; `assert_not_predicate client, :mfa_level_required?`; `assert_predicate client, :mfa_level_enabled?`; +1 further assertion lines | [Client](../../../app/models/client.rb#L76); [ClientMfaLevel](../../../app/models/client_mfa_level.rb#L11) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07579"></a>T-07579 / [329](../../../test/models/model_only_line_coverage_test.rb#L329) | "sign in flow recognizes legacy states and advances to return"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_predicate flow, :sign_in_primary_pending?`; `assert_not_respond_to flow, :sign_in_dashboard_pending?`; `assert_not_respond_to flow, :sign_in_return_pending?`; +2 further assertion lines | [ClientSignInFlow](../../../app/models/client_sign_in_flow.rb#L44); [ClientSignInFlowState](../../../app/models/client_sign_in_flow_state.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07580"></a>T-07580 / [346](../../../test/models/model_only_line_coverage_test.rb#L346) | "step up purge scope and connection owners cover every store"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_kind_of ActiveRecord::Relation, ClientStepUpCeremonyTransaction.purgeable_at(now)`; `assert_equal OpBaseOrgRecord, OperatorStepUpCeremonyTransaction.connection_owner`; `assert_equal OpBaseComRecord, VisitorStepUpCeremonyTransaction.connection_owner` | [ClientStepUpCeremonyTransaction](../../../app/models/client_step_up_ceremony_transaction.rb#L49); [OpBaseOrgRecord](../../../app/models/op_base_org_record.rb#L6) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07581"></a>T-07581 / [354](../../../test/models/model_only_line_coverage_test.rb#L354) | "small public model APIs and reference defaults are covered by model tests"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal VisitorTokenBindingMethod::DEFAULTS.sort,`; `assert_predicate OperatorSecretCredential.generate_raw_secret_credential, :present?`; `assert_equal :operator, OperatorEmail.new.promotional_unsubscribe_scope`; +6 further assertion lines | [VisitorTokenBindingMethod](../../../app/models/visitor_token_binding_method.rb#L11); [ComPreferenceBindingMethod](../../../app/models/com_preference_binding_method.rb#L11) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07582"></a>T-07582 / [373](../../../test/models/model_only_line_coverage_test.rb#L373) | "email lookup and ceremony candidate validation cover valid and invalid shapes"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_kind_of ActiveRecord::Relation, VisitorEmail.with_address("visitor@example.test")`; `assert_kind_of ActiveRecord::Relation, VisitorEmail.with_address(nil)`; `assert_empty valid.errors.details[:auth_hash]`; +2 further assertion lines | [VisitorEmail](../../../app/models/visitor_email.rb#L43); [IdentitySocialCeremonyCandidate](../../../app/models/identity_social_ceremony_candidate.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07583"></a>T-07583 / [399](../../../test/models/model_only_line_coverage_test.rb#L399) | "signup and acme logout no-op predicates use their configured entry states"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_includes ClientSignUpFlow.social_entry_methods, "google"`; `assert_predicate flow, :social_entry_method?`; `assert_same failed, failed.fail!`; +1 further assertion lines | [ClientSignUpFlow](../../../app/models/client_sign_up_flow.rb#L59); [AcmeLogoutTransaction](../../../app/models/acme_logout_transaction.rb#L41) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07584"></a>T-07584 / [412](../../../test/models/model_only_line_coverage_test.rb#L412) | "model scopes and unlink predicate remain queryable"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_kind_of ActiveRecord::Relation, ClientWithdrawalFlow.active`; `assert_kind_of ActiveRecord::Relation, ClientSignInFlow.current`; `assert client.social_unlink_methods_remaining?(excluding_provider: "google")` | [ClientWithdrawalFlow](../../../app/models/client_withdrawal_flow.rb#L36); [ClientSignInFlow](../../../app/models/client_sign_in_flow.rb#L44) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07585"></a>T-07585 / [423](../../../test/models/model_only_line_coverage_test.rb#L423) | "withdrawal ceremony issue and expiration use the model boundary"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_same created, ClientWithdrawalCeremony.issue!(subject: subject)`; `assert_same subject, attributes[:client]`; `assert_predicate ceremony, :expired?` | [Client](../../../app/models/client.rb#L76); [ClientWithdrawalCeremony](../../../app/models/client_withdrawal_ceremony.rb#L4) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07586"></a>T-07586 / [446](../../../test/models/model_only_line_coverage_test.rb#L446) | "org preference chronicle defaults its actor to its subject"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_same preference, chronicle.actor` | [OrgPreference](../../../app/models/org_preference.rb#L49); [OrgPreferenceChronicle](../../../app/models/org_preference_chronicle.rb#L43) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07587"></a>T-07587 / [457](../../../test/models/model_only_line_coverage_test.rb#L457) | "acme logout failure records the failed transition"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal "failed", updates.last[:status]` | [AcmeLogoutTransaction](../../../app/models/acme_logout_transaction.rb#L41) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07588"></a>T-07588 / [467](../../../test/models/model_only_line_coverage_test.rb#L467) | "step up transaction exposes scopes claims and valid state transitions"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_equal %w(totp passkey), transaction.allowed_methods_array`; `assert_equal "model-coverage-step-up", transaction.grant_claims(now: now)["transaction_id"]`; `assert_not transaction.expired?(now: now)`; +5 further assertion lines | [ClientStepUpCeremonyTransaction](../../../app/models/client_step_up_ceremony_transaction.rb#L49) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07589"></a>T-07589 / [505](../../../test/models/model_only_line_coverage_test.rb#L505) | "step up cancellation scopes and validations reject invalid state"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_predicate transaction.reload, :canceled?`; `assert_includes ClientStepUpCeremonyTransaction.canceled, transaction`; `assert_not invalid.valid?`; +6 further assertion lines | [ClientStepUpCeremonyTransaction](../../../app/models/client_step_up_ceremony_transaction.rb#L49) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07590"></a>T-07590 / [540](../../../test/models/model_only_line_coverage_test.rb#L540) | "withdrawal ceremony defaults authenticate and state changes are deterministic"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_not ceremony.valid?`; `assert_equal "status", ceremony.purpose`; `assert_operator ceremony.expires_at, :&gt;, Time.current`; +9 further assertion lines | [ClientWithdrawalCeremony](../../../app/models/client_withdrawal_ceremony.rb#L4); [WithdrawalCeremonyRecordable](../../../app/models/concerns/withdrawal_ceremony_recordable.rb#L4) | S: static inventory; individual semantic review open | stubbed-boundary, coverage-named |
| <a id="t-07591"></a>T-07591 / [579](../../../test/models/model_only_line_coverage_test.rb#L579) | "withdrawal ceremony predicates cover expired consumed revoked and mismatched tokens"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_predicate ceremony, :expired?`; `assert_predicate ceremony, :consumed?`; `assert_predicate ceremony, :revoked?`; +3 further assertion lines | [ClientWithdrawalCeremony](../../../app/models/client_withdrawal_ceremony.rb#L4); [WithdrawalCeremonyRecordable](../../../app/models/concerns/withdrawal_ceremony_recordable.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-07592"></a>T-07592 / [597](../../../test/models/model_only_line_coverage_test.rb#L597) | "identity ceremony candidates reject missing consumed and expired records then consume active records"<br>Owner: `ModelOnlyLineCoverageTest` | `assert_raises(error_class) do`; `assert_raises(error_class) do`; `assert_raises(error_class) do`; +3 further assertion lines | [IdentitySocialCeremonyCandidate](../../../app/models/identity_social_ceremony_candidate.rb#L4) | S: static inventory; individual semantic review open | redefined-subject-or-double, stubbed-boundary, coverage-named |

## `test/models/model_table_fixture_consistency_test.rb`

[test/models/model_table_fixture_consistency_test.rb](../../../test/models/model_table_fixture_consistency_test.rb); SHA-256: `ce58c3fbede1fd64cde115e69b64b7099fc04d25d91549da77f56fef423b3728`.

File-level implementation candidates (including setup/import context): [app/models/client_persona.rb:11](../../../app/models/client_persona.rb#L11); [app/models/operator_organization.rb:12](../../../app/models/operator_organization.rb#L12); [app/models/app_identity_authentication_event.rb:4](../../../app/models/app_identity_authentication_event.rb#L4); [app/models/com_identity_authentication_event.rb:4](../../../app/models/com_identity_authentication_event.rb#L4); [app/models/org_identity_authentication_event.rb:4](../../../app/models/org_identity_authentication_event.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07593"></a>T-07593 / [55](../../../test/models/model_table_fixture_consistency_test.rb#L55) | "application record table names follow model tableize convention"<br>Owner: `ModelTableFixtureConsistencyTest` | `assert_empty mismatches.sort, "Model/table naming mismatches remain:\n#{mismatches.sort.join("\n")}"` | [ClientPersona](../../../app/models/client_persona.rb#L11); [OperatorOrganization](../../../app/models/operator_organization.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07594"></a>T-07594 / [68](../../../test/models/model_table_fixture_consistency_test.rb#L68) | "fixture file names map to active record table names"<br>Owner: `ModelTableFixtureConsistencyTest` | `assert_empty missing_tables.sort,` | [ClientPersona](../../../app/models/client_persona.rb#L11); [OperatorOrganization](../../../app/models/operator_organization.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
