# rails-concurrency: per-definition ledger

2 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/concurrency/operator_capability_continuity_test.rb`

[test/concurrency/operator_capability_continuity_test.rb](../../../test/concurrency/operator_capability_continuity_test.rb); SHA-256: `e914da01af925e775f35799afa790f33c18dde8fd663f395b97ba1666c5c807c`.

File-level implementation candidates (including setup/import context): [app/models/operator.rb:59](../../../app/models/operator.rb#L59); [app/models/operator_status.rb:12](../../../app/models/operator_status.rb#L12); [app/models/operator_visibility.rb:11](../../../app/models/operator_visibility.rb#L11); [app/models/operator_capability_grant.rb:10](../../../app/models/operator_capability_grant.rb#L10).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-00151"></a>T-00151 / [32](../../../test/concurrency/operator_capability_continuity_test.rb#L32) | "concurrent revocations of the last two holders leave at least one holder"<br>Owner: `OperatorCapabilityContinuityTest` | `assert_operator remaining, :&gt;=, 1, "outcomes were #{results.inspect}"`; `assert_equal 1, results.count(:revoked), "exactly one revocation may win: #{results.inspect}"` | [OperatorCapabilityGrant](../../../app/models/operator_capability_grant.rb#L10); [Operator](../../../app/models/operator.rb#L59) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/concurrency/preference_parallel_read_test.rb`

[test/concurrency/preference_parallel_read_test.rb](../../../test/concurrency/preference_parallel_read_test.rb); SHA-256: `68e6fece6d0174d2d593cc3b77573bd207dff8f1b3cb528c8932daec7223a95b`.

File-level implementation candidates (including setup/import context): [app/models/app_preference.rb:49](../../../app/models/app_preference.rb#L49); [lib/jit_security_jwt_jti_generator.rb:7](../../../lib/jit_security_jwt_jti_generator.rb#L7); [app/models/app_preference_binding_method.rb:11](../../../app/models/app_preference_binding_method.rb#L11); [app/models/app_preference_dbsc_status.rb:11](../../../app/models/app_preference_dbsc_status.rb#L11); [app/controllers/concerns/preference_cookie_name.rb:4](../../../app/controllers/concerns/preference_cookie_name.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-00152"></a>T-00152 / [32](../../../test/concurrency/preference_parallel_read_test.rb#L32) | "parallel reads of one generation all succeed without replay, deletion, rotation, or insert"<br>Owner: `PreferenceParallelReadTest` | `assert_equal [[200, false]] * READERS, outcomes`; `assert_nil @preference.used_at`; `assert_predicate @preference.discard_at, :future?`; +1 further assertion lines | [AppPreference](../../../app/models/app_preference.rb#L49); [PreferenceCookieName](../../../app/controllers/concerns/preference_cookie_name.rb#L4) | S: static inventory; individual semantic review open | environment-reference |
