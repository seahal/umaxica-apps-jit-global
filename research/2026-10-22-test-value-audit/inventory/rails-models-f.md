# rails-models-f: per-definition ledger

2 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/flow_expiry_commit_test.rb`

[test/models/flow_expiry_commit_test.rb](../../../test/models/flow_expiry_commit_test.rb); SHA-256: `98abdb8d9fd995d066dbd2c40384d262c3a27e9d1cb58664b2efe57d9bf629d8`.

File-level implementation candidates (including setup/import context): [app/models/client_sign_in_flow.rb:44](../../../app/models/client_sign_in_flow.rb#L44); [app/models/visitor_sign_in_flow.rb:44](../../../app/models/visitor_sign_in_flow.rb#L44); [app/models/operator_sign_in_flow.rb:44](../../../app/models/operator_sign_in_flow.rb#L44); [app/models/concerns/flow_base.rb:10](../../../app/models/concerns/flow_base.rb#L10).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07440"></a>T-07440 / [8](../../../test/models/flow_expiry_commit_test.rb#L8) | "standalone sign-in expiry commits before raising in every realm"<br>Owner: `FlowExpiryCommitTest` | `assert_not model.lease_connection.transaction_open?`; `assert_raises(FlowInvalidTransition) { flow.complete_sign_in! }`; `assert_predicate model.find(flow.id), :sign_in_expired?` | [ClientSignInFlow](../../../app/models/client_sign_in_flow.rb#L44); [VisitorSignInFlow](../../../app/models/visitor_sign_in_flow.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07441"></a>T-07441 / [26](../../../test/models/flow_expiry_commit_test.rb#L26) | "expiry ownership follows the writer transaction when the caller temporarily selects reading"<br>Owner: `FlowExpiryCommitTest` | `assert_predicate outcome, :expired?`; `assert_predicate model.find(flow.id), :sign_in_expired?`; `assert_raises(FlowInvalidTransition) { outcome.value! }` | [ClientSignInFlow](../../../app/models/client_sign_in_flow.rb#L44); [VisitorSignInFlow](../../../app/models/visitor_sign_in_flow.rb#L44) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
