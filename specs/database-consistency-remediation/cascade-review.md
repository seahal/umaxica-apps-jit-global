# Foreign-key cascade review

Read-only review against the original full catalog, current association declarations and the default
3.0.16 checker implementation. All eight findings remain open; no cascade/dependent change is made.

| Parent / association                                          | Child connection                   | Actual selected FK                                                                 | Assessment                                                                                                                     |
| ------------------------------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| VisitorToken.visitor_verifications                            | op_base_com                        | visitor_token_id -> visitor_tokens, NO ACTION                                      | Same-DB mismatch between model delete_all and raw deletion; verify token verification retention before any change              |
| VisitorPrivacyRequest.visitor_processor_erasure_notifications | com_zenith                         | visitor_privacy_request_id -> visitor_privacy_requests, NO ACTION                  | Notification delivery/receipt history; preserve until retention decision                                                       |
| ClientPrivacyRequest.client_processor_erasure_notifications   | app_zenith                         | client_privacy_request_id -> client_privacy_requests, NO ACTION                    | Notification delivery/receipt history; preserve until retention decision                                                       |
| VisitorWithdrawalFlow.visitor_withdrawal_flow_events          | com_zenith                         | visitor_withdrawal_flow_id -> visitor_withdrawal_flows, NO ACTION                  | Lifecycle event history; model and raw deletion differ, not permission to cascade                                              |
| ClientWithdrawalFlow.client_withdrawal_flow_events            | app_zenith                         | client_withdrawal_flow_id -> client_withdrawal_flows, NO ACTION                    | Lifecycle event history; model and raw deletion differ, not permission to cascade                                              |
| Visitor.visitor_withdrawal_ceremonies                         | com_zenith                         | visitor_id -> visitors, NO ACTION                                                  | Withdrawal/session lifecycle requires retention review                                                                         |
| Client.client_withdrawal_ceremonies                           | app_zenith                         | client_id -> clients, NO ACTION                                                    | Withdrawal/session lifecycle requires retention review                                                                         |
| Visitor.visitor_tokens                                        | op_base_com (parent is com_zenith) | (visitor_id,device_session_id) -> visitor_device_sessions(visitor_id,id), RESTRICT | Checker selects an unrelated composite FK by column containment across a DB boundary; no FK to visitors exists in the child DB |

`ForeignKeyCascadeChecker#foreign_key` matches only whether association FK columns are contained in
a child FK's columns. It does not compare the FK target table, full referenced primary-key tuple or
actual parent/child database. Consequently its Visitor.visitor_tokens claim does not describe a
missing cascade to Visitor. Correcting the application to satisfy that selected FK would change the
stable device-session boundary. Retain the report and document checker limitations; no checker
configuration/source change is used to hide it.

The other seven are genuine differences in deletion semantics, but neither raw deletion equivalence
nor automatic data loss is an established requirement. Current withdrawal/privacy documentation
retains history, legal holds and processor attempt outcomes, and self-service withdrawal does not
physically delete the account. These contracts must be evaluated through public deletion/retention
operations before choosing policy. Review is not proof that parent destruction is permissible.
