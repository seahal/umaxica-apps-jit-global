# rails-services-dpop: per-definition ledger

14 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/services/dpop/jti_replay_guard_test.rb`

[test/services/dpop/jti_replay_guard_test.rb](../../../test/services/dpop/jti_replay_guard_test.rb); SHA-256: `64284360e42f4d21c849a7f14a37c47a156b78158f55d30128253e1732d23454`.

File-level implementation candidates (including setup/import context): [app/models/client_dpop_proof_state.rb:27](../../../app/models/client_dpop_proof_state.rb#L27); [app/services/dpop_jti_replay_guard.rb:4](../../../app/services/dpop_jti_replay_guard.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11397"></a>T-11397 / [13](../../../test/services/dpop/jti_replay_guard_test.rb#L13) | "record! stores jti and returns true on first record"<br>Owner: `Dpop::JtiReplayGuardTest` | `assert DpopJtiReplayGuard.record!("jti_1")` | [DpopJtiReplayGuard](../../../app/services/dpop_jti_replay_guard.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11398"></a>T-11398 / [17](../../../test/services/dpop/jti_replay_guard_test.rb#L17) | "record! returns false on duplicate jti"<br>Owner: `Dpop::JtiReplayGuardTest` | `assert_not DpopJtiReplayGuard.record!("jti_2")` | [DpopJtiReplayGuard](../../../app/services/dpop_jti_replay_guard.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11399"></a>T-11399 / [23](../../../test/services/dpop/jti_replay_guard_test.rb#L23) | "record! returns false for blank jti"<br>Owner: `Dpop::JtiReplayGuardTest` | `assert_not DpopJtiReplayGuard.record!("")`; `assert_not DpopJtiReplayGuard.record!(nil)` | [DpopJtiReplayGuard](../../../app/services/dpop_jti_replay_guard.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/dpop/nonce_service_test.rb`

[test/services/dpop/nonce_service_test.rb](../../../test/services/dpop/nonce_service_test.rb); SHA-256: `1060e8f07896d276cf21a734ea2f93c37dd305eeecfc541745ff71e08ccfb510`.

File-level implementation candidates (including setup/import context): [app/models/client_dpop_proof_state.rb:27](../../../app/models/client_dpop_proof_state.rb#L27); [app/services/dpop_nonce_service.rb:4](../../../app/services/dpop_nonce_service.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11400"></a>T-11400 / [13](../../../test/services/dpop/nonce_service_test.rb#L13) | "generate creates a unique nonce"<br>Owner: `Dpop::NonceServiceTest` | `assert_predicate nonce1, :present?`; `assert_predicate nonce2, :present?`; `assert_not_equal nonce1, nonce2` | [DpopNonceService](../../../app/services/dpop_nonce_service.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11401"></a>T-11401 / [22](../../../test/services/dpop/nonce_service_test.rb#L22) | "verify returns true for a generated nonce"<br>Owner: `Dpop::NonceServiceTest` | `assert DpopNonceService.verify(nonce)` | [DpopNonceService](../../../app/services/dpop_nonce_service.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11402"></a>T-11402 / [28](../../../test/services/dpop/nonce_service_test.rb#L28) | "verify returns false for an unknown nonce"<br>Owner: `Dpop::NonceServiceTest` | `assert_not DpopNonceService.verify("unknown_nonce")` | [DpopNonceService](../../../app/services/dpop_nonce_service.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11403"></a>T-11403 / [32](../../../test/services/dpop/nonce_service_test.rb#L32) | "verify returns false for blank nonce"<br>Owner: `Dpop::NonceServiceTest` | `assert_not DpopNonceService.verify("")`; `assert_not DpopNonceService.verify(nil)` | [DpopNonceService](../../../app/services/dpop_nonce_service.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11404"></a>T-11404 / [37](../../../test/services/dpop/nonce_service_test.rb#L37) | "nonce is single use"<br>Owner: `Dpop::NonceServiceTest` | `assert DpopNonceService.verify(nonce)`; `assert_not DpopNonceService.verify(nonce)` | [DpopNonceService](../../../app/services/dpop_nonce_service.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/dpop/request_verifier_test.rb`

[test/services/dpop/request_verifier_test.rb](../../../test/services/dpop/request_verifier_test.rb); SHA-256: `370b973b6a7898ff26ce40ccad2b8ad619db4c2379e8ac8b4c235b72f21ed734`.

File-level implementation candidates (including setup/import context): [app/services/dpop_request_verifier.rb:4](../../../app/services/dpop_request_verifier.rb#L4); [lib/jit_security_jwt_thumbprint_calculator.rb:8](../../../lib/jit_security_jwt_thumbprint_calculator.rb#L8).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11405"></a>T-11405 / [20](../../../test/services/dpop/request_verifier_test.rb#L20) | "accepts standard bearer when no cnf.jkt and no proof"<br>Owner: `Dpop::RequestVerifierTest` | `assert_predicate result, :valid?` | [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11406"></a>T-11406 / [32](../../../test/services/dpop/request_verifier_test.rb#L32) | "rejects dpop-bound token without proof"<br>Owner: `Dpop::RequestVerifierTest` | `assert_not result.valid?`; `assert_equal "missing_dpop_proof", result.error` | [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11407"></a>T-11407 / [45](../../../test/services/dpop/request_verifier_test.rb#L45) | "accepts valid dpop proof with matching jkt"<br>Owner: `Dpop::RequestVerifierTest` | `assert_predicate result, :valid?` | [JitSecurityJwtThumbprintCalculator](../../../lib/jit_security_jwt_thumbprint_calculator.rb#L8); [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11408"></a>T-11408 / [61](../../../test/services/dpop/request_verifier_test.rb#L61) | "rejects replayed dpop proof jti on resource requests"<br>Owner: `Dpop::RequestVerifierTest` | `assert_predicate first, :valid?`; `assert_not replay.valid?`; `assert_equal "jti_replay", replay.error` | [JitSecurityJwtThumbprintCalculator](../../../lib/jit_security_jwt_thumbprint_calculator.rb#L8); [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11409"></a>T-11409 / [85](../../../test/services/dpop/request_verifier_test.rb#L85) | "rejects dpop proof with mismatched jkt"<br>Owner: `Dpop::RequestVerifierTest` | `assert_not result.valid?`; `assert_equal "jkt_mismatch", result.error` | [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11410"></a>T-11410 / [101](../../../test/services/dpop/request_verifier_test.rb#L101) | "rejects when proof validation fails"<br>Owner: `Dpop::RequestVerifierTest` | `assert_not result.valid?`; `assert_equal "malformed_proof", result.error` | [DpopRequestVerifier](../../../app/services/dpop_request_verifier.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
