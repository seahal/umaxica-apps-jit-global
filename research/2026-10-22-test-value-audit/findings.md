# Low-value and misleading-test findings

Snapshot findings only. No test or production file was edited. Each entry is a proposed disposition, not permission to remove coverage. P1 denotes misleading assurance at a material contract; P2 a weak or incomplete oracle; P3 redundant or misplaced maintenance. Priority is review order, not an exploit severity rating.

| Finding | Priority | Confidence | Source definitions | Subject |
| --- | --- | --- | --- | --- |
| [LV-001](#lv-001) | P1 | confirmed | 1 | The appeal test throws its own expected exception |
| [LV-002](#lv-002) | P1 | confirmed | 1 | The inactive avatar test can execute no graph operation |
| [LV-003](#lv-003) | P1 | confirmed | 1 | WebAuthn errors are swallowed and the oracle checks the test object |
| [LV-004](#lv-004) | P1 | confirmed | 1 | The auth controller sweep counts exceptions as successful exercises |
| [LV-005](#lv-005) | P1 | confirmed | 1 | Retention and refresh branches swallow failures without a behavior oracle |
| [LV-006](#lv-006) | P1 | confirmed | 1 | The health test falls back to a locally copied implementation |
| [LV-007](#lv-007) | P2 | confirmed | 1 | Publishing CRUD introspection skips missing actions |
| [LV-008](#lv-008) | P2 | confirmed | 1 | The retired code-column test succeeds when its subject disappears |
| [LV-009](#lv-009) | P2 | confirmed | 2 | Helper delegation tests require only absence of an exception |
| [LV-010](#lv-010) | P2 | confirmed | 1 | A module existence assertion does not exercise the audit writer |
| [LV-011](#lv-011) | P2 | candidate | 1 | The token discard test conditionally abandons its claimed contract |
| [LV-012](#lv-012) | P2 | confirmed | 2 | Seeded fixtures can satisfy the defaults assertion without an insert |
| [LV-013](#lv-013) | P3 | confirmed | 1 | Association metadata repeats a stronger association behavior check |
| [LV-014](#lv-014) | P3 | confirmed | 3 | The helper harness explicitly supplies the module it asserts is included |
| [LV-015](#lv-015) | P1 | confirmed | 1 | The refresh journey leaves the supposedly missing access cookie in its jar |
| [LV-016](#lv-016) | P2 | confirmed | 1 | A logout revocation claim asserts no record deletion instead of revocation |
| [LV-017](#lv-017) | P2 | confirmed | 5 | Preference mutation cases verify only dummy-endpoint success |
| [LV-018](#lv-018) | P2 | confirmed | 1 | The title sweep can pass with zero checked responses on a host |
| [LV-019](#lv-019) | P2 | confirmed | 1 | The route smoke sweep accepts routing misses as product success |
| [LV-020](#lv-020) | P2 | confirmed | 3 | Bootstrap tests do not observe the shared-import claim |
| [LV-021](#lv-021) | P3 | confirmed-policy-conflict | 6 | Flipper setup and vendor behavior tests are outside the environment-test policy |
| [LV-022](#lv-022) | P3 | confirmed-policy-conflict | 2 | Rack timeout tests validate initializer assignments rather than a timed request |
| [LV-023](#lv-023) | P3 | confirmed-policy-conflict | 2 | Prosopite tests exercise diagnostic-tool wiring outside production |
| [LV-024](#lv-024) | P3 | confirmed-policy-conflict | 6 | Compose assertions belong to observed environment construction evidence |
| [LV-025](#lv-025) | P3 | confirmed | 1 | A prose-heading assertion adds no deployed behavior evidence |
| [LV-026](#lv-026) | P3 | confirmed-policy-conflict | 1 | A future route-file existence test is a weak setup check |
| [LV-027](#lv-027) | P3 | candidate | 50 | Unsaved integer-ID validity is a repeated weak proxy for schema safety |
| [LV-028](#lv-028) | P2 | confirmed | 1 | The CSP intake registration test makes rate-limit registration a no-op |
| [LV-029](#lv-029) | P2 | confirmed | 1 | Conditional Apple action assertions disappear when an action disappears |
| [LV-030](#lv-030) | P1 | confirmed | 1 | The visitor scope case repeats the client partition |
| [LV-031](#lv-031) | P2 | confirmed-duplicate | 1 | The retired passkey-route absence is asserted twice |
| [LV-032](#lv-032) | P2 | confirmed-duplicate | 1 | The credential-ceremony claim repeats a non-404 smoke request |
| [LV-033](#lv-033) | P3 | confirmed-duplicate | 1 | Binding-method default-row idempotence is duplicated |
| [LV-034](#lv-034) | P3 | confirmed-duplicate | 1 | The invalid retention ordering partition is duplicated |
| [LV-035](#lv-035) | P3 | confirmed-duplicate | 1 | Operator language default-row idempotence is duplicated |
| [LV-036](#lv-036) | P3 | confirmed-duplicate | 1 | The same valid Operator identifier is presented as two techniques |
| [LV-037](#lv-037) | P3 | confirmed-duplicate | 1 | The same expired sign-in transition is tested twice |
| [LV-038](#lv-038) | P3 | confirmed-duplicate | 1 | The block-precedence claim repeats the same blocked-target setup |
| [LV-039](#lv-039) | P3 | confirmed-duplicate | 1 | Missing confidential-client authentication has duplicate scenarios |

<a id="lv-001"></a>
## LV-001: The appeal test throws its own expected exception

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** A missing appeal is refused by the routed owner without unauthorized mutation.

**Observed limitation.** Neither controller action is invoked. The test creates @enforcement_case, checks its test-defined appeal reader, then raises ActiveRecord::RecordNotFound itself inside assert_raises. The current Base controller only relays new/create to the owner; this is also a stale local-owner scenario. Replacing both real actions with raising methods in a temporary process left this test passing.

**Proposed action.** Replace with a real owner/request contract; retire this test after coverage is established.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/base/org/support/enforcement_cases/appeal_reviews_controller.rb](../../app/controllers/base/org/support/enforcement_cases/appeal_reviews_controller.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02385](inventory/rails-controllers-root.md#t-02385) | [test/controllers/branch_coverage_batch35_zero_files_test.rb:71](../../test/controllers/branch_coverage_batch35_zero_files_test.rb#L71) | "AppealReviewsController raises when appeal missing" |

<a id="lv-002"></a>
## LV-002: The inactive avatar test can execute no graph operation

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Inactive avatars cannot create follow/block/mute edges.

**Observed limitation.** The test discovers module singleton methods, but the real API consists of nested Follow, Block and Mute operation classes. It swallows unexpected exceptions and finishes with assert_kind_of Minitest::Test, self. No denial or absence of database mutation is required.

**Proposed action.** Replace with explicit nested public operations and inactive actor/target cases; keep self-edge cases separate.

**Replacement / safety condition.** test/services/branch_coverage_batch20_precise_services_test.rb:31 explicitly exercises inactive actor and target for Follow, Block and Mute; normal graph behavior remains in dedicated operation suites.

**Implementation and comparison sources.** [app/services/avatar_social_graph.rb](../../app/services/avatar_social_graph.rb), [test/services/avatar_social_graph/follow_test.rb](../../test/services/avatar_social_graph/follow_test.rb), [test/services/branch_coverage_batch20_precise_services_test.rb](../../test/services/branch_coverage_batch20_precise_services_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02796](inventory/rails-controllers-concerns.md#t-02796) | [test/controllers/concerns/branch_coverage_batch19_surgical_raises_test.rb:7](../../test/controllers/concerns/branch_coverage_batch19_surgical_raises_test.rb#L7) | "avatar social graph blocked when inactive" |

<a id="lv-003"></a>
## LV-003: WebAuthn errors are swallowed and the oracle checks the test object

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** WebAuthn option construction refuses unsupported or missing participants safely.

**Observed limitation.** Both options_for calls rescue every StandardError. The optional configuration call also rescues all errors. The final assertion is true regardless of outcomes. A changed signature, missing method or broken verifier does not make this test fail.

**Proposed action.** Replace with public verifier results or the precise expected refusal and no-state-change assertions.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/services/webauthn/assertion_verifier.rb](../../app/services/webauthn/assertion_verifier.rb), [app/services/webauthn/registration_verifier.rb](../../app/services/webauthn/registration_verifier.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02794](inventory/rails-controllers-concerns.md#t-02794) | [test/controllers/concerns/branch_coverage_batch15_more_auth_prefs_test.rb:7](../../test/controllers/concerns/branch_coverage_batch15_more_auth_prefs_test.rb#L7) | "webauthn verifiers and turnstile zeros" |

<a id="lv-004"></a>
## LV-004: The auth controller sweep counts exceptions as successful exercises

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Each admitted route refuses invalid state with the correct HTTP result and no mutation.

**Observed limitation.** deny_gates! overwrites guards and rendering, actions are called directly, unknown classes and actions are skipped, and both normal return and StandardError increment exercised. exercised > 5 proves only that attempts occurred. It does not distinguish denial from a crash.

**Proposed action.** Replace with named route requests and explicit denial/status/state contracts. Preserve independent surface coverage.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/auth/app/sign/in/emails_controller.rb](../../app/controllers/auth/app/sign/in/emails_controller.rb), [app/controllers/auth/com/sign/up/check/email/otps_controller.rb](../../app/controllers/auth/com/sign/up/check/email/otps_controller.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02792](inventory/rails-controllers-concerns.md#t-02792) | [test/controllers/concerns/branch_coverage_batch13_mass_guards_test.rb:68](../../test/controllers/concerns/branch_coverage_batch13_mass_guards_test.rb#L68) | "mass early-return gates across auth controllers" |

<a id="lv-005"></a>
## LV-005: Retention and refresh branches swallow failures without a behavior oracle

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Discard and refresh checks preserve token validity and retained state.

**Observed limitation.** Object construction and method calls are conditional or broadly rescued; the only final assertion checks the Minitest object type. Removing those production calls leaves the oracle unchanged.

**Proposed action.** Retire after identifying the specific missing public contract, or replace with persisted token lifecycle assertions.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/models/concerns/refresh_tokenable.rb](../../app/models/concerns/refresh_tokenable.rb), [app/models/concerns/retainable.rb](../../app/models/concerns/retainable.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02793](inventory/rails-controllers-concerns.md#t-02793) | [test/controllers/concerns/branch_coverage_batch13_mass_guards_test.rb:90](../../test/controllers/concerns/branch_coverage_batch13_mass_guards_test.rb#L90) | "retainable and refresh tokenable else arms" |

<a id="lv-006"></a>
## LV-006: The health test falls back to a locally copied implementation

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** A non-ok dependency exposes the public status failed without diagnostic details.

**Observed limitation.** The test calls DependencyResult.new(name:, ok:), whereas production requires kind: and status:. That ArgumentError is caught and the assertion runs against a test-local class. An in-memory mutation returning an incorrect public_status passed this case; the real HealthTest failed under the same mutation.

**Proposed action.** Consolidate into the existing real DependencyResult test; remove the local fallback.

**Replacement / safety condition.** test/services/health_test.rb:13 exercises the real constructor and detected the deliberate mutation in this session.

**Implementation and comparison sources.** [app/services/health.rb](../../app/services/health.rb), [test/services/health_test.rb](../../test/services/health_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-11296](inventory/rails-services-root.md#t-11296) | [test/services/branch_coverage_batch39_easy_misses_test.rb:44](../../test/services/branch_coverage_batch39_easy_misses_test.rb#L44) | "Health DependencyResult public_status failed arm" |

<a id="lv-007"></a>
## LV-007: Publishing CRUD introspection skips missing actions

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Publishing routes invoke the correct authorized CRUD operation.

**Observed limitation.** For each action, next unless method_defined? discards the failure it should expose. instance_method returns UnboundMethod by Ruby definition; no action body, route, policy or mutation is exercised. Removing an action can reduce assertions while retaining green.

**Proposed action.** Use request contracts, or a finite route/action existence contract that fails when an expected action is absent.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/edit/org/publishing/docs/app/entries_controller.rb](../../app/controllers/edit/org/publishing/docs/app/entries_controller.rb), [app/controllers/edit/org/publishing/news/app/entries_controller.rb](../../app/controllers/edit/org/publishing/news/app/entries_controller.rb), [app/controllers/edit/org/publishing/info/app/entries_controller.rb](../../app/controllers/edit/org/publishing/info/app/entries_controller.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-11299](inventory/rails-services-root.md#t-11299) | [test/services/branch_coverage_batch39_easy_misses_test.rb:89](../../test/services/branch_coverage_batch39_easy_misses_test.rb#L89) | "Edit Publishing entries controllers respond to CRUD verbs for method coverage" |

<a id="lv-008"></a>
## LV-008: The retired code-column test succeeds when its subject disappears

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Reference columns have the required persisted identifier shape.

**Observed limitation.** The four selected token kind/status tables have id-only definitions in the checked structure SQL. The test filters to models with code; an empty set reaches assert true and returns. Thus absence of the former schema is accepted as a success of the old citext claim.

**Proposed action.** Retire the obsolete code-column claim; preserve meaningful bigint/FK constraints separately.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [db/op_base_app_structure.sql](../../db/op_base_app_structure.sql), [db/op_base_org_structure.sql](../../db/op_base_org_structure.sql).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-07290](inventory/rails-models-d.md#t-07290) | [test/models/database_pk_type_test.rb:48](../../test/models/database_pk_type_test.rb#L48) | "models with code column use citext" |

<a id="lv-009"></a>
## LV-009: Helper delegation tests require only absence of an exception

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** View helpers expose the correct actor and authorization predicates.

**Observed limitation.** The suite enumerates whatever methods exist and only asserts that each invocation does not raise. It never compares delegated results; removing every listed helper yields zero assertions in the loops.

**Proposed action.** Choose named externally used helper behavior and expected values, preferably via rendered/request behavior.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/edit/org/application_controller.rb](../../app/controllers/edit/org/application_controller.rb), [app/controllers/warp/app/application_controller.rb](../../app/controllers/warp/app/application_controller.rb), [app/controllers/warp/com/application_controller.rb](../../app/controllers/warp/com/application_controller.rb), [app/controllers/warp/org/application_controller.rb](../../app/controllers/warp/org/application_controller.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02389](inventory/rails-controllers-root.md#t-02389) | [test/controllers/branch_coverage_batch40_line_push_test.rb:10](../../test/controllers/branch_coverage_batch40_line_push_test.rb#L10) | "Edit::Org HelperMethods delegates execute when signed out" |
| [T-02390](inventory/rails-controllers-root.md#t-02390) | [test/controllers/branch_coverage_batch40_line_push_test.rb:26](../../test/controllers/branch_coverage_batch40_line_push_test.rb#L26) | "Warp application HelperMethods delegates execute" |

<a id="lv-010"></a>
## LV-010: A module existence assertion does not exercise the audit writer

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Authentication outcomes write the required authoritative audit records.

**Observed limitation.** The entire test is assert defined?(AuthenticationAuditWriter). An empty module with that name satisfies it; no event, actor, redaction or persistence contract is asserted.

**Proposed action.** Consolidate with audit emission behavior tests; use real success/failure event and record assertions.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/concerns/authentication_audit_writer.rb](../../app/controllers/concerns/authentication_audit_writer.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02795](inventory/rails-controllers-concerns.md#t-02795) | [test/controllers/concerns/branch_coverage_batch17_completions_and_emails_test.rb:7](../../test/controllers/concerns/branch_coverage_batch17_completions_and_emails_test.rb#L7) | "authentication audit writer skipped class include" |

<a id="lv-011"></a>
## LV-011: The token discard test conditionally abandons its claimed contract

Priority: **P2**. Confidence: **candidate**. Disposition: **open; no removal performed**.

**Intended protection.** A token at or after its discard deadline is unusable.

**Observed limitation.** The current ClientToken has discard_at and the assertion is useful on that branch. If the column disappears, the test substitutes a Minitest-object assertion. It also overlaps the first case in branch_coverage_batch2 and the substantial TokenStatusManagement suite. This is a repair/consolidation candidate, not an assertion that current production logic is untested.

**Proposed action.** Remove the success fallback; consolidate with before/at/after expiry cases, keeping surface-specific behavior.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/models/concerns/token_status_management.rb](../../app/models/concerns/token_status_management.rb), [test/controllers/concerns/branch_coverage_batch2_test.rb](../../test/controllers/concerns/branch_coverage_batch2_test.rb), [test/models/concerns/token_status_management_test.rb](../../test/models/concerns/token_status_management_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-11203](inventory/rails-services-root.md#t-11203) | [test/services/branch_coverage_batch26_depth_easy_arms_test.rb:9](../../test/services/branch_coverage_batch26_depth_easy_arms_test.rb#L9) | "TokenStatusManagement discarded arm" |

<a id="lv-012"></a>
## LV-012: Seeded fixtures can satisfy the defaults assertion without an insert

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** ensure_defaults! restores missing reference rows and tolerates repeat calls.

**Observed limitation.** IpOccurrenceStatus fixtures already contain every DEFAULTS id (0,1,2). Calling ensure_defaults! and checking existence cannot distinguish a no-op implementation. ReferenceRecordTest only requires no exception. ClientStatusTest and ClientChronicleLevelTest show stronger patterns that first remove an unused row and assert restoration.

**Proposed action.** Consolidate the generic insertion contract and retain concrete DEFAULTS/foreign-key contracts. Do not delete fixture or persistence data as part of this audit.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/models/ip_occurrence_status.rb](../../app/models/ip_occurrence_status.rb), [app/models/concerns/reference_record.rb](../../app/models/concerns/reference_record.rb), [test/fixtures/ip_occurrence_statuses.yml](../../test/fixtures/ip_occurrence_statuses.yml), [test/models/client_status_test.rb](../../test/models/client_status_test.rb), [test/models/client_chronicle_level_test.rb](../../test/models/client_chronicle_level_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-07499](inventory/rails-models-i.md#t-07499) | [test/models/ip_occurrence_status_test.rb:37](../../test/models/ip_occurrence_status_test.rb#L37) | "ensure_defaults! creates default records" |
| [T-07079](inventory/rails-models-concerns.md#t-07079) | [test/models/concerns/reference_record_test.rb:23](../../test/models/concerns/reference_record_test.rb#L23) | "ensure_defaults! inserts defaults" |

<a id="lv-013"></a>
## LV-013: Association metadata repeats a stronger association behavior check

Priority: **P3**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Token kinds find the correct tokens through the retained foreign key.

**Observed limitation.** The metadata assertion only checks the macro has_many. The same file already loads the relation with fixtures and checks both populated and empty partitions, which catches a missing or wrong association. The macro assertion adds little to that behavior and couples the suite to Rails declaration shape.

**Proposed action.** Consider removing only the metadata case after the relation case passes.

**Replacement / safety condition.** The relation case is at line 35. Destroy restriction and database restriction at lines 42 and 51 are distinct boundaries and must remain.

**Implementation and comparison sources.** [app/models/client_token_kind.rb](../../app/models/client_token_kind.rb), [test/models/client_token_kind_test.rb](../../test/models/client_token_kind_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-06603](inventory/rails-models-c.md#t-06603) | [test/models/client_token_kind_test.rb:31](../../test/models/client_token_kind_test.rb#L31) | "has many client_tokens" |

<a id="lv-014"></a>
## LV-014: The helper harness explicitly supplies the module it asserts is included

Priority: **P3**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Concrete surface controllers expose required audit behavior.

**Observed limitation.** Each test Harness explicitly includes AuthorizationAudit before including the authentication concern, then asserts AuthorizationAudit is included. The assertion cannot prove that the authentication concern or the concrete production host wires auditing correctly.

**Proposed action.** Replace with actual audit emission at concrete request boundaries or an explicitly owned integration contract.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/concerns/authentication_client.rb](../../app/controllers/concerns/authentication_client.rb), [app/controllers/concerns/authentication_operator.rb](../../app/controllers/concerns/authentication_operator.rb), [app/controllers/concerns/authentication_visitor.rb](../../app/controllers/concerns/authentication_visitor.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02588](inventory/rails-controllers-concerns.md#t-02588) | [test/controllers/concerns/authentication/client_included_do_test.rb:17](../../test/controllers/concerns/authentication/client_included_do_test.rb#L17) | "included do includes AuthorizationAudit module" |
| [T-02669](inventory/rails-controllers-concerns.md#t-02669) | [test/controllers/concerns/authentication/operator_included_do_test.rb:17](../../test/controllers/concerns/authentication/operator_included_do_test.rb#L17) | "included do includes AuthorizationAudit module" |
| [T-02745](inventory/rails-controllers-concerns.md#t-02745) | [test/controllers/concerns/authentication/visitor_included_do_test.rb:17](../../test/controllers/concerns/authentication/visitor_included_do_test.rb#L17) | "included do includes AuthorizationAudit module" |

<a id="lv-015"></a>
## LV-015: The refresh journey leaves the supposedly missing access cookie in its jar

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Refresh credentials independently recover access when no access cookie is present.

**Observed limitation.** After login the integration cookie jar already contains the access cookie. response.cookies[access] merely reads it; the code sets refresh again but never deletes access or expires it. The ok response can come from ordinary access authentication. Moreover, AuthenticationBase#transparent_refresh_allowed? currently returns false, so the invoked transparent refresh method immediately exits even before the access-cookie check. The temporary dummy endpoint omits the concrete RP lifecycle.

**Proposed action.** Replace this obsolete scenario with an explicit refresh protocol/RP request after removing or expiring access; assert rotation and new cookie state under the accepted Browser RP contract. The disabled transparent path is not a supported replacement contract.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/integration/auth_booster_test.rb](../../test/integration/auth_booster_test.rb), [app/controllers/concerns/authentication_base.rb](../../app/controllers/concerns/authentication_base.rb), [test/controllers/base/edge_v0_token_refreshes_test.rb](../../test/controllers/base/edge_v0_token_refreshes_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-03700](inventory/rails-integration.md#t-03700) | [test/integration/auth_booster_test.rb:186](../../test/integration/auth_booster_test.rb#L186) | "transparent refresh" |

<a id="lv-016"></a>
## LV-016: A logout revocation claim asserts no record deletion instead of revocation

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Sign-out invalidates refresh authority and clears credential cookies.

**Observed limitation.** The case named log_out revokes refresh token and removes cookies asserts only unchanged ClientToken.count and cleared cookies. A retained ACTIVE token passes those assertions. Retention requires checking status/credential rejection, not deletion.

**Proposed action.** Add public revocation/replay outcome or consolidate with a real sign-out/reuse test; retain cookie clearing coverage.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/concerns/auth/client_test.rb](../../test/concerns/auth/client_test.rb), [app/controllers/concerns/authentication_base.rb](../../app/controllers/concerns/authentication_base.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-00131](inventory/rails-concerns.md#t-00131) | [test/concerns/auth/client_test.rb:134](../../test/concerns/auth/client_test.rb#L134) | "log_out revokes refresh token and removes cookies" |

<a id="lv-017"></a>
## LV-017: Preference mutation cases verify only dummy-endpoint success

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** A preference update persists and returns the selected value or consent choice on its own surface.

**Observed limitation.** Each case redraws routes to DummyPreferenceController, sends edit/update requests and only checks success. A controller returning ok without changing preferences satisfies those assertions. The host localhost and the dummy path also bypass the deployed surface routing contract.

**Proposed action.** Move each claimed mutation to real surface endpoints and assert the resulting value/cookies. Keep the separate read-only GET case: it asserts no creation and no cookies.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/integration/preference_booster_test.rb](../../test/integration/preference_booster_test.rb), [app/controllers/concerns/preference_core.rb](../../app/controllers/concerns/preference_core.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-04313](inventory/rails-integration.md#t-04313) | [test/integration/preference_booster_test.rb:125](../../test/integration/preference_booster_test.rb#L125) | "edits and updates region" |
| [T-04314](inventory/rails-integration.md#t-04314) | [test/integration/preference_booster_test.rb:135](../../test/integration/preference_booster_test.rb#L135) | "edits and updates language" |
| [T-04315](inventory/rails-integration.md#t-04315) | [test/integration/preference_booster_test.rb:145](../../test/integration/preference_booster_test.rb#L145) | "edits and updates timezone" |
| [T-04316](inventory/rails-integration.md#t-04316) | [test/integration/preference_booster_test.rb:155](../../test/integration/preference_booster_test.rb#L155) | "edits and updates theme" |
| [T-04317](inventory/rails-integration.md#t-04317) | [test/integration/preference_booster_test.rb:166](../../test/integration/preference_booster_test.rb#L166) | "edits and updates cookie consent" |

<a id="lv-018"></a>
## LV-018: The title sweep can pass with zero checked responses on a host

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Every required rendered HTML page has one non-empty localized title.

**Observed limitation.** StandardError is ignored and unsuccessful/non-HTML responses are skipped. The only unconditional assertion compares attempted paths with the candidate count; checked.size may remain zero. A host that starts failing every request can therefore pass. The separate path-discovery assertion does not establish any successfully checked page on that host.

**Proposed action.** Define required routes per host and fail unexpected exceptions/statuses; record intentionally unreachable routes explicitly rather than counting attempts.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/integration/html_title_contract_test.rb](../../test/integration/html_title_contract_test.rb), [app/views/layouts/base/app/application.html.erb](../../app/views/layouts/base/app/application.html.erb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-04096](inventory/rails-integration.md#t-04096) | [test/integration/html_title_contract_test.rb:572](../../test/integration/html_title_contract_test.rb#L572) | "every routed GET HTML page carries a non-empty title on #{surface.fetch(:tld)} " \          "(#{surface.fetch(:host)})" |

<a id="lv-019"></a>
## LV-019: The route smoke sweep accepts routing misses as product success

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Published static routes reach their intended HTTP boundary without crashes.

**Observed limitation.** It gathers GET paths globally across host-constrained routes but sends every request to auth.app.localhost, accepting all statuses below 500. A missing or wrong-host route returning 404 is indistinguishable from the intended published route. It remains a coarse 5xx smoke test, not route reachability evidence.

**Proposed action.** Consolidate only after host-aware route coverage exists; assert required status/controller per route partition and fail an empty discovery set.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/integration/static_get_route_response_test.rb](../../test/integration/static_get_route_response_test.rb), [config/routes.rb](../../config/routes.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-04840](inventory/rails-integration.md#t-04840) | [test/integration/static_get_route_response_test.rb:11](../../test/integration/static_get_route_response_test.rb#L11) | "static GET routes do not produce an unhandled server error" |

<a id="lv-020"></a>
## LV-020: Bootstrap tests do not observe the shared-import claim

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Base/Auth import shared bootstrap; Warp/Palm avoid it; Core dev imports it without offline registration.

**Observed limitation.** The shared application module is mocked to an empty object, and every oracle observes only registerOfflineServiceWorker. Removing the shared import from a Base/Auth/Core wrapper, or adding it to a Warp wrapper, does not affect that oracle. The three declarations protect the registration half but overstate their bootstrap isolation claim.

**Proposed action.** Either assert the intended import-side effect through a meaningful boundary or narrow the names and consolidate wiring checks; keep service-worker behavior tests.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [src/entrypoints/base/app.ts](../../src/entrypoints/base/app.ts), [src/entrypoints/warp/app.ts](../../src/entrypoints/warp/app.ts), [src/entrypoints/core/dev.ts](../../src/entrypoints/core/dev.ts), [src/entrypoints/application.ts](../../src/entrypoints/application.ts).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-14001](inventory/gait.md#t-14001) | [gait/entrypoints/bootstrap_entrypoints.test.ts:30](../../gait/entrypoints/bootstrap_entrypoints.test.ts#L30) | "imports the shared application bootstrap and registers the offline service worker" |
| [T-14002](inventory/gait.md#t-14002) | [gait/entrypoints/bootstrap_entrypoints.test.ts:43](../../gait/entrypoints/bootstrap_entrypoints.test.ts#L43) | "registers the offline service worker without pulling in the Turbo application bundle" |
| [T-14003](inventory/gait.md#t-14003) | [gait/entrypoints/bootstrap_entrypoints.test.ts:51](../../gait/entrypoints/bootstrap_entrypoints.test.ts#L51) | "imports the shared application bootstrap without registering an offline service worker" |

<a id="lv-021"></a>
## LV-021: Flipper setup and vendor behavior tests are outside the environment-test policy

Priority: **P3**. Confidence: **confirmed-policy-conflict**. Disposition: **open; no removal performed**.

**Intended protection.** Feature-gated application requests fail closed and respond to explicit availability changes.

**Observed limitation.** The six cases assert Memory/ActiveRecord adapter selection, pool names, vendor reads/preloads and Flipper enable/disable behavior. These are tool/environment construction subjects under the accepted ADR. The case named outside test actually reads the currently booted test configuration. They do not prove a production boot or a protected request refusal.

**Proposed action.** Run the real configured setup and retain an evidence record; preserve application availability/kill-switch behavior tests. No removal is performed by this audit.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [config/initializers/flipper.rb](../../config/initializers/flipper.rb), [adr/no-test-suite-for-environment-construction.md](../../adr/no-test-suite-for-environment-construction.md).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-03545](inventory/rails-initializers.md#t-03545) | [test/initializers/flipper_test.rb:10](../../test/initializers/flipper_test.rb#L10) | "uses the in-memory adapter so the suite needs no flag storage backend" |
| [T-03546](inventory/rails-initializers.md#t-03546) | [test/initializers/flipper_test.rb:17](../../test/initializers/flipper_test.rb#L17) | "outside test the flag tables resolve to the primary database" |
| [T-03547](inventory/rails-initializers.md#t-03547) | [test/initializers/flipper_test.rb:24](../../test/initializers/flipper_test.rb#L24) | "the primary database is configured without a replica" |
| [T-03548](inventory/rails-initializers.md#t-03548) | [test/initializers/flipper_test.rb:33](../../test/initializers/flipper_test.rb#L33) | "the ActiveRecord adapter reads flags inside a reading-role request" |
| [T-03549](inventory/rails-initializers.md#t-03549) | [test/initializers/flipper_test.rb:48](../../test/initializers/flipper_test.rb#L48) | "the ActiveRecord adapter preloads every flag" |
| [T-03550](inventory/rails-initializers.md#t-03550) | [test/initializers/flipper_test.rb:56](../../test/initializers/flipper_test.rb#L56) | "features default to disabled and follow enable and disable" |

<a id="lv-022"></a>
## LV-022: Rack timeout tests validate initializer assignments rather than a timed request

Priority: **P3**. Confidence: **confirmed-policy-conflict**. Disposition: **open; no removal performed**.

**Intended protection.** The configured development/operational request timeout is installed and enforced.

**Observed limitation.** The test reloads an initializer with Rails.env stubbed and asserts ENV strings. It can synthesize Rack::Timeout if absent and never observes middleware enforcement. It also pins a code default contrary to the root required-configuration policy; that is an unresolved policy/code conflict, not authority to change the configuration here.

**Proposed action.** Replace the setup evidence with a boot/request observation under the owning configuration workflow; resolve the default policy conflict separately.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [config/initializers/rack_timeout.rb](../../config/initializers/rack_timeout.rb), [adr/no-test-suite-for-environment-construction.md](../../adr/no-test-suite-for-environment-construction.md).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-03588](inventory/rails-initializers.md#t-03588) | [test/initializers/rack_timeout_test.rb:18](../../test/initializers/rack_timeout_test.rb#L18) | "defaults service timeout to 10 seconds" |
| [T-03589](inventory/rails-initializers.md#t-03589) | [test/initializers/rack_timeout_test.rb:26](../../test/initializers/rack_timeout_test.rb#L26) | "preserves an explicit service timeout" |

<a id="lv-023"></a>
## LV-023: Prosopite tests exercise diagnostic-tool wiring outside production

Priority: **P3**. Confidence: **confirmed-policy-conflict**. Disposition: **open; no removal performed**.

**Intended protection.** Diagnostic SQL fingerprinting preserves connection-role state in the configured development tool.

**Observed limitation.** These invoke the diagnostic gem and the non-production initializer patch. Their subject is tool wiring, explicitly excluded from permanent Minitest/Vitest setup coverage. They do have a real role-restoration oracle; low value here is the agreed suite ownership decision, not tautology.

**Proposed action.** Run the configured tool and record role/fingerprint evidence; do not use this as grounds to remove product connection-role tests.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [config/initializers/prosopite.rb](../../config/initializers/prosopite.rb), [adr/no-test-suite-for-environment-construction.md](../../adr/no-test-suite-for-environment-construction.md).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-03586](inventory/rails-initializers.md#t-03586) | [test/initializers/prosopite_test.rb:12](../../test/initializers/prosopite_test.rb#L12) | "fingerprint works while Active Record base is in reading role" |
| [T-03587](inventory/rails-initializers.md#t-03587) | [test/initializers/prosopite_test.rb:21](../../test/initializers/prosopite_test.rb#L21) | "fingerprint does not leave Active Record base in writing role" |

<a id="lv-024"></a>
## LV-024: Compose assertions belong to observed environment construction evidence

Priority: **P3**. Confidence: **confirmed-policy-conflict**. Disposition: **open; no removal performed**.

**Intended protection.** Published services use the reviewed host exposure and socket policy.

**Observed limitation.** Six cases parse Compose YAML and assert port/network/socket declaration shapes. This is precisely Compose/devcontainer setup covered by the no-environment-tests ADR. They cannot show the effective running listener or override resolution, although the exposure intent is security-relevant.

**Proposed action.** Preserve the intent, validate resolved configuration and actual listeners, and record evidence before any future suite retirement. Existing security invariant tests are excluded from this recommendation.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [compose.yaml](../../compose.yaml), [.devcontainer/compose.yaml](../../.devcontainer/compose.yaml), [docs/operations/development-host-port-exposure.md](../../docs/operations/development-host-port-exposure.md), [adr/no-test-suite-for-environment-construction.md](../../adr/no-test-suite-for-environment-construction.md).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-12837](inventory/rails-tooling.md#t-12837) | [test/tooling/compose_host_port_exposure_test.rb:38](../../test/tooling/compose_host_port_exposure_test.rb#L38) | test_every_published_port_binds_loopback |
| [T-12838](inventory/rails-tooling.md#t-12838) | [test/tooling/compose_host_port_exposure_test.rb:47](../../test/tooling/compose_host_port_exposure_test.rb#L47) | test_backend_observability_services_have_no_host_publication |
| [T-12839](inventory/rails-tooling.md#t-12839) | [test/tooling/compose_host_port_exposure_test.rb:57](../../test/tooling/compose_host_port_exposure_test.rb#L57) | test_grafana_publishes_only_loopback_13000 |
| [T-12840](inventory/rails-tooling.md#t-12840) | [test/tooling/compose_host_port_exposure_test.rb:72](../../test/tooling/compose_host_port_exposure_test.rb#L72) | test_alloy_publishes_only_the_loopback_otlp_http_receiver |
| [T-12841](inventory/rails-tooling.md#t-12841) | [test/tooling/compose_host_port_exposure_test.rb:88](../../test/tooling/compose_host_port_exposure_test.rb#L88) | test_no_service_uses_host_networking |
| [T-12842](inventory/rails-tooling.md#t-12842) | [test/tooling/compose_host_port_exposure_test.rb:103](../../test/tooling/compose_host_port_exposure_test.rb#L103) | test_no_service_mounts_a_container_socket |

<a id="lv-025"></a>
## LV-025: A prose-heading assertion adds no deployed behavior evidence

Priority: **P3**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** The content-surface matrix accurately describes the currently served/pending surfaces.

**Observed limitation.** The test checks twelve literal Markdown headings and the sentence Edge does not consume it yet. Rewording the same fact breaks it; an implementation contradicting the document can leave it green. It is a document-shape check rather than evidence that any surface is served or isolated.

**Proposed action.** Move durable surface behavior into host/authorization contracts; maintain prose through review. Reassess the historical sentence against code before changing it.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [docs/architecture/content-surface-matrix.md](../../docs/architecture/content-surface-matrix.md), [test/tooling/content_surface_matrix_doc_test.rb](../../test/tooling/content_surface_matrix_doc_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-12843](inventory/rails-tooling.md#t-12843) | [test/tooling/content_surface_matrix_doc_test.rb:25](../../test/tooling/content_surface_matrix_doc_test.rb#L25) | test_matrix_document_lists_every_cell_and_does_not_claim_edge_cms_is_deployed |

<a id="lv-026"></a>
## LV-026: A future route-file existence test is a weak setup check

Priority: **P3**. Confidence: **confirmed-policy-conflict**. Disposition: **open; no removal performed**.

**Intended protection.** Required routing entrypoints expose the intended concrete routes.

**Observed limitation.** The case merely checks that config/routes/core.rb exists. An empty or never-loaded file passes. Setup construction is outside permanent test-suite coverage under the ADR. The neighboring route-recognition case has a different and stronger oracle and is not included in this finding.

**Proposed action.** Use actual boot/route behavior evidence; retire the existence-only check independently.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [config/routes/core.rb](../../config/routes/core.rb), [config/routes.rb](../../config/routes.rb), [adr/no-test-suite-for-environment-construction.md](../../adr/no-test-suite-for-environment-construction.md).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-00164](inventory/rails-config.md#t-00164) | [test/config/routing_entrypoints_test.rb:19](../../test/config/routing_entrypoints_test.rb#L19) | "future routing namespace files exist" |

<a id="lv-027"></a>
## LV-027: Unsaved integer-ID validity is a repeated weak proxy for schema safety

Priority: **P3**. Confidence: **candidate**. Disposition: **open; no removal performed**.

**Intended protection.** Fixed reference identifiers retain the required persisted shape and domain mapping.

**Observed limitation.** Fifty definitions share the claim accepts integer ids. Representative bodies only construct id: 9/99 and call valid?, which does not insert/read a PostgreSQL bigint or test a domain mapping. This family is a structural candidate; the entire family has not received a per-model semantic deletion decision. Concrete fixed constants and restrictive foreign keys can be materially different contracts.

**Proposed action.** Review individually against persisted type/FK/default-row tests, then consolidate only proven redundant validity smoke checks. Keep persistent constant mappings.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [test/models/client_token_kind_test.rb](../../test/models/client_token_kind_test.rb), [test/models/client_mfa_level_test.rb](../../test/models/client_mfa_level_test.rb), [app/models/client_mfa_level.rb](../../app/models/client_mfa_level.rb), [test/models/database_pk_type_test.rb](../../test/models/database_pk_type_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-05554](inventory/rails-models-a.md#t-05554) | [test/models/agent_membership_kind_test.rb:15](../../test/models/agent_membership_kind_test.rb#L15) | "accepts integer ids" |
| [T-05559](inventory/rails-models-a.md#t-05559) | [test/models/agent_membership_revoke_reason_test.rb:15](../../test/models/agent_membership_revoke_reason_test.rb#L15) | "accepts integer ids" |
| [T-05564](inventory/rails-models-a.md#t-05564) | [test/models/agent_membership_state_test.rb:15](../../test/models/agent_membership_state_test.rb#L15) | "accepts integer ids" |
| [T-05622](inventory/rails-models-a.md#t-05622) | [test/models/app_preference_chronicle_event_test.rb:17](../../test/models/app_preference_chronicle_event_test.rb#L17) | "accepts integer ids" |
| [T-05804](inventory/rails-models-a.md#t-05804) | [test/models/area_occurrence_status_test.rb:22](../../test/models/area_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-05929](inventory/rails-models-a.md#t-05929) | [test/models/avatar_capability_test.rb:37](../../test/models/avatar_capability_test.rb#L37) | "accepts integer ids" |
| [T-06012](inventory/rails-models-a.md#t-06012) | [test/models/avatar_ownership_status_test.rb:15](../../test/models/avatar_ownership_status_test.rb#L15) | "accepts integer ids" |
| [T-06016](inventory/rails-models-a.md#t-06016) | [test/models/avatar_permission_test.rb:15](../../test/models/avatar_permission_test.rb#L15) | "accepts integer ids" |
| [T-06039](inventory/rails-models-a.md#t-06039) | [test/models/avatar_role_test.rb:15](../../test/models/avatar_role_test.rb#L15) | "accepts integer ids" |
| [T-06173](inventory/rails-models-c.md#t-06173) | [test/models/client_chronicle_event_test.rb:21](../../test/models/client_chronicle_event_test.rb#L21) | "accepts integer ids" |
| [T-06180](inventory/rails-models-c.md#t-06180) | [test/models/client_chronicle_level_test.rb:19](../../test/models/client_chronicle_level_test.rb#L19) | "accepts integer ids" |
| [T-06266](inventory/rails-models-c.md#t-06266) | [test/models/client_mfa_level_test.rb:15](../../test/models/client_mfa_level_test.rb#L15) | "accepts integer ids" |
| [T-06276](inventory/rails-models-c.md#t-06276) | [test/models/client_occurrence_status_test.rb:29](../../test/models/client_occurrence_status_test.rb#L29) | "accepts integer ids" |
| [T-06385](inventory/rails-models-c.md#t-06385) | [test/models/client_profile_status_test.rb:15](../../test/models/client_profile_status_test.rb#L15) | "accepts integer ids" |
| [T-06600](inventory/rails-models-c.md#t-06600) | [test/models/client_token_kind_test.rb:15](../../test/models/client_token_kind_test.rb#L15) | "accepts integer ids" |
| [T-06607](inventory/rails-models-c.md#t-06607) | [test/models/client_token_status_test.rb:15](../../test/models/client_token_status_test.rb#L15) | "accepts integer ids" |
| [T-06717](inventory/rails-models-c.md#t-06717) | [test/models/com_preference_chronicle_event_test.rb:26](../../test/models/com_preference_chronicle_event_test.rb#L26) | "accepts integer ids" |
| [T-06791](inventory/rails-models-c.md#t-06791) | [test/models/com_preference_status_test.rb:32](../../test/models/com_preference_status_test.rb#L32) | "accepts integer ids" |
| [T-07306](inventory/rails-models-d.md#t-07306) | [test/models/division_status_test.rb:19](../../test/models/division_status_test.rb#L19) | "accepts integer ids" |
| [T-07318](inventory/rails-models-d.md#t-07318) | [test/models/domain_occurrence_status_test.rb:22](../../test/models/domain_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-07347](inventory/rails-models-e.md#t-07347) | [test/models/email_occurrence_status_test.rb:22](../../test/models/email_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-07443](inventory/rails-models-h.md#t-07443) | [test/models/handle_assignment_status_test.rb:15](../../test/models/handle_assignment_status_test.rb#L15) | "accepts integer ids" |
| [T-07477](inventory/rails-models-i.md#t-07477) | [test/models/individual_membership_kind_test.rb:15](../../test/models/individual_membership_kind_test.rb#L15) | "accepts integer ids" |
| [T-07482](inventory/rails-models-i.md#t-07482) | [test/models/individual_membership_revoke_reason_test.rb:15](../../test/models/individual_membership_revoke_reason_test.rb#L15) | "accepts integer ids" |
| [T-07487](inventory/rails-models-i.md#t-07487) | [test/models/individual_membership_state_test.rb:15](../../test/models/individual_membership_state_test.rb#L15) | "accepts integer ids" |
| [T-07496](inventory/rails-models-i.md#t-07496) | [test/models/ip_occurrence_status_test.rb:22](../../test/models/ip_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-07528](inventory/rails-models-j.md#t-07528) | [test/models/jwt_occurrence_status_test.rb:23](../../test/models/jwt_occurrence_status_test.rb#L23) | "accepts integer ids" |
| [T-07682](inventory/rails-models-o.md#t-07682) | [test/models/operator_chronicle_event_test.rb:21](../../test/models/operator_chronicle_event_test.rb#L21) | "accepts integer ids" |
| [T-07688](inventory/rails-models-o.md#t-07688) | [test/models/operator_chronicle_level_test.rb:41](../../test/models/operator_chronicle_level_test.rb#L41) | "accepts integer ids" |
| [T-07767](inventory/rails-models-o.md#t-07767) | [test/models/operator_mfa_level_test.rb:15](../../test/models/operator_mfa_level_test.rb#L15) | "accepts integer ids" |
| [T-07777](inventory/rails-models-o.md#t-07777) | [test/models/operator_occurrence_status_test.rb:22](../../test/models/operator_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-07786](inventory/rails-models-o.md#t-07786) | [test/models/operator_passkey_status_test.rb:16](../../test/models/operator_passkey_status_test.rb#L16) | "accepts integer ids" |
| [T-08017](inventory/rails-models-o.md#t-08017) | [test/models/operator_token_kind_test.rb:15](../../test/models/operator_token_kind_test.rb#L15) | "accepts integer ids" |
| [T-08024](inventory/rails-models-o.md#t-08024) | [test/models/operator_token_status_test.rb:15](../../test/models/operator_token_status_test.rb#L15) | "accepts integer ids" |
| [T-08069](inventory/rails-models-o.md#t-08069) | [test/models/operator_workspace_account_status_test.rb:14](../../test/models/operator_workspace_account_status_test.rb#L14) | "accepts integer ids" |
| [T-08101](inventory/rails-models-o.md#t-08101) | [test/models/org_preference_chronicle_event_test.rb:16](../../test/models/org_preference_chronicle_event_test.rb#L16) | "accepts integer ids" |
| [T-08174](inventory/rails-models-o.md#t-08174) | [test/models/org_preference_status_test.rb:32](../../test/models/org_preference_status_test.rb#L32) | "accepts integer ids" |
| [T-08199](inventory/rails-models-o.md#t-08199) | [test/models/org_preference_theme_option_test.rb:43](../../test/models/org_preference_theme_option_test.rb#L43) | "accepts integer ids" |
| [T-08282](inventory/rails-models-o.md#t-08282) | [test/models/organization_status_test.rb:18](../../test/models/organization_status_test.rb#L18) | "accepts integer ids" |
| [T-08349](inventory/rails-models-p.md#t-08349) | [test/models/persona_membership_kind_test.rb:15](../../test/models/persona_membership_kind_test.rb#L15) | "accepts integer ids" |
| [T-08354](inventory/rails-models-p.md#t-08354) | [test/models/persona_membership_revoke_reason_test.rb:15](../../test/models/persona_membership_revoke_reason_test.rb#L15) | "accepts integer ids" |
| [T-08359](inventory/rails-models-p.md#t-08359) | [test/models/persona_membership_state_test.rb:15](../../test/models/persona_membership_state_test.rb#L15) | "accepts integer ids" |
| [T-08974](inventory/rails-models-t.md#t-08974) | [test/models/telephone_occurrence_status_test.rb:22](../../test/models/telephone_occurrence_status_test.rb#L22) | "accepts integer ids" |
| [T-09023](inventory/rails-models-v.md#t-09023) | [test/models/visitor_email_status_test.rb:15](../../test/models/visitor_email_status_test.rb#L15) | "accepts integer ids" |
| [T-09046](inventory/rails-models-v.md#t-09046) | [test/models/visitor_mfa_level_test.rb:15](../../test/models/visitor_mfa_level_test.rb#L15) | "accepts integer ids" |
| [T-09169](inventory/rails-models-v.md#t-09169) | [test/models/visitor_telephone_status_test.rb:15](../../test/models/visitor_telephone_status_test.rb#L15) | "accepts integer ids" |
| [T-09206](inventory/rails-models-v.md#t-09206) | [test/models/visitor_token_binding_method_test.rb:15](../../test/models/visitor_token_binding_method_test.rb#L15) | "accepts integer ids" |
| [T-09214](inventory/rails-models-v.md#t-09214) | [test/models/visitor_token_kind_test.rb:15](../../test/models/visitor_token_kind_test.rb#L15) | "accepts integer ids" |
| [T-09218](inventory/rails-models-v.md#t-09218) | [test/models/visitor_token_status_test.rb:15](../../test/models/visitor_token_status_test.rb#L15) | "accepts integer ids" |
| [T-09261](inventory/rails-models-z.md#t-09261) | [test/models/zip_occurrence_status_test.rb:22](../../test/models/zip_occurrence_status_test.rb#L22) | "accepts integer ids" |

<a id="lv-028"></a>
## LV-028: The CSP intake registration test makes rate-limit registration a no-op

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** CSP report intake registers and enforces its abuse controls and safe rejection behavior.

**Observed limitation.** The harness overrides its rate_limit class method with an empty body, calls protect_csp_violation_report_intake, and only asserts no exception. It cannot detect omission or wrong options of the discarded registration and sends no request through a configured limit.

**Proposed action.** Consolidate with routed CSP intake/rate-limit tests that assert enforcement and safe response behavior; retain independent report privacy tests.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/concerns/csp_violation_report.rb](../../app/controllers/concerns/csp_violation_report.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02857](inventory/rails-controllers-concerns.md#t-02857) | [test/controllers/concerns/csp_violation_report_test.rb:25](../../test/controllers/concerns/csp_violation_report_test.rb#L25) | "protect_csp_violation_report_intake registers rescue and rate limit when available" |

<a id="lv-029"></a>
## LV-029: Conditional Apple action assertions disappear when an action disappears

Priority: **P2**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** The Apple confirmation route refuses a failed gate on both applicable verbs.

**Observed limitation.** Each assertion is guarded by if respond_to?(:show/update). Removing the action can remove its assertion. A controller is directly instantiated, load_gate_context! is overwritten, and neither HTTP denial nor no-state-change is observed.

**Proposed action.** Use real routed refusal cases with required status and state assertions; fail explicitly when a required action is missing.

**Replacement / safety condition.** No replacement demonstrated; preserve coverage until the replacement is run.

**Implementation and comparison sources.** [app/controllers/auth/app/sign/up/check/apple/confirmations_controller.rb](../../app/controllers/auth/app/sign/up/check/apple/confirmations_controller.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-12953](inventory/rails-unit.md#t-12953) | [test/unit/branch_coverage_batch16_zeros_and_precision_test.rb:29](../../test/unit/branch_coverage_batch16_zeros_and_precision_test.rb#L29) | "apple confirmations early returns" |

<a id="lv-030"></a>
## LV-030: The visitor scope case repeats the client partition

Priority: **P1**. Confidence: **confirmed**. Disposition: **open; no removal performed**.

**Intended protection.** Visitor-domain scope must be accepted for visitor and refused for other actor types.

**Observed limitation.** Despite its visitor name, the payload is authenticated domain:client and the expected resource type argument is client. The body is token-identical to the matching-user case at line 59. A visitor-specific regression cannot be detected by this case.

**Proposed action.** Repair the input and expected actor to exercise the visitor partition; retain the existing client case.

**Replacement / safety condition.** The client case at line 59 covers only the client partition; it is not a substitute for visitor coverage.

**Implementation and comparison sources.** [app/controllers/concerns/authentication_token_service.rb](../../app/controllers/concerns/authentication_token_service.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-02732](inventory/rails-controllers-concerns.md#t-02732) | [test/controllers/concerns/authentication/token_service_test.rb:77](../../test/controllers/concerns/authentication/token_service_test.rb#L77) | "resource_type_scope_matches? returns true for matching visitor" |

<a id="lv-031"></a>
## LV-031: The retired passkey-route absence is asserted twice

Priority: **P2**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** retired passkey settings route is absent from sign

**Observed limitation.** Both declarations belong to Auth::App::UiFoundationTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 23 adds no distinct reachable input or oracle to the earlier declaration at line 17.

**Proposed action.** Consolidate into T-00694 at test/controllers/auth/app/ui_foundation_test.rb:17; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-00694 (test/controllers/auth/app/ui_foundation_test.rb:17) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [config/routes/auth.rb](../../config/routes/auth.rb), [test/controllers/auth/app/ui_foundation_test.rb](../../test/controllers/auth/app/ui_foundation_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-00695](inventory/rails-controllers-auth.md#t-00695) | [test/controllers/auth/app/ui_foundation_test.rb:23](../../test/controllers/auth/app/ui_foundation_test.rb#L23) | "unauthenticated retired passkey settings entry cannot start a handoff" |

<a id="lv-032"></a>
## LV-032: The credential-ceremony claim repeats a non-404 smoke request

Priority: **P2**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** totp settings route exists on sign

**Observed limitation.** Both declarations belong to Auth::App::UiFoundationTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 60 adds no distinct reachable input or oracle to the earlier declaration at line 29. Its credential-ceremony name overstates the body: assert_not_equal 404 also permits 500, and no ceremony binding or mutation is asserted.

**Proposed action.** Consolidate into T-00696 at test/controllers/auth/app/ui_foundation_test.rb:29; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-00696 (test/controllers/auth/app/ui_foundation_test.rb:29) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [config/routes/auth.rb](../../config/routes/auth.rb), [test/controllers/auth/app/ui_foundation_test.rb](../../test/controllers/auth/app/ui_foundation_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-00700](inventory/rails-controllers-auth.md#t-00700) | [test/controllers/auth/app/ui_foundation_test.rb:60](../../test/controllers/auth/app/ui_foundation_test.rb#L60) | "TOTP registration remains scoped to credential ceremony" |

<a id="lv-033"></a>
## LV-033: Binding-method default-row idempotence is duplicated

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** ensure_defaults! skips existing records

**Observed limitation.** Both declarations belong to AppPreferenceBindingMethodTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 66 adds no distinct reachable input or oracle to the earlier declaration at line 60.

**Proposed action.** Consolidate into T-05618 at test/models/app_preference_binding_method_test.rb:60; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-05618 (test/models/app_preference_binding_method_test.rb:60) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/models/app_preference_binding_method.rb](../../app/models/app_preference_binding_method.rb), [test/models/app_preference_binding_method_test.rb](../../test/models/app_preference_binding_method_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-05619](inventory/rails-models-a.md#t-05619) | [test/models/app_preference_binding_method_test.rb:66](../../test/models/app_preference_binding_method_test.rb#L66) | "ensure_defaults! does nothing when all exist" |

<a id="lv-034"></a>
## LV-034: The invalid retention ordering partition is duplicated

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** validates discard_at <= purge_eligible_at

**Observed limitation.** Both declarations belong to RetainableTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 199 adds no distinct reachable input or oracle to the earlier declaration at line 142.

**Proposed action.** Consolidate into T-07111 at test/models/concerns/retainable_test.rb:142; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-07111 (test/models/concerns/retainable_test.rb:142) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/models/concerns/retainable.rb](../../app/models/concerns/retainable.rb), [test/models/concerns/retainable_test.rb](../../test/models/concerns/retainable_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-07116](inventory/rails-models-concerns.md#t-07116) | [test/models/concerns/retainable_test.rb:199](../../test/models/concerns/retainable_test.rb#L199) | "a discard_at later than purge_eligible_at is invalid" |

<a id="lv-035"></a>
## LV-035: Operator language default-row idempotence is duplicated

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** ensure_defaults! skips existing records

**Observed limitation.** Both declarations belong to OperatorPreferenceLanguageOptionTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 83 adds no distinct reachable input or oracle to the earlier declaration at line 77.

**Proposed action.** Consolidate into T-07835 at test/models/operator_preference_language_option_test.rb:77; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-07835 (test/models/operator_preference_language_option_test.rb:77) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/models/operator_preference_language_option.rb](../../app/models/operator_preference_language_option.rb), [test/models/operator_preference_language_option_test.rb](../../test/models/operator_preference_language_option_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-07836](inventory/rails-models-o.md#t-07836) | [test/models/operator_preference_language_option_test.rb:83](../../test/models/operator_preference_language_option_test.rb#L83) | "ensure_defaults! does nothing when all exist" |

<a id="lv-036"></a>
## LV-036: The same valid Operator identifier is presented as two techniques

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** boundary: length 16 is valid

**Observed limitation.** Both declarations belong to OperatorTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 258 adds no distinct reachable input or oracle to the earlier declaration at line 241. Boundary and partition techniques may use the same representative without executing it twice; preserve both intentions in the surviving test name/comment.

**Proposed action.** Consolidate into T-07977 at test/models/operator_test.rb:241; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-07977 (test/models/operator_test.rb:241) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/models/operator.rb](../../app/models/operator.rb), [test/models/operator_test.rb](../../test/models/operator_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-07979](inventory/rails-models-o.md#t-07979) | [test/models/operator_test.rb:258](../../test/models/operator_test.rb#L258) | "equivalence: valid set - allowed base32 characters only (16 chars) is valid" |

<a id="lv-037"></a>
## LV-037: The same expired sign-in transition is tested twice

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** sign-in cycle methods reject expired cycles

**Observed limitation.** Both declarations belong to SignFlowTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 489 adds no distinct reachable input or oracle to the earlier declaration at line 476.

**Proposed action.** Consolidate into T-08875 at test/models/sign_flow_test.rb:476; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-08875 (test/models/sign_flow_test.rb:476) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/models/client_sign_in_flow.rb](../../app/models/client_sign_in_flow.rb), [test/models/sign_flow_test.rb](../../test/models/sign_flow_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-08876](inventory/rails-models-s.md#t-08876) | [test/models/sign_flow_test.rb:489](../../test/models/sign_flow_test.rb#L489) | "named sign-in transitions reject expired cycles after terminalizing them" |

<a id="lv-038"></a>
## LV-038: The block-precedence claim repeats the same blocked-target setup

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** create denies follow when target blocked actor

**Observed limitation.** Both declarations belong to AvatarFollowPolicyTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 47 adds no distinct reachable input or oracle to the earlier declaration at line 29. The later test creates no existing follow, so it adds no interaction between an existing follow and a block despite its precedence name.

**Proposed action.** Consolidate into T-10080 at test/policies/avatar_follow_policy_test.rb:29; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-10080 (test/policies/avatar_follow_policy_test.rb:29) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/policies/avatar_follow_policy.rb](../../app/policies/avatar_follow_policy.rb), [test/policies/avatar_follow_policy_test.rb](../../test/policies/avatar_follow_policy_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-10082](inventory/rails-policies.md#t-10082) | [test/policies/avatar_follow_policy_test.rb:47](../../test/policies/avatar_follow_policy_test.rb#L47) | "block precedence wins over follow" |

<a id="lv-039"></a>
## LV-039: Missing confidential-client authentication has duplicate scenarios

Priority: **P3**. Confidence: **confirmed-duplicate**. Disposition: **open; no removal performed**.

**Intended protection.** fails invalid_client for missing confidential client secret

**Observed limitation.** Both declarations belong to OidcTokenExchangeCoordinatorTest, use the same class setup and have token-identical bodies (comments and whitespace excluded). The later declaration at line 1416 adds no distinct reachable input or oracle to the earlier declaration at line 994.

**Proposed action.** Consolidate into T-11938 at test/services/oidc/token_exchange_service_test.rb:994; add a genuinely different scenario if the later name intended one.

**Replacement / safety condition.** T-11938 (test/services/oidc/token_exchange_service_test.rb:994) has the same current setup, action and assertion body. Runtime equivalence beyond this inspected code was not mutation-tested.

**Implementation and comparison sources.** [app/services/oidc_token_exchange_coordinator.rb](../../app/services/oidc_token_exchange_coordinator.rb), [test/services/oidc/token_exchange_service_test.rb](../../test/services/oidc/token_exchange_service_test.rb).

**Affected definitions.**

| ID | Source | Declared protection |
| --- | --- | --- |
| [T-11958](inventory/rails-services-oidc.md#t-11958) | [test/services/oidc/token_exchange_service_test.rb:1416](../../test/services/oidc/token_exchange_service_test.rb#L1416) | "confidential client cannot use public path by omitting secret" |
