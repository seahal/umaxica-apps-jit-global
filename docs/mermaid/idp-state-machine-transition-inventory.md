# Current transition inventory

Static code and test-reading evidence only. Tests were not executed. Model-permitted edges are explicitly distinguished from wired orchestration. Expiry predicates do not imply persisted EXPIRED writes.

## idp-client-sign-in

Implementation: `FlowSignIn / participants / LocalAuthenticationSessionCommitter`. Storage: `client_sign_in_flows` / `status_id`.

Sources: `app/models/client_sign_in_flow.rb`, `app/models/client_sign_in_flow_status.rb`, `app/models/concerns/flow_sign_in.rb`, `app/models/concerns/sign_flow.rb`, `app/services/sign_in_state_machine.rb`, `app/services/sign_in_cycle_locator.rb`, `app/controllers/concerns/authentication_sequence_gate.rb`, `app/controllers/concerns/authentication_base.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/services/sign_in/post_issuance_participants_test.rb`, `test/controllers/auth/app/sign_ins_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-sign-in:T001 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_mfa! | MFA_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T002 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T003 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T004 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T005 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T006 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T007 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T008 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | advance_sign_in_to_checkpoint! | CHECKPOINT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T009 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | advance_sign_in_to_selector! | SELECTOR_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T010 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | advance_sign_in_to_session_issuance! | SESSION_ISSUANCE_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T011 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | advance_sign_in_to_return! | RETURN_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T012 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T013 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T014 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T015 | DOCUMENTED_TRANSITION | RETURN_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T016 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T017 | DOCUMENTED_TRANSITION | MFA_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T018 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T019 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T020 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T021 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T022 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T023 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T024 | DOCUMENTED_TRANSITION | RETURN_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-client-sign-in:T025 | OUT_OF_BAND | SELECTOR_PENDING | AuthenticationSequenceGate direct update legacy path | DASHBOARD_PENDING | Legacy participant completed checkpoint/selector; direct update! no named transition guard | status/state/step dashboard | app/controllers/concerns/authentication_sequence_gate.rb | CONFIRMED |
| idp-client-sign-in:T026 | DOCUMENTED_TRANSITION | MFA_PENDING | cancel_pending_mfa | FAILED | Matching pending principal/flow and live named transition guard | Fail flow; clear pending MFA/session carrier | app/controllers/concerns/authentication_base.rb | CONFIRMED |
| idp-client-sign-in:T027 | DOCUMENTED_TRANSITION | Any pending app status with FAILED in its model map | expire_sign_in! via Secret claim reconciliation | FAILED | Writer DB deadline reached; no issued session or token; same Ticket row lock as issuance; completed login immutable | Synchronize status/state/step without extending admission; source retirement separately audits flow_expired | app/models/client_sign_in_flow.rb; app/operations/client_secret_claim_finalizer.rb | CONFIRMED |
| idp-client-sign-in:T028 | INITIALIZATION | absent | ClientSecretClaimCommitter.bind_oidc_flow! | PRIMARY_PENDING | Saved complete value; Client lock; locked pending app OIDC transaction; matching admitted active browser ceremony; all writer deadlines valid | Server-issued flow bound uniquely to OIDC transaction; retries reuse; no claim, proof or token | app/operations/client_secret_claim_committer.rb | CONFIRMED |

Terminal storage states are COMPLETED (100) and FAILED (900). Expiry is a predicate (`expires_at <= now`), not an EXPIRED status write; no cancel status/event exists. Expired flows disappear from `SignInCycleLocator.current`. Named methods use FlowBase locks, but `transition_to!` checks its model transition map before entering the locked write. `complete_sign_in!` permits SESSION_LIMIT_PENDING/DASHBOARD_PENDING → COMPLETED although the model TRANSITIONS map does not. These are real public method edges, not invented map edges.

`SignInStateMachine` contains result classifiers and PRIMARY_VERIFIED_TRANSITIONS metadata only. `session_limit_hard_reject`, `guardrail_blocked`, `credential_failed`, etc. are results, not stored states. Participant blockers normally preserve the current state. New paths use selector before issuance; DASHBOARD_PENDING and RETURN_PENDING are legacy states with no incoming DASHBOARD_PENDING edge in the model map, but AuthenticationSequenceGate directly writes SELECTOR_PENDING to DASHBOARD_PENDING after the checkpoint participant. `advance_sign_in_to_dashboard!` actually calls complete_sign_in! with step dashboard; current model STEP_BY_STATUS_ID validation maps COMPLETED to completed (the historical migration CHECK is absent from current checked-in structure), so this public helper has a static constraint mismatch (not repaired).

External boundaries: Auth records authentication evidence; LocalAuthenticationResultCoordinator advances guardrail/checkpoint/selector, then Base LocalAuthenticationSessionCommitter invokes root login and finalizes. SESSION_ISSUANCE_PENDING → SESSION_LIMIT_PENDING is the explicit final capacity recheck, before successful session commit. Token/finalization evidence is an additional axis, not a backward edge after durable issuance.

Direct writes outside transitions include `authentication_sequence_gate.rb` (legacy state/step/status update) and `credential_security_transition.rb` (calls fail_sign_in! and directly expires result delivery). `authentication_base.rb` records token/session evidence and calls named transitions. Storage duplicates status_id, state and step; model STEP_BY_STATUS_ID validations and model validations align them, including COMPLETED step. See mutation index for exact locations. Tests read cover participant rejection, selector binding, legacy dashboard/return, admission refusal and finalization replay; no test execution is claimed.

## idp-visitor-sign-in

Implementation: `FlowSignIn / participants / LocalAuthenticationSessionCommitter`. Storage: `visitor_sign_in_flows` / `status_id`.

Sources: `app/models/visitor_sign_in_flow.rb`, `app/models/visitor_sign_in_flow_status.rb`, `app/models/concerns/flow_sign_in.rb`, `app/models/concerns/sign_flow.rb`, `app/services/sign_in_state_machine.rb`, `app/services/sign_in_cycle_locator.rb`, `app/controllers/concerns/authentication_sequence_gate.rb`, `app/controllers/concerns/authentication_base.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/services/sign_in/post_issuance_participants_test.rb`, `test/controllers/auth/com/sign_ins_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-sign-in:T001 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_mfa! | MFA_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T002 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T003 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T004 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T005 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T006 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T007 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T008 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | advance_sign_in_to_checkpoint! | CHECKPOINT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T009 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | advance_sign_in_to_selector! | SELECTOR_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T010 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | advance_sign_in_to_session_issuance! | SESSION_ISSUANCE_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T011 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | advance_sign_in_to_return! | RETURN_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T012 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T013 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T014 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T015 | DOCUMENTED_TRANSITION | RETURN_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T016 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T017 | DOCUMENTED_TRANSITION | MFA_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T018 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T019 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T020 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T021 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T022 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T023 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T024 | DOCUMENTED_TRANSITION | RETURN_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-visitor-sign-in:T025 | OUT_OF_BAND | SELECTOR_PENDING | AuthenticationSequenceGate direct update legacy path | DASHBOARD_PENDING | Legacy participant completed checkpoint/selector; direct update! no named transition guard | status/state/step dashboard | app/controllers/concerns/authentication_sequence_gate.rb | CONFIRMED |
| idp-visitor-sign-in:T026 | DOCUMENTED_TRANSITION | MFA_PENDING | cancel_pending_mfa | FAILED | Matching pending principal/flow and live named transition guard | Fail flow; clear pending MFA/session carrier | app/controllers/concerns/authentication_base.rb | CONFIRMED |

Terminal storage states are COMPLETED (100) and FAILED (900). Expiry is a predicate (`expires_at <= now`), not an EXPIRED status write; no cancel status/event exists. Expired flows disappear from `SignInCycleLocator.current`. Named methods use FlowBase locks, but `transition_to!` checks its model transition map before entering the locked write. `complete_sign_in!` permits SESSION_LIMIT_PENDING/DASHBOARD_PENDING → COMPLETED although the model TRANSITIONS map does not. These are real public method edges, not invented map edges.

`SignInStateMachine` contains result classifiers and PRIMARY_VERIFIED_TRANSITIONS metadata only. `session_limit_hard_reject`, `guardrail_blocked`, `credential_failed`, etc. are results, not stored states. Participant blockers normally preserve the current state. New paths use selector before issuance; DASHBOARD_PENDING and RETURN_PENDING are legacy states with no incoming DASHBOARD_PENDING edge in the model map, but AuthenticationSequenceGate directly writes SELECTOR_PENDING to DASHBOARD_PENDING after the checkpoint participant. `advance_sign_in_to_dashboard!` actually calls complete_sign_in! with step dashboard; current model STEP_BY_STATUS_ID validation maps COMPLETED to completed (the historical migration CHECK is absent from current checked-in structure), so this public helper has a static constraint mismatch (not repaired).

External boundaries: Auth records authentication evidence; LocalAuthenticationResultCoordinator advances guardrail/checkpoint/selector, then Base LocalAuthenticationSessionCommitter invokes root login and finalizes. SESSION_ISSUANCE_PENDING → SESSION_LIMIT_PENDING is the explicit final capacity recheck, before successful session commit. Token/finalization evidence is an additional axis, not a backward edge after durable issuance.

Direct writes outside transitions include `authentication_sequence_gate.rb` (legacy state/step/status update) and `credential_security_transition.rb` (calls fail_sign_in! and directly expires result delivery). `authentication_base.rb` records token/session evidence and calls named transitions. Storage duplicates status_id, state and step; model STEP_BY_STATUS_ID validations and model validations align them, including COMPLETED step. See mutation index for exact locations. Tests read cover participant rejection, selector binding, legacy dashboard/return, admission refusal and finalization replay; no test execution is claimed.

## idp-operator-sign-in

Implementation: `FlowSignIn / participants / LocalAuthenticationSessionCommitter`. Storage: `operator_sign_in_flows` / `status_id`.

Sources: `app/models/operator_sign_in_flow.rb`, `app/models/operator_sign_in_flow_status.rb`, `app/models/concerns/flow_sign_in.rb`, `app/models/concerns/sign_flow.rb`, `app/services/sign_in_state_machine.rb`, `app/services/sign_in_cycle_locator.rb`, `app/controllers/concerns/authentication_sequence_gate.rb`, `app/controllers/concerns/authentication_base.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/services/sign_in/post_issuance_participants_test.rb`, `test/controllers/auth/org/sign_ins_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-sign-in:T001 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_mfa! | MFA_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T002 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T003 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T004 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | advance_sign_in_to_session_limit! | SESSION_LIMIT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T005 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T006 | DOCUMENTED_TRANSITION | MFA_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T007 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | advance_sign_in_to_guardrail! | GUARDRAIL_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T008 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | advance_sign_in_to_checkpoint! | CHECKPOINT_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T009 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | advance_sign_in_to_selector! | SELECTOR_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T010 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | advance_sign_in_to_session_issuance! | SESSION_ISSUANCE_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T011 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | advance_sign_in_to_return! | RETURN_PENDING | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T012 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T013 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T014 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T015 | DOCUMENTED_TRANSITION | RETURN_PENDING | complete_sign_in! | COMPLETED | Allowed source; accessible; unexpired; row lock | completed_at; state COMPLETED; step argument | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T016 | DOCUMENTED_TRANSITION | PRIMARY_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T017 | DOCUMENTED_TRANSITION | MFA_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T018 | DOCUMENTED_TRANSITION | SESSION_LIMIT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T019 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T020 | DOCUMENTED_TRANSITION | SESSION_ISSUANCE_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T021 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T022 | DOCUMENTED_TRANSITION | SELECTOR_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T023 | DOCUMENTED_TRANSITION | DASHBOARD_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T024 | DOCUMENTED_TRANSITION | RETURN_PENDING | fail_sign_in! | FAILED | Allowed source; accessible; unexpired; row lock | Synchronize status_id/state/step | app/models/concerns/flow_sign_in.rb | CONFIRMED |
| idp-operator-sign-in:T025 | OUT_OF_BAND | SELECTOR_PENDING | AuthenticationSequenceGate direct update legacy path | DASHBOARD_PENDING | Legacy participant completed checkpoint/selector; direct update! no named transition guard | status/state/step dashboard | app/controllers/concerns/authentication_sequence_gate.rb | CONFIRMED |
| idp-operator-sign-in:T026 | DOCUMENTED_TRANSITION | MFA_PENDING | cancel_pending_mfa | FAILED | Matching pending principal/flow and live named transition guard | Fail flow; clear pending MFA/session carrier | app/controllers/concerns/authentication_base.rb | CONFIRMED |

Terminal storage states are COMPLETED (100) and FAILED (900). Expiry is a predicate (`expires_at <= now`), not an EXPIRED status write; no cancel status/event exists. Expired flows disappear from `SignInCycleLocator.current`. Named methods use FlowBase locks, but `transition_to!` checks its model transition map before entering the locked write. `complete_sign_in!` permits SESSION_LIMIT_PENDING/DASHBOARD_PENDING → COMPLETED although the model TRANSITIONS map does not. These are real public method edges, not invented map edges.

`SignInStateMachine` contains result classifiers and PRIMARY_VERIFIED_TRANSITIONS metadata only. `session_limit_hard_reject`, `guardrail_blocked`, `credential_failed`, etc. are results, not stored states. Participant blockers normally preserve the current state. New paths use selector before issuance; DASHBOARD_PENDING and RETURN_PENDING are legacy states with no incoming DASHBOARD_PENDING edge in the model map, but AuthenticationSequenceGate directly writes SELECTOR_PENDING to DASHBOARD_PENDING after the checkpoint participant. `advance_sign_in_to_dashboard!` actually calls complete_sign_in! with step dashboard; current model STEP_BY_STATUS_ID validation maps COMPLETED to completed (the historical migration CHECK is absent from current checked-in structure), so this public helper has a static constraint mismatch (not repaired).

External boundaries: Auth records authentication evidence; LocalAuthenticationResultCoordinator advances guardrail/checkpoint/selector, then Base LocalAuthenticationSessionCommitter invokes root login and finalizes. SESSION_ISSUANCE_PENDING → SESSION_LIMIT_PENDING is the explicit final capacity recheck, before successful session commit. Token/finalization evidence is an additional axis, not a backward edge after durable issuance.

Direct writes outside transitions include `authentication_sequence_gate.rb` (legacy state/step/status update) and `credential_security_transition.rb` (calls fail_sign_in! and directly expires result delivery). `authentication_base.rb` records token/session evidence and calls named transitions. Storage duplicates status_id, state and step; model STEP_BY_STATUS_ID validations and model validations align them, including COMPLETED step. See mutation index for exact locations. Tests read cover participant rejection, selector binding, legacy dashboard/return, admission refusal and finalization replay; no test execution is claimed.

## idp-client-sign-up

Implementation: `SignUpStateMachine + SignFlow / FlowSignUp`. Storage: `client_sign_up_flows` / `status_id`.

Sources: `app/models/client_sign_up_flow.rb`, `app/models/client_sign_up_flow_status.rb`, `app/services/sign_up_state_machine.rb`, `app/models/concerns/sign_flow.rb`, `app/models/concerns/sign_up_flow_ticket.rb`, `app/jobs/sign_up_expiry_job.rb`, `app/services/sign_up_termination.rb`.

Tests read: `test/services/sign_up/state_machine_test.rb`, `test/services/sign_up_expiry_race_test.rb`, `test/services/sign_up_termination_idempotence_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-sign-up:T001 | DOCUMENTED_TRANSITION | STARTED | submit_contact | CONTACT_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T002 | DOCUMENTED_TRANSITION | STARTED | advance_sign_up_to_credential! / model map | CREDENTIAL_PENDING | Public helper; state synchronization mismatch noted below | status_id/state/step; terminal timestamp when defined | app/models/concerns/flow_sign_up.rb | CONFIRMED |
| idp-client-sign-up:T003 | DOCUMENTED_TRANSITION | STARTED | start_social_callback | SOCIAL_CALLBACK_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T004 | DOCUMENTED_TRANSITION | STARTED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T005 | DOCUMENTED_TRANSITION | STARTED | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T006 | DOCUMENTED_TRANSITION | STARTED | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T007 | DOCUMENTED_TRANSITION | CONTACT_PENDING | advance_sign_up_to_credential! / model map | CREDENTIAL_PENDING | Public helper; state synchronization mismatch noted below | status_id/state/step; terminal timestamp when defined | app/models/concerns/flow_sign_up.rb | CONFIRMED |
| idp-client-sign-up:T008 | DOCUMENTED_TRANSITION | CONTACT_PENDING | verify_contact | CONTACT_VERIFIED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T009 | DOCUMENTED_TRANSITION | CONTACT_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T010 | DOCUMENTED_TRANSITION | CONTACT_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T011 | DOCUMENTED_TRANSITION | CONTACT_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T012 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | verify_contact | CONTACT_VERIFIED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T013 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T014 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T015 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T016 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | enter_guardrail | GUARDRAIL_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T017 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T018 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T019 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T020 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | transition_to! model-permitted | CONTACT_VERIFIED | Caller reachability UNCONFIRMED | status_id/state/step; terminal timestamp when defined | app/models/client_sign_up_flow.rb | CONFIRMED |
| idp-client-sign-up:T021 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | transition_to! model-permitted | GUARDRAIL_PENDING | Caller reachability UNCONFIRMED | status_id/state/step; terminal timestamp when defined | app/models/client_sign_up_flow.rb | CONFIRMED |
| idp-client-sign-up:T022 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | complete_social_callback new identity | CHECKPOINT_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T023 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T024 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T025 | DOCUMENTED_TRANSITION | SOCIAL_CALLBACK_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T026 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | enter_checkpoint | CHECKPOINT_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T027 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T028 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T029 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T030 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | finalize accepted | FINALIZING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T031 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T032 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T033 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T034 | DOCUMENTED_TRANSITION | FINALIZING | finalize accepted | FINALIZED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T035 | DOCUMENTED_TRANSITION | FINALIZING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T036 | DOCUMENTED_TRANSITION | FINALIZED | handoff_to_sign_in accepted | SIGN_IN_HANDOFF_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T037 | DOCUMENTED_TRANSITION | FINALIZED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T038 | DOCUMENTED_TRANSITION | SIGN_IN_HANDOFF_PENDING | complete | COMPLETED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T039 | DOCUMENTED_TRANSITION | SIGN_IN_HANDOFF_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-client-sign-up:T040 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | clear_requirement | CHECKPOINT_PENDING | Matching checkpoint_version; in-order uncleared registry requirement | completed_requirements; checkpoint_version +1 | app/services/sign_up_state_machine.rb | CONFIRMED |

COMPLETED=100, FAILED=900, EXPIRED=910, CANCELLED=920 are current terminal ids. `start` returns ok without a state write, and terminal `start` is allowed; it does not reopen the flow. cancel is allowed only through CHECKPOINT_PENDING and replay on CANCELLED is idempotent. `complete_social_callback(sign_in_handoff:)` can return a handoff result without changing status; it is not a FINALIZED edge. Social transitions exist only for client/app; visitor has no social status.

`finalize` requires all registry requirements plus accepted finalization_result; it writes FINALIZING then FINALIZED. Missing result is blocked; nonaccepted result returns failed/cleanup_required without moving to FAILED. `handoff_to_sign_in` accepts only FINALIZED: accepted writes HANDOFF_PENDING; stopped/failed leave FINALIZED intact. Thus result failure and stored FAILED differ, and stranded FINALIZING/FINALIZED/HANDOFF_PENDING have no cancel/expire model edge. SignUpExpiryJob nevertheless selects all in-progress ids; its explicit expire can be rejected by TRANSITIONS after FINALIZING. Expired/lapsed events normally return expired without persisting EXPIRED; raw `transition_to!` itself checks the map but not TTL, while named FlowBase methods check TTL. These are static observations, not runtime proof.

`SignUpTermination` wraps cancel/expire/fail, schedules retention, writes cleanup_status_id and runs compensation; calling the raw state machine skips those effects. checkpoint clearing locks the entire decision and rejects stale replay/version; requirement clearing is state-preserving. Direct creation and legacy writes are recorded in the mutation index, including `base/app/controllers/base/app/social/authentication/completions_controller.rb` writing SOCIAL_CALLBACK_PENDING, and FlowSignUp helper methods writing status/step without synchronizing a populated state. Tests read cover contact/social, ordering, stale version, finalize blocked/accepted, failed handoff, cancel-after-finalizing rejection, cancel replay and expiry race. No extra expiry or back edge is inferred.

## idp-visitor-sign-up

Implementation: `SignUpStateMachine + SignFlow / FlowSignUp`. Storage: `visitor_sign_up_flows` / `status_id`.

Sources: `app/models/visitor_sign_up_flow.rb`, `app/models/visitor_sign_up_flow_status.rb`, `app/services/sign_up_state_machine.rb`, `app/models/concerns/sign_flow.rb`, `app/models/concerns/sign_up_flow_ticket.rb`, `app/jobs/sign_up_expiry_job.rb`, `app/services/sign_up_termination.rb`.

Tests read: `test/services/sign_up/state_machine_test.rb`, `test/services/sign_up_expiry_race_test.rb`, `test/services/sign_up_termination_idempotence_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-sign-up:T001 | DOCUMENTED_TRANSITION | STARTED | submit_contact | CONTACT_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T002 | DOCUMENTED_TRANSITION | STARTED | advance_sign_up_to_credential! / model map | CREDENTIAL_PENDING | Public helper; state synchronization mismatch noted below | status_id/state/step; terminal timestamp when defined | app/models/concerns/flow_sign_up.rb | CONFIRMED |
| idp-visitor-sign-up:T003 | DOCUMENTED_TRANSITION | STARTED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T004 | DOCUMENTED_TRANSITION | STARTED | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T005 | DOCUMENTED_TRANSITION | STARTED | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T006 | DOCUMENTED_TRANSITION | CONTACT_PENDING | advance_sign_up_to_credential! / model map | CREDENTIAL_PENDING | Public helper; state synchronization mismatch noted below | status_id/state/step; terminal timestamp when defined | app/models/concerns/flow_sign_up.rb | CONFIRMED |
| idp-visitor-sign-up:T007 | DOCUMENTED_TRANSITION | CONTACT_PENDING | verify_contact | CONTACT_VERIFIED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T008 | DOCUMENTED_TRANSITION | CONTACT_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T009 | DOCUMENTED_TRANSITION | CONTACT_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T010 | DOCUMENTED_TRANSITION | CONTACT_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T011 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | verify_contact | CONTACT_VERIFIED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T012 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T013 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T014 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T015 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | enter_guardrail | GUARDRAIL_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T016 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T017 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T018 | DOCUMENTED_TRANSITION | CONTACT_VERIFIED | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T019 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | enter_checkpoint | CHECKPOINT_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T020 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T021 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T022 | DOCUMENTED_TRANSITION | GUARDRAIL_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T023 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | finalize accepted | FINALIZING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T024 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T025 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | expire | EXPIRED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T026 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | cancel | CANCELLED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T027 | DOCUMENTED_TRANSITION | FINALIZING | finalize accepted | FINALIZED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T028 | DOCUMENTED_TRANSITION | FINALIZING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T029 | DOCUMENTED_TRANSITION | FINALIZED | handoff_to_sign_in accepted | SIGN_IN_HANDOFF_PENDING | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T030 | DOCUMENTED_TRANSITION | FINALIZED | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T031 | DOCUMENTED_TRANSITION | SIGN_IN_HANDOFF_PENDING | complete | COMPLETED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T032 | DOCUMENTED_TRANSITION | SIGN_IN_HANDOFF_PENDING | fail | FAILED | Model map; event-specific guard below | status_id/state/step; terminal timestamp when defined | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-visitor-sign-up:T033 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | clear_requirement | CHECKPOINT_PENDING | Matching checkpoint_version; in-order uncleared registry requirement | completed_requirements; checkpoint_version +1 | app/services/sign_up_state_machine.rb | CONFIRMED |

COMPLETED=100, FAILED=900, EXPIRED=910, CANCELLED=920 are current terminal ids. `start` returns ok without a state write, and terminal `start` is allowed; it does not reopen the flow. cancel is allowed only through CHECKPOINT_PENDING and replay on CANCELLED is idempotent. `complete_social_callback(sign_in_handoff:)` can return a handoff result without changing status; it is not a FINALIZED edge. Social transitions exist only for client/app; visitor has no social status.

`finalize` requires all registry requirements plus accepted finalization_result; it writes FINALIZING then FINALIZED. Missing result is blocked; nonaccepted result returns failed/cleanup_required without moving to FAILED. `handoff_to_sign_in` accepts only FINALIZED: accepted writes HANDOFF_PENDING; stopped/failed leave FINALIZED intact. Thus result failure and stored FAILED differ, and stranded FINALIZING/FINALIZED/HANDOFF_PENDING have no cancel/expire model edge. SignUpExpiryJob nevertheless selects all in-progress ids; its explicit expire can be rejected by TRANSITIONS after FINALIZING. Expired/lapsed events normally return expired without persisting EXPIRED; raw `transition_to!` itself checks the map but not TTL, while named FlowBase methods check TTL. These are static observations, not runtime proof.

`SignUpTermination` wraps cancel/expire/fail, schedules retention, writes cleanup_status_id and runs compensation; calling the raw state machine skips those effects. checkpoint clearing locks the entire decision and rejects stale replay/version; requirement clearing is state-preserving. Direct creation and legacy writes are recorded in the mutation index, including `base/app/controllers/base/app/social/authentication/completions_controller.rb` writing SOCIAL_CALLBACK_PENDING, and FlowSignUp helper methods writing status/step without synchronizing a populated state. Tests read cover contact/social, ordering, stale version, finalize blocked/accepted, failed handoff, cancel-after-finalizing rejection, cancel replay and expiry race. No extra expiry or back edge is inferred.

## idp-operator-sign-up

Implementation: `FlowSignUp (model only)`. Storage: `operator_sign_up_flows` / `status_id`.

Sources: `app/models/operator_sign_up_flow.rb`, `app/models/operator_sign_up_flow_status.rb`, `app/models/concerns/flow_sign_up.rb`, `app/models/concerns/sign_flow.rb`, `app/models/concerns/sign_up_flow_ticket.rb`, `app/jobs/sign_up_expiry_job.rb`, `app/services/sign_up_termination.rb`.

Tests read: `test/models/operator_sign_up_flow_test.rb`, `test/controllers/auth/org/sign_ups_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-sign-up:T001 | DOCUMENTED_TRANSITION | STARTED | advance_sign_up_to_contact! | CONTACT_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T002 | DOCUMENTED_TRANSITION | STARTED | advance_sign_up_to_credential! | CREDENTIAL_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T003 | DOCUMENTED_TRANSITION | CONTACT_PENDING | advance_sign_up_to_credential! | CREDENTIAL_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T004 | DOCUMENTED_TRANSITION | STARTED | advance_sign_up_to_checkpoint! | CHECKPOINT_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T005 | DOCUMENTED_TRANSITION | CONTACT_PENDING | advance_sign_up_to_checkpoint! | CHECKPOINT_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T006 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | advance_sign_up_to_checkpoint! | CHECKPOINT_PENDING | Model-permitted source; serialized decision | status_id/state/step write | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T007 | DOCUMENTED_TRANSITION | STARTED | complete_sign_up! | COMPLETED | Model-permitted source; serialized decision | completed_at/step; state is NOT assigned by FlowSignUp | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T008 | DOCUMENTED_TRANSITION | CONTACT_PENDING | complete_sign_up! | COMPLETED | Model-permitted source; serialized decision | completed_at/step; state is NOT assigned by FlowSignUp | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T009 | DOCUMENTED_TRANSITION | CREDENTIAL_PENDING | complete_sign_up! | COMPLETED | Model-permitted source; serialized decision | completed_at/step; state is NOT assigned by FlowSignUp | app/services/sign_up_state_machine.rb | CONFIRMED |
| idp-operator-sign-up:T010 | DOCUMENTED_TRANSITION | CHECKPOINT_PENDING | complete_sign_up! | COMPLETED | Model-permitted source; serialized decision | completed_at/step; state is NOT assigned by FlowSignUp | app/services/sign_up_state_machine.rb | CONFIRMED |

This is an existing model machine, not the app/com SignUpStateMachine path. Reference table has only STARTED/CONTACT_PENDING/CREDENTIAL_PENDING/CHECKPOINT_PENDING/COMPLETED. No FAILED/EXPIRED/CANCELLED ids, no persisted expiry/cancel path. FlowSignUp updates status_id and step but does not update state; SignFlow only fills state when blank and validates it against status_id, so a persisted nonblank legacy state can reject named transitions. The operator model test uses synthetic FlowSignUpTestRecord with different terminal ids and no real operator schema validation; it proves concern behavior, not an operational operator signup route. Current `Auth::Org::Sign::UpsController` includes SignUpSuspensionGuard and has no operator flow transition calls, so HTTP entry reachability is UNCONFIRMED. Operator onboarding invitation acceptance is a separate machine. No normalization to target vocabulary is made.

## idp-client-sign-out

Implementation: `FlowSignOut / AuthenticationLogoutCurrentSession`. Storage: `client_sign_out_flows` / `status_id`.

Sources: `app/models/client_sign_out_flow.rb`, `app/models/client_sign_out_flow_status.rb`, `app/models/concerns/flow_sign_out.rb`, `app/models/concerns/sign_out_flow.rb`, `app/controllers/concerns/authentication_logout_current_session.rb`, `app/controllers/concerns/sign_out_cancellation.rb`.

Tests read: `test/models/sign_out_flow_test.rb`, `test/controllers/base/app/sign_outs_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-sign-out:T001 | DOCUMENTED_TRANSITION | NOTHING | request_sign_out! | REQUESTED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T002 | DOCUMENTED_TRANSITION | REQUESTED | mark_access_discarded! | ACCESS_DISCARDED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T003 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | mark_logically_revoked! | LOGICALLY_REVOKED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T004 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | await_sign_out_expiry! | AWAITING_EXPIRY | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T005 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | complete_sign_out! | COMPLETED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T006 | DOCUMENTED_TRANSITION | REQUESTED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T007 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T008 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-client-sign-out:T009 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |

Default is REQUESTED=10; NOTHING=0 is a supported model-only predecessor. COMPLETED=100 and FAILED=900 are stored terminals. There is no state or step string column and no flow expires_at. access_expires_at/refresh_expires_at describe token timing and their order; AWAITING_EXPIRY is not EXPIRED. `AuthenticationLogoutCurrentSession` advances through awaiting expiry and immediately calls complete_sign_out! in the same request, without waiting for refresh TTL. Token/cookie revocation is the durable boundary. Failure recovery reloads and fails an incomplete cycle.

`SignOutFlow.transition_to!` checks the model map and performs update! without a row lock, unlike the FlowSignOut named APIs; stale direct use is a possible concurrency boundary, not a demonstrated failure. Replay uses a recent COMPLETED row to suppress duplicate logout. UI cancellation in SignOutCancellation deletes pending request/session/notice context before a durable flow is committed; it is not a CANCELLED table state. Auth and RP return boundaries exist in controllers, but no external_result event exists in this model. Tests read verify progression, reverse rejection, defaults, integer transitions, retention and completion timestamps.

## idp-visitor-sign-out

Implementation: `FlowSignOut / AuthenticationLogoutCurrentSession`. Storage: `visitor_sign_out_flows` / `status_id`.

Sources: `app/models/visitor_sign_out_flow.rb`, `app/models/visitor_sign_out_flow_status.rb`, `app/models/concerns/flow_sign_out.rb`, `app/models/concerns/sign_out_flow.rb`, `app/controllers/concerns/authentication_logout_current_session.rb`, `app/controllers/concerns/sign_out_cancellation.rb`.

Tests read: `test/models/sign_out_flow_test.rb`, `test/controllers/base/com/sign_outs_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-sign-out:T001 | DOCUMENTED_TRANSITION | NOTHING | request_sign_out! | REQUESTED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T002 | DOCUMENTED_TRANSITION | REQUESTED | mark_access_discarded! | ACCESS_DISCARDED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T003 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | mark_logically_revoked! | LOGICALLY_REVOKED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T004 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | await_sign_out_expiry! | AWAITING_EXPIRY | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T005 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | complete_sign_out! | COMPLETED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T006 | DOCUMENTED_TRANSITION | REQUESTED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T007 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T008 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-visitor-sign-out:T009 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |

Default is REQUESTED=10; NOTHING=0 is a supported model-only predecessor. COMPLETED=100 and FAILED=900 are stored terminals. There is no state or step string column and no flow expires_at. access_expires_at/refresh_expires_at describe token timing and their order; AWAITING_EXPIRY is not EXPIRED. `AuthenticationLogoutCurrentSession` advances through awaiting expiry and immediately calls complete_sign_out! in the same request, without waiting for refresh TTL. Token/cookie revocation is the durable boundary. Failure recovery reloads and fails an incomplete cycle.

`SignOutFlow.transition_to!` checks the model map and performs update! without a row lock, unlike the FlowSignOut named APIs; stale direct use is a possible concurrency boundary, not a demonstrated failure. Replay uses a recent COMPLETED row to suppress duplicate logout. UI cancellation in SignOutCancellation deletes pending request/session/notice context before a durable flow is committed; it is not a CANCELLED table state. Auth and RP return boundaries exist in controllers, but no external_result event exists in this model. Tests read verify progression, reverse rejection, defaults, integer transitions, retention and completion timestamps.

## idp-operator-sign-out

Implementation: `FlowSignOut / AuthenticationLogoutCurrentSession`. Storage: `operator_sign_out_flows` / `status_id`.

Sources: `app/models/operator_sign_out_flow.rb`, `app/models/operator_sign_out_flow_status.rb`, `app/models/concerns/flow_sign_out.rb`, `app/models/concerns/sign_out_flow.rb`, `app/controllers/concerns/authentication_logout_current_session.rb`, `app/controllers/concerns/sign_out_cancellation.rb`.

Tests read: `test/models/sign_out_flow_test.rb`, `test/controllers/base/org/sign_outs_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-sign-out:T001 | DOCUMENTED_TRANSITION | NOTHING | request_sign_out! | REQUESTED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T002 | DOCUMENTED_TRANSITION | REQUESTED | mark_access_discarded! | ACCESS_DISCARDED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T003 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | mark_logically_revoked! | LOGICALLY_REVOKED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T004 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | await_sign_out_expiry! | AWAITING_EXPIRY | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T005 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | complete_sign_out! | COMPLETED | Allowed source; accessible; FlowBase row lock | phase timestamp when defined | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T006 | DOCUMENTED_TRANSITION | REQUESTED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T007 | DOCUMENTED_TRANSITION | ACCESS_DISCARDED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T008 | DOCUMENTED_TRANSITION | LOGICALLY_REVOKED | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |
| idp-operator-sign-out:T009 | DOCUMENTED_TRANSITION | AWAITING_EXPIRY | fail_sign_out! | FAILED | Allowed source; accessible; row lock | failed_at | app/models/concerns/flow_sign_out.rb | CONFIRMED |

Default is REQUESTED=10; NOTHING=0 is a supported model-only predecessor. COMPLETED=100 and FAILED=900 are stored terminals. There is no state or step string column and no flow expires_at. access_expires_at/refresh_expires_at describe token timing and their order; AWAITING_EXPIRY is not EXPIRED. `AuthenticationLogoutCurrentSession` advances through awaiting expiry and immediately calls complete_sign_out! in the same request, without waiting for refresh TTL. Token/cookie revocation is the durable boundary. Failure recovery reloads and fails an incomplete cycle.

`SignOutFlow.transition_to!` checks the model map and performs update! without a row lock, unlike the FlowSignOut named APIs; stale direct use is a possible concurrency boundary, not a demonstrated failure. Replay uses a recent COMPLETED row to suppress duplicate logout. UI cancellation in SignOutCancellation deletes pending request/session/notice context before a durable flow is committed; it is not a CANCELLED table state. Auth and RP return boundaries exist in controllers, but no external_result event exists in this model. Tests read verify progression, reverse rejection, defaults, integer transitions, retention and completion timestamps.

## idp-client-sign-up-cleanup

Implementation: `SignUpTermination / SignUpArtifactCleanup`. Storage: `client_sign_up_flows` / `cleanup_status_id`.

Sources: `app/services/sign_up_artifact_cleanup.rb`, `app/services/sign_up_termination.rb`, `app/models/client_sign_up_flow_cleanup_status.rb`.

Tests read: `test/services/sign_up_artifact_cleanup_test.rb`, `test/services/sign_up_termination_idempotence_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-sign-up-cleanup:T001 | DOCUMENTED_TRANSITION | IDLE | SignUpTermination terminal retention | PENDING | Terminal sign-up reached | Schedule retention and cleanup | app/services/sign_up_termination.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T002 | DOCUMENTED_TRANSITION | FAILED | SignUpTermination replay / cleanup worker | PENDING | Not completed; worker attempts <10 | Increment attempts; clear error | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T003 | DOCUMENTED_TRANSITION | PENDING | cleanup successful | COMPLETED | Dependents logically discarded | cleanup_completed_at; clear error | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T004 | DOCUMENTED_TRANSITION | PENDING | cleanup exception | FAILED | ActiveRecordError or ArgumentError | bounded error; attempted_at | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T005 | DOCUMENTED_TRANSITION | PENDING | cleanup attempt | PENDING | Not completed | attempt count +1 | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T006 | OUT_OF_BAND | NOTHING | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T007 | OUT_OF_BAND | IDLE | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-sign-up-cleanup:T008 | OUT_OF_BAND | FAILED | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

Cleanup is an independent status_id axis on the sign-up fact row, not duplicate main flow state. NOTHING has no identified setter/caller. Public cleanup accepts any not-completed cleanup state, including IDLE/NOTHING if called directly; ordinary termination enqueues PENDING. Worker uses SKIP LOCKED, retries PENDING/FAILED only for CANCELLED/EXPIRED/FAILED main flows and stops at 10 attempts. FAILED is retryable until that cap, then operationally stranded without a new terminal id. Cross-database dependent updates are not atomic with the ticket DB; tests exercise failures and retry. No cancellation/expiry lifecycle of cleanup itself is implemented. Direct status writes are the implementation, not routed through the main SignUpStateMachine.

## idp-visitor-sign-up-cleanup

Implementation: `SignUpTermination / SignUpArtifactCleanup`. Storage: `visitor_sign_up_flows` / `cleanup_status_id`.

Sources: `app/services/sign_up_artifact_cleanup.rb`, `app/services/sign_up_termination.rb`, `app/models/visitor_sign_up_flow_cleanup_status.rb`.

Tests read: `test/services/sign_up_artifact_cleanup_test.rb`, `test/services/sign_up_termination_idempotence_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-sign-up-cleanup:T001 | DOCUMENTED_TRANSITION | IDLE | SignUpTermination terminal retention | PENDING | Terminal sign-up reached | Schedule retention and cleanup | app/services/sign_up_termination.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T002 | DOCUMENTED_TRANSITION | FAILED | SignUpTermination replay / cleanup worker | PENDING | Not completed; worker attempts <10 | Increment attempts; clear error | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T003 | DOCUMENTED_TRANSITION | PENDING | cleanup successful | COMPLETED | Dependents logically discarded | cleanup_completed_at; clear error | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T004 | DOCUMENTED_TRANSITION | PENDING | cleanup exception | FAILED | ActiveRecordError or ArgumentError | bounded error; attempted_at | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T005 | DOCUMENTED_TRANSITION | PENDING | cleanup attempt | PENDING | Not completed | attempt count +1 | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T006 | OUT_OF_BAND | NOTHING | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T007 | OUT_OF_BAND | IDLE | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-sign-up-cleanup:T008 | OUT_OF_BAND | FAILED | SignUpArtifactCleanup public call | PENDING | cleanup_supported? and not cleanup_completed?; cycle lock | Increment attempt count; record attempted time | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

Cleanup is an independent status_id axis on the sign-up fact row, not duplicate main flow state. NOTHING has no identified setter/caller. Public cleanup accepts any not-completed cleanup state, including IDLE/NOTHING if called directly; ordinary termination enqueues PENDING. Worker uses SKIP LOCKED, retries PENDING/FAILED only for CANCELLED/EXPIRED/FAILED main flows and stops at 10 attempts. FAILED is retryable until that cap, then operationally stranded without a new terminal id. Cross-database dependent updates are not atomic with the ticket DB; tests exercise failures and retry. No cancellation/expiry lifecycle of cleanup itself is implemented. Direct status writes are the implementation, not routed through the main SignUpStateMachine.

## idp-client-auth-ceremony-session

Implementation: `AuthCeremonySession`. Storage: `client_auth_ceremony_sessions` / `admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at`.

Sources: `app/models/concerns/auth_ceremony_session.rb`, `app/models/client_auth_ceremony_session.rb`, `app/services/base_auth_admission_coordinator.rb`, `app/controllers/concerns/auth_ceremony_admission.rb`.

Tests read: `test/models/auth_ceremony_session_test.rb`, `test/models/auth_ceremony_session_concurrency_test.rb`, `test/models/auth_ceremony_revocation_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-auth-ceremony-session:T001 | DOCUMENTED_TRANSITION | issued | admit! | admitted | active; unadmitted; known purpose; row lock | admitted_at; purpose; binding | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T002 | DOCUMENTED_TRANSITION | admitted | record_authentication_evidence! | evidence | active/admitted; no prior evidence; supported method | method/event timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T003 | DOCUMENTED_TRANSITION | issued | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T004 | DOCUMENTED_TRANSITION | issued | rotate! same row | issued | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T005 | DOCUMENTED_TRANSITION | admitted | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T006 | DOCUMENTED_TRANSITION | admitted | rotate! same row | admitted | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T007 | DOCUMENTED_TRANSITION | evidence | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T008 | DOCUMENTED_TRANSITION | evidence | rotate! same row | evidence | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T009 | DOCUMENTED_TRANSITION | admitted | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T010 | DOCUMENTED_TRANSITION | admitted | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T011 | DOCUMENTED_TRANSITION | evidence | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-client-auth-ceremony-session:T012 | DOCUMENTED_TRANSITION | evidence | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |

No status string/id or reference table: labels are explicit predicates over timestamps. issue! creates unadmitted; rotate_and_admit! creates an already-admitted replacement and revokes the old row atomically. TTL is 30 minutes; expired continuity is inactive but not a stored terminal. revoke! deliberately permits expiry while complete!/cancel! require active admission. Terminal timestamps are mutually exclusive by CHECK. Authentication evidence is a one-time handoff input, not Base session authority. No ordinary failure state; errors reject mutation. Row locks and unique previous_sid_digest protect conflicting replacement. Direct previous-row revoked_at update is inside rotate_and_admit!, while callers terminate through the model; token security transition revokes linked continuity.

## idp-visitor-auth-ceremony-session

Implementation: `AuthCeremonySession`. Storage: `visitor_auth_ceremony_sessions` / `admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at`.

Sources: `app/models/concerns/auth_ceremony_session.rb`, `app/models/visitor_auth_ceremony_session.rb`, `app/services/base_auth_admission_coordinator.rb`, `app/controllers/concerns/auth_ceremony_admission.rb`.

Tests read: `test/models/auth_ceremony_session_test.rb`, `test/models/auth_ceremony_session_concurrency_test.rb`, `test/models/auth_ceremony_revocation_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-auth-ceremony-session:T001 | DOCUMENTED_TRANSITION | issued | admit! | admitted | active; unadmitted; known purpose; row lock | admitted_at; purpose; binding | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T002 | DOCUMENTED_TRANSITION | admitted | record_authentication_evidence! | evidence | active/admitted; no prior evidence; supported method | method/event timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T003 | DOCUMENTED_TRANSITION | issued | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T004 | DOCUMENTED_TRANSITION | issued | rotate! same row | issued | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T005 | DOCUMENTED_TRANSITION | admitted | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T006 | DOCUMENTED_TRANSITION | admitted | rotate! same row | admitted | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T007 | DOCUMENTED_TRANSITION | evidence | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T008 | DOCUMENTED_TRANSITION | evidence | rotate! same row | evidence | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T009 | DOCUMENTED_TRANSITION | admitted | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T010 | DOCUMENTED_TRANSITION | admitted | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T011 | DOCUMENTED_TRANSITION | evidence | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-visitor-auth-ceremony-session:T012 | DOCUMENTED_TRANSITION | evidence | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |

No status string/id or reference table: labels are explicit predicates over timestamps. issue! creates unadmitted; rotate_and_admit! creates an already-admitted replacement and revokes the old row atomically. TTL is 30 minutes; expired continuity is inactive but not a stored terminal. revoke! deliberately permits expiry while complete!/cancel! require active admission. Terminal timestamps are mutually exclusive by CHECK. Authentication evidence is a one-time handoff input, not Base session authority. No ordinary failure state; errors reject mutation. Row locks and unique previous_sid_digest protect conflicting replacement. Direct previous-row revoked_at update is inside rotate_and_admit!, while callers terminate through the model; token security transition revokes linked continuity.

## idp-operator-auth-ceremony-session

Implementation: `AuthCeremonySession`. Storage: `operator_auth_ceremony_sessions` / `admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at`.

Sources: `app/models/concerns/auth_ceremony_session.rb`, `app/models/operator_auth_ceremony_session.rb`, `app/services/base_auth_admission_coordinator.rb`, `app/controllers/concerns/auth_ceremony_admission.rb`.

Tests read: `test/models/auth_ceremony_session_test.rb`, `test/models/auth_ceremony_session_concurrency_test.rb`, `test/models/auth_ceremony_revocation_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-auth-ceremony-session:T001 | DOCUMENTED_TRANSITION | issued | admit! | admitted | active; unadmitted; known purpose; row lock | admitted_at; purpose; binding | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T002 | DOCUMENTED_TRANSITION | admitted | record_authentication_evidence! | evidence | active/admitted; no prior evidence; supported method | method/event timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T003 | DOCUMENTED_TRANSITION | issued | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T004 | DOCUMENTED_TRANSITION | issued | rotate! same row | issued | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T005 | DOCUMENTED_TRANSITION | admitted | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T006 | DOCUMENTED_TRANSITION | admitted | rotate! same row | admitted | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T007 | DOCUMENTED_TRANSITION | evidence | revoke! / rotate_and_admit! previous row | revoked | Not terminal; revoke! permits expired continuity | revoked_at; replacement is a distinct row | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T008 | DOCUMENTED_TRANSITION | evidence | rotate! same row | evidence | active; row lock | digest and expires_at replacement; rotated_at | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T009 | DOCUMENTED_TRANSITION | admitted | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T010 | DOCUMENTED_TRANSITION | admitted | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T011 | DOCUMENTED_TRANSITION | evidence | complete! | completed | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |
| idp-operator-auth-ceremony-session:T012 | DOCUMENTED_TRANSITION | evidence | cancel! | cancelled | active; admitted; row lock | one terminal timestamp | app/models/concerns/auth_ceremony_session.rb | CONFIRMED |

No status string/id or reference table: labels are explicit predicates over timestamps. issue! creates unadmitted; rotate_and_admit! creates an already-admitted replacement and revokes the old row atomically. TTL is 30 minutes; expired continuity is inactive but not a stored terminal. revoke! deliberately permits expiry while complete!/cancel! require active admission. Terminal timestamps are mutually exclusive by CHECK. Authentication evidence is a one-time handoff input, not Base session authority. No ordinary failure state; errors reject mutation. Row locks and unique previous_sid_digest protect conflicting replacement. Direct previous-row revoked_at update is inside rotate_and_admit!, while callers terminate through the model; token security transition revokes linked continuity.

## idp-client-email-ceremony

Implementation: `EmailCeremonyTransactionable`. Storage: `client_email_ceremony_transactions` / `status`.

Sources: `app/models/client_email_ceremony_transaction.rb`, `app/models/concerns/email_ceremony_transactionable.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/consumers/identity_email_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-email-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/email_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Email EVP outcome is a separate machine indexed below.

## idp-client-telephone-ceremony

Implementation: `TelephoneCeremonyTransactionable`. Storage: `client_telephone_ceremony_transactions` / `status`.

Sources: `app/models/client_telephone_ceremony_transaction.rb`, `app/models/concerns/telephone_ceremony_transactionable.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/consumers/identity_telephone_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-telephone-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/telephone_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-client-passkey-ceremony

Implementation: `PasskeyCeremonyTransactionable`. Storage: `client_passkey_ceremony_transactions` / `status`.

Sources: `app/models/client_passkey_ceremony_transaction.rb`, `app/models/concerns/passkey_ceremony_transactionable.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/consumers/identity_passkey_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_passkey_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-passkey-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/passkey_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Passkey enrollment can be linked to step-up through a RESTRICT FK; committed by Base operations.

## idp-client-secret-credential-ceremony

Implementation: `SecretCredentialCeremonyTransactionable`. Storage: `client_secret_credential_ceremony_transactions` / `status`.

Sources: `app/models/client_secret_credential_ceremony_transaction.rb`, `app/models/concerns/secret_credential_ceremony_transactionable.rb`, `app/operations/identity_secret_credential_ceremony_final_committer.rb`, `app/consumers/identity_secret_credential_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_secret_credential_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-secret-credential-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/secret_credential_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-visitor-email-ceremony

Implementation: `EmailCeremonyTransactionable`. Storage: `visitor_email_ceremony_transactions` / `status`.

Sources: `app/models/visitor_email_ceremony_transaction.rb`, `app/models/concerns/email_ceremony_transactionable.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/consumers/identity_email_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-email-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/email_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Email EVP outcome is a separate machine indexed below.

## idp-visitor-telephone-ceremony

Implementation: `TelephoneCeremonyTransactionable`. Storage: `visitor_telephone_ceremony_transactions` / `status`.

Sources: `app/models/visitor_telephone_ceremony_transaction.rb`, `app/models/concerns/telephone_ceremony_transactionable.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/consumers/identity_telephone_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-telephone-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/telephone_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-visitor-passkey-ceremony

Implementation: `PasskeyCeremonyTransactionable`. Storage: `visitor_passkey_ceremony_transactions` / `status`.

Sources: `app/models/visitor_passkey_ceremony_transaction.rb`, `app/models/concerns/passkey_ceremony_transactionable.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/consumers/identity_passkey_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_passkey_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-passkey-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/passkey_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Passkey enrollment can be linked to step-up through a RESTRICT FK; committed by Base operations.

## idp-visitor-secret-credential-ceremony

Implementation: `SecretCredentialCeremonyTransactionable`. Storage: `visitor_secret_credential_ceremony_transactions` / `status`.

Sources: `app/models/visitor_secret_credential_ceremony_transaction.rb`, `app/models/concerns/secret_credential_ceremony_transactionable.rb`, `app/operations/identity_secret_credential_ceremony_final_committer.rb`, `app/consumers/identity_secret_credential_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_secret_credential_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-secret-credential-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/secret_credential_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-operator-email-ceremony

Implementation: `EmailCeremonyTransactionable`. Storage: `operator_email_ceremony_transactions` / `status`.

Sources: `app/models/operator_email_ceremony_transaction.rb`, `app/models/concerns/email_ceremony_transactionable.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/consumers/identity_email_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-email-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/email_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Email EVP outcome is a separate machine indexed below.

## idp-operator-telephone-ceremony

Implementation: `TelephoneCeremonyTransactionable`. Storage: `operator_telephone_ceremony_transactions` / `status`.

Sources: `app/models/operator_telephone_ceremony_transaction.rb`, `app/models/concerns/telephone_ceremony_transactionable.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/consumers/identity_telephone_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-telephone-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/telephone_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-operator-passkey-ceremony

Implementation: `PasskeyCeremonyTransactionable`. Storage: `operator_passkey_ceremony_transactions` / `status`.

Sources: `app/models/operator_passkey_ceremony_transaction.rb`, `app/models/concerns/passkey_ceremony_transactionable.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/consumers/identity_passkey_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_passkey_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-passkey-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/passkey_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states. Passkey enrollment can be linked to step-up through a RESTRICT FK; committed by Base operations.

## idp-operator-secret-credential-ceremony

Implementation: `SecretCredentialCeremonyTransactionable`. Storage: `operator_secret_credential_ceremony_transactions` / `status`.

Sources: `app/models/operator_secret_credential_ceremony_transaction.rb`, `app/models/concerns/secret_credential_ceremony_transactionable.rb`, `app/operations/identity_secret_credential_ceremony_final_committer.rb`, `app/consumers/identity_secret_credential_ceremony_result_consumer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_secret_credential_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-secret-credential-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! | consumed | Unconsumed; TTL not reached; transaction row lock | result_jti + consumed_at | app/models/concerns/secret_credential_ceremony_transactionable.rb | CONFIRMED |

SQL default pending; status has model inclusion and consumed_at/result_jti duplication but no state reference FK. TTL expiry is a predicate and purge path, not stored expired. No cancel/failure status exists: result verification failures reject without transition. Auth result issuance crosses to Base final committer through signed grant/result; consumer reloads binding and consumes exactly once. Row lock plus unique result_jti rejects replay. Candidate/principal persistence can use another database, so no cross-DB atomicity is inferred. The model suite explicitly exercises client models; realm-specific committer tests are separate and test execution is unverified. Direct final-committer writes to credential/contact status are side effects, not ceremony states.

## idp-client-totp-ceremony

Implementation: `TotpCeremonyTransactionable`. Storage: `client_totp_ceremony_transactions` / `status`.

Sources: `app/models/client_totp_ceremony_transaction.rb`, `app/models/concerns/totp_ceremony_transactionable.rb`, `app/operations/identity_totp_ceremony_final_committer.rb`.

Tests read: `test/models/concerns/ceremony_transactionable_test.rb`, `test/operations/identity_totp_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-totp-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! / Base final committer | consumed | unconsumed; TTL; row lock; unique result_jti | consumed_at and result evidence | app/models/concerns/totp_ceremony_transactionable.rb | CONFIRMED |

These concrete machines exist only in app/client. pending default; consumed terminal; TTL 10 minutes is predicate-only and background purge retires rows after retention. No canceled/failed state or persisted expiry edge. Social supports provider-specific signed Auth-to-Base link/login/signup results; provider outcome does not create a social transaction state. TOTP is enrollment rather than primary login; new step-up enrollment final committer directly writes child consumed along with candidate and parent transaction under ticket locks. Results are unique and repeated consumption rejects. Credential creation may occur in a separate principal DB; failures and replay tests describe compensation/retained proof, not a guaranteed distributed transaction.

## idp-client-social-ceremony

Implementation: `SocialCeremonyTransactionable`. Storage: `client_social_ceremony_transactions` / `status`.

Sources: `app/models/client_social_ceremony_transaction.rb`, `app/models/concerns/social_ceremony_transactionable.rb`, `app/operations/identity_social_ceremony_final_committer.rb`.

Tests read: `test/models/concerns/social_ceremony_transactionable_test.rb`, UNKNOWN dedicated social final-committer test (path not present).

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-social-ceremony:T001 | DOCUMENTED_TRANSITION | pending | consume_result! / Base final committer | consumed | unconsumed; TTL; row lock; unique result_jti | consumed_at and result evidence | app/models/concerns/social_ceremony_transactionable.rb | CONFIRMED |

These concrete machines exist only in app/client. pending default; consumed terminal; TTL 10 minutes is predicate-only and background purge retires rows after retention. No canceled/failed state or persisted expiry edge. Social supports provider-specific signed Auth-to-Base link/login/signup results; provider outcome does not create a social transaction state. TOTP is enrollment rather than primary login; new step-up enrollment final committer directly writes child consumed along with candidate and parent transaction under ticket locks. Results are unique and repeated consumption rejects. Credential creation may occur in a separate principal DB; failures and replay tests describe compensation/retained proof, not a guaranteed distributed transaction.

## idp-client-step-up-ceremony

Implementation: `StepUpCeremonyTransactionable / Base committers`. Storage: `client_step_up_ceremony_transactions` / `status`.

Sources: `app/models/concerns/step_up_ceremony_transactionable.rb`, `app/operations/identity_step_up_ceremony_cancellation_committer.rb`, `app/models/concerns/token_status_management.rb`, `app/operations/identity_step_up_ceremony_freshness_committer.rb`, `app/operations/identity_totp_enrollment_final_committer.rb`.

Tests read: `test/models/opaque_step_up_transaction_test.rb`, `test/operations/identity_step_up_ceremony_cancellation_committer_test.rb`, `test/operations/identity_totp_enrollment_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-step-up-ceremony:T001 | DOCUMENTED_TRANSITION | pending | record_verification! / record_registration_verification! | verified | pending/unexpired; allowed method/purpose; evidence/assurance checks; lock | method/AAL/time/credential; result_jti | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T002 | DOCUMENTED_TRANSITION | verified | prepare_result_delivery! | verified | verified/unexpired; digest; ttl>0 | generation +1; bounded result TTL | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T003 | DOCUMENTED_TRANSITION | pending | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-client-step-up-ceremony:T004 | DOCUMENTED_TRANSITION | pending | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-client-step-up-ceremony:T005 | DOCUMENTED_TRANSITION | pending | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-step-up-ceremony:T006 | DOCUMENTED_TRANSITION | verified | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-client-step-up-ceremony:T007 | DOCUMENTED_TRANSITION | verified | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-client-step-up-ceremony:T008 | DOCUMENTED_TRANSITION | verified | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-step-up-ceremony:T009 | DOCUMENTED_TRANSITION | verified | Base freshness / registration final committer | consumed | verified evidence; binding/generation/resource/policy recheck | consumed_at; token freshness OR credential creation | app/operations/identity_step_up_ceremony_freshness_committer.rb | CONFIRMED |
| idp-client-step-up-ceremony:T010 | OUT_OF_BAND | pending | consume_result! public model API | consumed | Not consumed/canceled/time-expired; does NOT require verified | supplied verification data; consumed_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T011 | DUPLICATE_EVIDENCE_OF_T010 | pending | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T012 | OUT_OF_BAND | pending | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T013 | OUT_OF_BAND | verified | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T014 | OUT_OF_BAND | verified | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T015 | OUT_OF_BAND | expired | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-client-step-up-ceremony:T016 | OUT_OF_BAND | expired | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |

status is a string CHECK, no reference FK. canceled (single l) is current vocabulary; Auth continuity uses cancelled. SQL evidence/purpose CHECKs distinguish registration proof (AAL none, no existing credential) from authentication verification. Parent revoked/consumed/canceled states close normal workflows; time expiry is usually a predicate, and expired is persisted only in the cancellation committer path. Generic consume_result! does not assert verified source and generic cancel! excludes canceled/consumed/time-expired but can accept revoked; therefore formal terminality is not universal across public APIs. Generic cancel! also omits canceled_at. These broader model APIs are recorded rather than hidden. Base committers use stricter verified/binding/current-credential checks and serialization. Result reissue rotates generation while preserving verified state. Token refresh/revocation invalidates pending/verified ceremonies; no evidence of automatic blanket pending→expired job transition (purger deletes expired records). Email/TOTP/passkey methods differ by surface and scope; consult allowed_methods/policy source.

Adversarial SQL cross-check: public consume_result!/cancel! do not reject revoked status explicitly, but current terminal CHECK requires a non-null revoked_at only with status revoked. Consequently, these attempted rewrites of a normally revoked row fail the database CHECK; no revoked->consumed/canceled runtime edge is drawn. Expired-status public edges require a future expires_at and are merely model-permitted, not recovery from real clock expiry.

## idp-visitor-step-up-ceremony

Implementation: `StepUpCeremonyTransactionable / Base committers`. Storage: `visitor_step_up_ceremony_transactions` / `status`.

Sources: `app/models/concerns/step_up_ceremony_transactionable.rb`, `app/operations/identity_step_up_ceremony_cancellation_committer.rb`, `app/models/concerns/token_status_management.rb`, `app/operations/identity_step_up_ceremony_freshness_committer.rb`, `app/operations/identity_totp_enrollment_final_committer.rb`.

Tests read: `test/models/opaque_step_up_transaction_test.rb`, `test/operations/identity_step_up_ceremony_cancellation_committer_test.rb`, `test/operations/identity_totp_enrollment_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-step-up-ceremony:T001 | DOCUMENTED_TRANSITION | pending | record_verification! / record_registration_verification! | verified | pending/unexpired; allowed method/purpose; evidence/assurance checks; lock | method/AAL/time/credential; result_jti | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T002 | DOCUMENTED_TRANSITION | verified | prepare_result_delivery! | verified | verified/unexpired; digest; ttl>0 | generation +1; bounded result TTL | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T003 | DOCUMENTED_TRANSITION | pending | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T004 | DOCUMENTED_TRANSITION | pending | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T005 | DOCUMENTED_TRANSITION | pending | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T006 | DOCUMENTED_TRANSITION | verified | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T007 | DOCUMENTED_TRANSITION | verified | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T008 | DOCUMENTED_TRANSITION | verified | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T009 | DOCUMENTED_TRANSITION | verified | Base freshness / registration final committer | consumed | verified evidence; binding/generation/resource/policy recheck | consumed_at; token freshness OR credential creation | app/operations/identity_step_up_ceremony_freshness_committer.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T010 | OUT_OF_BAND | pending | consume_result! public model API | consumed | Not consumed/canceled/time-expired; does NOT require verified | supplied verification data; consumed_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T011 | DUPLICATE_EVIDENCE_OF_T010 | pending | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T012 | OUT_OF_BAND | pending | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T013 | OUT_OF_BAND | verified | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T014 | OUT_OF_BAND | verified | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T015 | OUT_OF_BAND | expired | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-visitor-step-up-ceremony:T016 | OUT_OF_BAND | expired | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |

status is a string CHECK, no reference FK. canceled (single l) is current vocabulary; Auth continuity uses cancelled. SQL evidence/purpose CHECKs distinguish registration proof (AAL none, no existing credential) from authentication verification. Parent revoked/consumed/canceled states close normal workflows; time expiry is usually a predicate, and expired is persisted only in the cancellation committer path. Generic consume_result! does not assert verified source and generic cancel! excludes canceled/consumed/time-expired but can accept revoked; therefore formal terminality is not universal across public APIs. Generic cancel! also omits canceled_at. These broader model APIs are recorded rather than hidden. Base committers use stricter verified/binding/current-credential checks and serialization. Result reissue rotates generation while preserving verified state. Token refresh/revocation invalidates pending/verified ceremonies; no evidence of automatic blanket pending→expired job transition (purger deletes expired records). Email/TOTP/passkey methods differ by surface and scope; consult allowed_methods/policy source.

Adversarial SQL cross-check: public consume_result!/cancel! do not reject revoked status explicitly, but current terminal CHECK requires a non-null revoked_at only with status revoked. Consequently, these attempted rewrites of a normally revoked row fail the database CHECK; no revoked->consumed/canceled runtime edge is drawn. Expired-status public edges require a future expires_at and are merely model-permitted, not recovery from real clock expiry.

## idp-operator-step-up-ceremony

Implementation: `StepUpCeremonyTransactionable / Base committers`. Storage: `operator_step_up_ceremony_transactions` / `status`.

Sources: `app/models/concerns/step_up_ceremony_transactionable.rb`, `app/operations/identity_step_up_ceremony_cancellation_committer.rb`, `app/models/concerns/token_status_management.rb`, `app/operations/identity_step_up_ceremony_freshness_committer.rb`, `app/operations/identity_totp_enrollment_final_committer.rb`.

Tests read: `test/models/opaque_step_up_transaction_test.rb`, `test/operations/identity_step_up_ceremony_cancellation_committer_test.rb`, `test/operations/identity_totp_enrollment_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-step-up-ceremony:T001 | DOCUMENTED_TRANSITION | pending | record_verification! / record_registration_verification! | verified | pending/unexpired; allowed method/purpose; evidence/assurance checks; lock | method/AAL/time/credential; result_jti | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T002 | DOCUMENTED_TRANSITION | verified | prepare_result_delivery! | verified | verified/unexpired; digest; ttl>0 | generation +1; bounded result TTL | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T003 | DOCUMENTED_TRANSITION | pending | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T004 | DOCUMENTED_TRANSITION | pending | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T005 | DOCUMENTED_TRANSITION | pending | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T006 | DOCUMENTED_TRANSITION | verified | Base cancellation committer | canceled | Matching current actor/token; purpose binding; unexpired; lock | canceled_at; linked Auth cancel | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T007 | DOCUMENTED_TRANSITION | verified | Base cancellation at TTL | expired | Same binding; expires_at <= DB now | status expired; no cancel side effect | app/operations/identity_step_up_ceremony_cancellation_committer.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T008 | DOCUMENTED_TRANSITION | verified | token revoke_step_up_authority! | revoked | Linked session; status pending or verified; ordered locks | revoked_at; discard child; clear token freshness; revoke Auth | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T009 | DOCUMENTED_TRANSITION | verified | Base freshness / registration final committer | consumed | verified evidence; binding/generation/resource/policy recheck | consumed_at; token freshness OR credential creation | app/operations/identity_step_up_ceremony_freshness_committer.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T010 | OUT_OF_BAND | pending | consume_result! public model API | consumed | Not consumed/canceled/time-expired; does NOT require verified | supplied verification data; consumed_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T011 | DUPLICATE_EVIDENCE_OF_T010 | pending | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T012 | OUT_OF_BAND | pending | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T013 | OUT_OF_BAND | verified | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T014 | OUT_OF_BAND | verified | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T015 | OUT_OF_BAND | expired | consume_result! public model API | consumed | Not consumed/canceled; expires_at>consumed_at; lock; model/SQL evidence validity | Direct consumed status and result evidence | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |
| idp-operator-step-up-ceremony:T016 | OUT_OF_BAND | expired | cancel! public model API | canceled | Not consumed/canceled; expires_at>canceled_at; row lock; no revoked-status guard | Writes status canceled and updated_at; no canceled_at | app/models/concerns/step_up_ceremony_transactionable.rb | CONFIRMED |

status is a string CHECK, no reference FK. canceled (single l) is current vocabulary; Auth continuity uses cancelled. SQL evidence/purpose CHECKs distinguish registration proof (AAL none, no existing credential) from authentication verification. Parent revoked/consumed/canceled states close normal workflows; time expiry is usually a predicate, and expired is persisted only in the cancellation committer path. Generic consume_result! does not assert verified source and generic cancel! excludes canceled/consumed/time-expired but can accept revoked; therefore formal terminality is not universal across public APIs. Generic cancel! also omits canceled_at. These broader model APIs are recorded rather than hidden. Base committers use stricter verified/binding/current-credential checks and serialization. Result reissue rotates generation while preserving verified state. Token refresh/revocation invalidates pending/verified ceremonies; no evidence of automatic blanket pending→expired job transition (purger deletes expired records). Operator emergency session cannot enter/cancel step-up; only passkey is permitted on org.

Adversarial SQL cross-check: public consume_result!/cancel! do not reject revoked status explicitly, but current terminal CHECK requires a non-null revoked_at only with status revoked. Consequently, these attempted rewrites of a normally revoked row fail the database CHECK; no revoked->consumed/canceled runtime edge is drawn. Expired-status public edges require a future expires_at and are merely model-permitted, not recovery from real clock expiry.

## idp-client-oidc-authorization

Implementation: `OidcAuthorizationTransactionable`. Storage: `client_oidc_authorization_transactions` / `status`.

Sources: `app/models/concerns/oidc_authorization_transactionable.rb`, `app/models/client_oidc_authorization_transaction.rb`, `app/services/oidc_authorization_transaction_coordinator.rb`, `app/services/credential_security_transition.rb`.

Tests read: `test/models/concerns/oidc_authorization_transactionable_test.rb`, `test/services/oidc_authorization_transaction_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-oidc-authorization:T001 | DOCUMENTED_TRANSITION | pending | register_authentication! | authenticated | pending; transaction/login-challenge DB clock deadlines; row lock | actor/method/authentication time | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-client-oidc-authorization:T002 | DOCUMENTED_TRANSITION | authenticated | prepare_result_delivery! | authenticated | unexpired/unfinalized; digest | generation +1; reset result_consumed_at; bounded TTL | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-client-oidc-authorization:T003 | DOCUMENTED_TRANSITION | authenticated | consume! | consumed | authenticated; unexpired; row lock | consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-client-oidc-authorization:T004 | DOCUMENTED_TRANSITION | authenticated | finalize_base! success | consumed | authenticated or previously finalized; matching generation; successful session reference | browser_session_ref; result_consumed_at; base_finalized_at; consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-client-oidc-authorization:T005 | DOCUMENTED_TRANSITION | consumed | claim_authorization_grant! | consumed | finalized; unexpired; grant not redeemed | authorization_grant_redeemed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |

OIDC `state` is request CSRF correlation, not lifecycle duplication of status. No reference table or persisted canceled/failed/expired status. Expiry predicates check authorization and login-challenge independently; security transitions clamp deadlines and revoke linked Auth continuity without status change. consumed ends authentication transition but authorization grant redemption remains a second one-time fact; finalize_base! idempotently reuses persisted browser-session reference. Raw consume! lacks Base finalization fact, so consumed alone does not prove grant readiness. Row locking serializes authentication and redemption; test reads cover exact microsecond deadline neighbors, stale generation, overwritten authentication rejection and concurrent one winner. Auth-to-Base result uses opaque admission transport; code issuance then redemption creates RP session. No target external_result event is inferred.

## idp-visitor-oidc-authorization

Implementation: `OidcAuthorizationTransactionable`. Storage: `visitor_oidc_authorization_transactions` / `status`.

Sources: `app/models/concerns/oidc_authorization_transactionable.rb`, `app/models/visitor_oidc_authorization_transaction.rb`, `app/services/oidc_authorization_transaction_coordinator.rb`, `app/services/credential_security_transition.rb`.

Tests read: `test/models/concerns/oidc_authorization_transactionable_test.rb`, `test/services/oidc_authorization_transaction_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-oidc-authorization:T001 | DOCUMENTED_TRANSITION | pending | register_authentication! | authenticated | pending; transaction/login-challenge DB clock deadlines; row lock | actor/method/authentication time | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-visitor-oidc-authorization:T002 | DOCUMENTED_TRANSITION | authenticated | prepare_result_delivery! | authenticated | unexpired/unfinalized; digest | generation +1; reset result_consumed_at; bounded TTL | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-visitor-oidc-authorization:T003 | DOCUMENTED_TRANSITION | authenticated | consume! | consumed | authenticated; unexpired; row lock | consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-visitor-oidc-authorization:T004 | DOCUMENTED_TRANSITION | authenticated | finalize_base! success | consumed | authenticated or previously finalized; matching generation; successful session reference | browser_session_ref; result_consumed_at; base_finalized_at; consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-visitor-oidc-authorization:T005 | DOCUMENTED_TRANSITION | consumed | claim_authorization_grant! | consumed | finalized; unexpired; grant not redeemed | authorization_grant_redeemed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |

OIDC `state` is request CSRF correlation, not lifecycle duplication of status. No reference table or persisted canceled/failed/expired status. Expiry predicates check authorization and login-challenge independently; security transitions clamp deadlines and revoke linked Auth continuity without status change. consumed ends authentication transition but authorization grant redemption remains a second one-time fact; finalize_base! idempotently reuses persisted browser-session reference. Raw consume! lacks Base finalization fact, so consumed alone does not prove grant readiness. Row locking serializes authentication and redemption; test reads cover exact microsecond deadline neighbors, stale generation, overwritten authentication rejection and concurrent one winner. Auth-to-Base result uses opaque admission transport; code issuance then redemption creates RP session. No target external_result event is inferred.

## idp-operator-oidc-authorization

Implementation: `OidcAuthorizationTransactionable`. Storage: `operator_oidc_authorization_transactions` / `status`.

Sources: `app/models/concerns/oidc_authorization_transactionable.rb`, `app/models/operator_oidc_authorization_transaction.rb`, `app/services/oidc_authorization_transaction_coordinator.rb`, `app/services/credential_security_transition.rb`.

Tests read: `test/models/concerns/oidc_authorization_transactionable_test.rb`, `test/services/oidc_authorization_transaction_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-oidc-authorization:T001 | DOCUMENTED_TRANSITION | pending | register_authentication! | authenticated | pending; transaction/login-challenge DB clock deadlines; row lock | actor/method/authentication time | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-operator-oidc-authorization:T002 | DOCUMENTED_TRANSITION | authenticated | prepare_result_delivery! | authenticated | unexpired/unfinalized; digest | generation +1; reset result_consumed_at; bounded TTL | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-operator-oidc-authorization:T003 | DOCUMENTED_TRANSITION | authenticated | consume! | consumed | authenticated; unexpired; row lock | consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-operator-oidc-authorization:T004 | DOCUMENTED_TRANSITION | authenticated | finalize_base! success | consumed | authenticated or previously finalized; matching generation; successful session reference | browser_session_ref; result_consumed_at; base_finalized_at; consumed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |
| idp-operator-oidc-authorization:T005 | DOCUMENTED_TRANSITION | consumed | claim_authorization_grant! | consumed | finalized; unexpired; grant not redeemed | authorization_grant_redeemed_at | app/models/concerns/oidc_authorization_transactionable.rb | CONFIRMED |

OIDC `state` is request CSRF correlation, not lifecycle duplication of status. No reference table or persisted canceled/failed/expired status. Expiry predicates check authorization and login-challenge independently; security transitions clamp deadlines and revoke linked Auth continuity without status change. consumed ends authentication transition but authorization grant redemption remains a second one-time fact; finalize_base! idempotently reuses persisted browser-session reference. Raw consume! lacks Base finalization fact, so consumed alone does not prove grant readiness. Row locking serializes authentication and redemption; test reads cover exact microsecond deadline neighbors, stale generation, overwritten authentication rejection and concurrent one winner. Auth-to-Base result uses opaque admission transport; code issuance then redemption creates RP session. No target external_result event is inferred.

## idp-client-oauth-callback

Implementation: `OauthCallbackStateable`. Storage: `client_oauth_callback_states` / `consumed_at / expires_at`.

Sources: `app/models/concerns/oauth_callback_stateable.rb`, `app/models/client_oauth_callback_state.rb`, `app/services/social_auth_callback_state_store.rb`.

Tests read: `test/models/oauth_callback_state_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-oauth-callback:T001 | DOCUMENTED_TRANSITION | unconsumed | consume! provider callback | consumed | provider/digest match; active TTL; row lock in transaction | consumed_at | app/models/concerns/oauth_callback_stateable.rb | CONFIRMED |

No lifecycle `state` column: state_digest identifies OAuth anti-CSRF state. TTL 300 seconds; expiry leaves row unconsumed but unresumable. Duplicate issuance find_or_create may return existing expired/consumed row; does not reset TTL/consumption. Provider mismatch/replay reject without state mutation. Production SocialAuthCallbackStateStore only supports configured providers; tests explicitly refuse unsupported org/com google names. Operator model has working transaction API but production provider wiring must be assessed independently; visitor has no callback model/table and no invented diagram.

## idp-operator-oauth-callback

Implementation: `OauthCallbackStateable`. Storage: `operator_oauth_callback_states` / `consumed_at / expires_at`.

Sources: `app/models/concerns/oauth_callback_stateable.rb`, `app/models/operator_oauth_callback_state.rb`, `app/services/social_auth_callback_state_store.rb`.

Tests read: `test/models/oauth_callback_state_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-oauth-callback:T001 | DOCUMENTED_TRANSITION | unconsumed | consume! provider callback | consumed | provider/digest match; active TTL; row lock in transaction | consumed_at | app/models/concerns/oauth_callback_stateable.rb | CONFIRMED |

No lifecycle `state` column: state_digest identifies OAuth anti-CSRF state. TTL 300 seconds; expiry leaves row unconsumed but unresumable. Duplicate issuance find_or_create may return existing expired/consumed row; does not reset TTL/consumption. Provider mismatch/replay reject without state mutation. Production SocialAuthCallbackStateStore only supports configured providers; tests explicitly refuse unsupported org/com google names. Operator model has working transaction API but production provider wiring must be assessed independently; visitor has no callback model/table and no invented diagram.

## idp-client-local-result-delivery

Implementation: `LocalAuthenticationResultDelivery / LocalAuthenticationResultCoordinator`. Storage: `client_sign_in_flows` / `result_generation / result_digest / base_finalized_at`.

Sources: `app/models/concerns/local_authentication_result_delivery.rb`, `app/models/client_sign_in_flow.rb`, `app/services/local_authentication_result_coordinator.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/integration/local_authentication_boundary_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-local-result-delivery:T001 | DOCUMENTED_TRANSITION | empty | record_local_authentication_evidence! | evidence | PRIMARY/MFA_PENDING; principal; expiry; supported method; lock | method/event time/context | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-client-local-result-delivery:T002 | DOCUMENTED_TRANSITION | evidence | prepare_local_result_delivery! | delivery | issuance/limit/handoff phase; evidence; digest/TTL; not finalized | digest; generation+1; expiry bounded | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-client-local-result-delivery:T003 | DOCUMENTED_TRANSITION | delivery | prepare_local_result_delivery! reissue | delivery | same guards; unfinalized | new digest/generation invalidates old delivery | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-client-local-result-delivery:T004 | DOCUMENTED_TRANSITION | delivery | LocalAuthenticationSessionCommitter success | finalized | actor-before-flow locks; nonce/result/session/current binding | root session issuance; base_finalized_at; Auth complete | app/operations/local_authentication_session_committer.rb | CONFIRMED |

This is a subordinate fact lifecycle on sign-in rows, not an extra status reference or sign-up state. Only concrete sign-in flows include LocalAuthenticationResultDelivery and coordinator.surface_for accepts them. The helper permits SIGN_IN_HANDOFF_PENDING string but no sign-up model inclusion/caller is inferred. delivery TTL expiry is a refusal predicate, not a stored terminal. Base success completes flow through authentication pipeline; capacity refusal preserves result and moves main flow to SESSION_LIMIT_PENDING. Repeated finalization returns already_finalized token reference; other-browser/stale generation rejected. Direct base_finalized_at writes are operation-owned; chronology and generation are distinct from main status, not alternative state ids.

## idp-visitor-local-result-delivery

Implementation: `LocalAuthenticationResultDelivery / LocalAuthenticationResultCoordinator`. Storage: `visitor_sign_in_flows` / `result_generation / result_digest / base_finalized_at`.

Sources: `app/models/concerns/local_authentication_result_delivery.rb`, `app/models/visitor_sign_in_flow.rb`, `app/services/local_authentication_result_coordinator.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/integration/local_authentication_boundary_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-local-result-delivery:T001 | DOCUMENTED_TRANSITION | empty | record_local_authentication_evidence! | evidence | PRIMARY/MFA_PENDING; principal; expiry; supported method; lock | method/event time/context | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-visitor-local-result-delivery:T002 | DOCUMENTED_TRANSITION | evidence | prepare_local_result_delivery! | delivery | issuance/limit/handoff phase; evidence; digest/TTL; not finalized | digest; generation+1; expiry bounded | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-visitor-local-result-delivery:T003 | DOCUMENTED_TRANSITION | delivery | prepare_local_result_delivery! reissue | delivery | same guards; unfinalized | new digest/generation invalidates old delivery | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-visitor-local-result-delivery:T004 | DOCUMENTED_TRANSITION | delivery | LocalAuthenticationSessionCommitter success | finalized | actor-before-flow locks; nonce/result/session/current binding | root session issuance; base_finalized_at; Auth complete | app/operations/local_authentication_session_committer.rb | CONFIRMED |

This is a subordinate fact lifecycle on sign-in rows, not an extra status reference or sign-up state. Only concrete sign-in flows include LocalAuthenticationResultDelivery and coordinator.surface_for accepts them. The helper permits SIGN_IN_HANDOFF_PENDING string but no sign-up model inclusion/caller is inferred. delivery TTL expiry is a refusal predicate, not a stored terminal. Base success completes flow through authentication pipeline; capacity refusal preserves result and moves main flow to SESSION_LIMIT_PENDING. Repeated finalization returns already_finalized token reference; other-browser/stale generation rejected. Direct base_finalized_at writes are operation-owned; chronology and generation are distinct from main status, not alternative state ids.

## idp-operator-local-result-delivery

Implementation: `LocalAuthenticationResultDelivery / LocalAuthenticationResultCoordinator`. Storage: `operator_sign_in_flows` / `result_generation / result_digest / base_finalized_at`.

Sources: `app/models/concerns/local_authentication_result_delivery.rb`, `app/models/operator_sign_in_flow.rb`, `app/services/local_authentication_result_coordinator.rb`, `app/operations/local_authentication_session_committer.rb`.

Tests read: `test/integration/local_authentication_boundary_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-local-result-delivery:T001 | DOCUMENTED_TRANSITION | empty | record_local_authentication_evidence! | evidence | PRIMARY/MFA_PENDING; principal; expiry; supported method; lock | method/event time/context | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-operator-local-result-delivery:T002 | DOCUMENTED_TRANSITION | evidence | prepare_local_result_delivery! | delivery | issuance/limit/handoff phase; evidence; digest/TTL; not finalized | digest; generation+1; expiry bounded | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-operator-local-result-delivery:T003 | DOCUMENTED_TRANSITION | delivery | prepare_local_result_delivery! reissue | delivery | same guards; unfinalized | new digest/generation invalidates old delivery | app/models/concerns/local_authentication_result_delivery.rb | CONFIRMED |
| idp-operator-local-result-delivery:T004 | DOCUMENTED_TRANSITION | delivery | LocalAuthenticationSessionCommitter success | finalized | actor-before-flow locks; nonce/result/session/current binding | root session issuance; base_finalized_at; Auth complete | app/operations/local_authentication_session_committer.rb | CONFIRMED |

This is a subordinate fact lifecycle on sign-in rows, not an extra status reference or sign-up state. Only concrete sign-in flows include LocalAuthenticationResultDelivery and coordinator.surface_for accepts them. The helper permits SIGN_IN_HANDOFF_PENDING string but no sign-up model inclusion/caller is inferred. delivery TTL expiry is a refusal predicate, not a stored terminal. Base success completes flow through authentication pipeline; capacity refusal preserves result and moves main flow to SESSION_LIMIT_PENDING. Repeated finalization returns already_finalized token reference; other-browser/stale generation rejected. Direct base_finalized_at writes are operation-owned; chronology and generation are distinct from main status, not alternative state ids.

## idp-client-token

Implementation: `TokenStatusManagement / RefreshTokenable`. Storage: `client_tokens` / `actor token status FK`.

Sources: `app/models/concerns/token_status_management.rb`, `app/models/concerns/refresh_tokenable.rb`, `app/models/client_token.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/token_status_management_test.rb`, `test/models/concerns/refresh_tokenable_test.rb`, `test/models/refresh_token_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-token:T001 | DOCUMENTED_TRANSITION | ACTIVE | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T002 | DOCUMENTED_TRANSITION | ACTIVE | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T003 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T004 | DOCUMENTED_TRANSITION | EXPIRED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T005 | DOCUMENTED_TRANSITION | EXPIRED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T006 | DOCUMENTED_TRANSITION | EXPIRED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T007 | DOCUMENTED_TRANSITION | RESTRICTED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T008 | DOCUMENTED_TRANSITION | RESTRICTED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T009 | DOCUMENTED_TRANSITION | RESTRICTED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T010 | DOCUMENTED_TRANSITION | REVOKED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T011 | DOCUMENTED_TRANSITION | REVOKED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T012 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T013 | DOCUMENTED_TRANSITION | ACTIVE | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-client-token:T014 | DOCUMENTED_TRANSITION | RESTRICTED | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-client-token:T015 | OUT_OF_BAND | NOTHING | promote_to_active! | ACTIVE | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T016 | OUT_OF_BAND | NOTHING | mark_restricted! | RESTRICTED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-client-token:T017 | OUT_OF_BAND | NOTHING | revoke! | REVOKED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |

EXPIRED is a reference id, but no production setter was found; time/discard/rotation independently make a row unusable without setting EXPIRED. Public promote/restrict APIs lack a source-status guard and can change a revoked/expired id, although retained discard/rotation prevents usability; therefore no universal absorbing terminal is drawn. revoke! is locked and clears bound step-up authority; promote/restrict are status saves without their own row lock. Refresh rotation marks old row unusable and creates a separate replacement, not an old row transition back to ACTIVE. Old digest replay returns replay; surrounding verifier can revoke family. Device current-refresh ownership is distinct. Default constructor uses ACTIVE; restricted issuance is an existing path. Storage includes status plus discard_at/rotated_at/generation rather than a single lifecycle authority; DBSC is independently indexed.

## idp-client-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `client_tokens` / `actor token DBSC status FK`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-client-preference-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `app_preferences` / `dbsc_status_id`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/preference_dbsc_registration_endpoint.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`, `test/controllers/concerns/preference/dbsc_registration_endpoint_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-preference-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-preference-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-preference-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-preference-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-preference-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-preference-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-preference-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-client-preference-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-client-preference-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-client-device-session

Implementation: `DeviceSessionable`. Storage: `client_device_sessions` / `status_id`.

Sources: `app/models/concerns/device_sessionable.rb`, `app/models/client_device_session.rb`, `app/models/concerns/refresh_tokenable.rb`.

Tests read: `test/models/concerns/device_sessionable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-device-session:T001 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No own source guard or lock | status and revoked_at/reason | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-client-device-session:T002 | DOCUMENTED_TRANSITION | REVOKED | revoke! replay | REVOKED | No guard; preserves first revoked_at | reason may change | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-client-device-session:T003 | OUT_OF_BAND | ACTIVE | bind_dbsc! | ACTIVE | No own lifecycle guard | update_columns digest/thumbprint/dbsc_bound_at | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-client-device-session:T004 | DOCUMENTED_TRANSITION | REVOKED | bind_dbsc! public API | REVOKED | No own lifecycle guard | binding columns can still change | app/models/concerns/device_sessionable.rb | CONFIRMED |

No state reference FK or explicit enum validation beyond status presence. status_id and revoked_at duplicate the revoked predicate. revoke! has no own row lock; surrounding root rotation/revocation callers may supply locks. bind_dbsc! uses update_columns even for revoked rows; binding is a subordinate axis, not reactivation. Token/device composite owner and current refresh FKs do not encode status transitions. No own expires_at/expiry/cancel/failure state; root token lifetimes govern authentication.

## idp-client-rp-session

Implementation: `RpSession`. Storage: `client_rp_sessions` / `revoked_at / expires_at`.

Sources: `app/models/concerns/rp_session.rb`, `app/models/client_rp_session.rb`, `app/operations/rp_session_revoker.rb`.

Tests read: `test/models/rp_session_test.rb`, `test/models/rp_session_retirement_window_test.rb`, `test/operations/rp_session_revoker_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-rp-session:T001 | DOCUMENTED_TRANSITION | active | issue_refresh_token! / rotate_refresh_token! | active | Parent and RP row locks; active root; absolute expiry cap | digest/previous digest/last_used/refresh expiry | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-client-rp-session:T002 | DOCUMENTED_TRANSITION | active | revoke! | revoked | Parent and RP row locks | revoked_at; logout timestamps/result | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-client-rp-session:T003 | DOCUMENTED_TRANSITION | revoked | revoke! repeat | revoked | No source-state guard | replaces revocation/logout timestamp | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-client-rp-session:T004 | DOCUMENTED_TRANSITION | revoked | retirement_pending? clock predicate | retired | now >= max issued access exp + leeway; known max | No DB write | app/models/concerns/rp_session.rb | CONFIRMED |

Labels are timestamp/root validity predicates, not stored status strings. A nonrevoked row may be inactive due to parent or refresh expiry; that inactive condition is not a persisted terminal. Retirement_pending? remains true for an unknown maximum access JWT expiry, including legacy rows: hidden operational non-retirement, not failed state. last_logout_status success/no_session/unsupported/failed describes delivery outcome, not RP lifecycle. Max access expiry is monotonic; same-row refresh rotation tracks previous digest, and token exchange recognizes replay. Parent token expiry immediately removes active authority; issued access tokens can outlive revocation until max expiry/leeway. No universal EXPIRED/cancel state.

## idp-visitor-token

Implementation: `TokenStatusManagement / RefreshTokenable`. Storage: `visitor_tokens` / `actor token status FK`.

Sources: `app/models/concerns/token_status_management.rb`, `app/models/concerns/refresh_tokenable.rb`, `app/models/visitor_token.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/token_status_management_test.rb`, `test/models/concerns/refresh_tokenable_test.rb`, `test/models/refresh_token_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-token:T001 | DOCUMENTED_TRANSITION | ACTIVE | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T002 | DOCUMENTED_TRANSITION | ACTIVE | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T003 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T004 | DOCUMENTED_TRANSITION | EXPIRED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T005 | DOCUMENTED_TRANSITION | EXPIRED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T006 | DOCUMENTED_TRANSITION | EXPIRED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T007 | DOCUMENTED_TRANSITION | RESTRICTED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T008 | DOCUMENTED_TRANSITION | RESTRICTED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T009 | DOCUMENTED_TRANSITION | RESTRICTED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T010 | DOCUMENTED_TRANSITION | REVOKED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T011 | DOCUMENTED_TRANSITION | REVOKED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T012 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T013 | DOCUMENTED_TRANSITION | ACTIVE | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-visitor-token:T014 | DOCUMENTED_TRANSITION | RESTRICTED | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-visitor-token:T015 | OUT_OF_BAND | NOTHING | promote_to_active! | ACTIVE | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T016 | OUT_OF_BAND | NOTHING | mark_restricted! | RESTRICTED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-visitor-token:T017 | OUT_OF_BAND | NOTHING | revoke! | REVOKED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |

EXPIRED is a reference id, but no production setter was found; time/discard/rotation independently make a row unusable without setting EXPIRED. Public promote/restrict APIs lack a source-status guard and can change a revoked/expired id, although retained discard/rotation prevents usability; therefore no universal absorbing terminal is drawn. revoke! is locked and clears bound step-up authority; promote/restrict are status saves without their own row lock. Refresh rotation marks old row unusable and creates a separate replacement, not an old row transition back to ACTIVE. Old digest replay returns replay; surrounding verifier can revoke family. Device current-refresh ownership is distinct. Default constructor uses ACTIVE; restricted issuance is an existing path. Storage includes status plus discard_at/rotated_at/generation rather than a single lifecycle authority; DBSC is independently indexed.

## idp-visitor-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `visitor_tokens` / `actor token DBSC status FK`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-visitor-preference-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `com_preferences` / `dbsc_status_id`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/preference_dbsc_registration_endpoint.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`, `test/controllers/concerns/preference/dbsc_registration_endpoint_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-preference-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-visitor-preference-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-visitor-device-session

Implementation: `DeviceSessionable`. Storage: `visitor_device_sessions` / `status_id`.

Sources: `app/models/concerns/device_sessionable.rb`, `app/models/visitor_device_session.rb`, `app/models/concerns/refresh_tokenable.rb`.

Tests read: `test/models/concerns/device_sessionable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-device-session:T001 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No own source guard or lock | status and revoked_at/reason | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-visitor-device-session:T002 | DOCUMENTED_TRANSITION | REVOKED | revoke! replay | REVOKED | No guard; preserves first revoked_at | reason may change | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-visitor-device-session:T003 | OUT_OF_BAND | ACTIVE | bind_dbsc! | ACTIVE | No own lifecycle guard | update_columns digest/thumbprint/dbsc_bound_at | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-visitor-device-session:T004 | DOCUMENTED_TRANSITION | REVOKED | bind_dbsc! public API | REVOKED | No own lifecycle guard | binding columns can still change | app/models/concerns/device_sessionable.rb | CONFIRMED |

No state reference FK or explicit enum validation beyond status presence. status_id and revoked_at duplicate the revoked predicate. revoke! has no own row lock; surrounding root rotation/revocation callers may supply locks. bind_dbsc! uses update_columns even for revoked rows; binding is a subordinate axis, not reactivation. Token/device composite owner and current refresh FKs do not encode status transitions. No own expires_at/expiry/cancel/failure state; root token lifetimes govern authentication.

## idp-visitor-rp-session

Implementation: `RpSession`. Storage: `visitor_rp_sessions` / `revoked_at / expires_at`.

Sources: `app/models/concerns/rp_session.rb`, `app/models/visitor_rp_session.rb`, `app/operations/rp_session_revoker.rb`.

Tests read: `test/models/rp_session_test.rb`, `test/models/rp_session_retirement_window_test.rb`, `test/operations/rp_session_revoker_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-rp-session:T001 | DOCUMENTED_TRANSITION | active | issue_refresh_token! / rotate_refresh_token! | active | Parent and RP row locks; active root; absolute expiry cap | digest/previous digest/last_used/refresh expiry | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-visitor-rp-session:T002 | DOCUMENTED_TRANSITION | active | revoke! | revoked | Parent and RP row locks | revoked_at; logout timestamps/result | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-visitor-rp-session:T003 | DOCUMENTED_TRANSITION | revoked | revoke! repeat | revoked | No source-state guard | replaces revocation/logout timestamp | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-visitor-rp-session:T004 | DOCUMENTED_TRANSITION | revoked | retirement_pending? clock predicate | retired | now >= max issued access exp + leeway; known max | No DB write | app/models/concerns/rp_session.rb | CONFIRMED |

Labels are timestamp/root validity predicates, not stored status strings. A nonrevoked row may be inactive due to parent or refresh expiry; that inactive condition is not a persisted terminal. Retirement_pending? remains true for an unknown maximum access JWT expiry, including legacy rows: hidden operational non-retirement, not failed state. last_logout_status success/no_session/unsupported/failed describes delivery outcome, not RP lifecycle. Max access expiry is monotonic; same-row refresh rotation tracks previous digest, and token exchange recognizes replay. Parent token expiry immediately removes active authority; issued access tokens can outlive revocation until max expiry/leeway. No universal EXPIRED/cancel state.

## idp-operator-token

Implementation: `TokenStatusManagement / RefreshTokenable`. Storage: `operator_tokens` / `actor token status FK`.

Sources: `app/models/concerns/token_status_management.rb`, `app/models/concerns/refresh_tokenable.rb`, `app/models/operator_token.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/token_status_management_test.rb`, `test/models/concerns/refresh_tokenable_test.rb`, `test/models/refresh_token_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-token:T001 | DOCUMENTED_TRANSITION | ACTIVE | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T002 | DOCUMENTED_TRANSITION | ACTIVE | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T003 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T004 | DOCUMENTED_TRANSITION | EXPIRED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T005 | DOCUMENTED_TRANSITION | EXPIRED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T006 | DOCUMENTED_TRANSITION | EXPIRED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T007 | DOCUMENTED_TRANSITION | RESTRICTED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T008 | DOCUMENTED_TRANSITION | RESTRICTED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T009 | DOCUMENTED_TRANSITION | RESTRICTED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T010 | DOCUMENTED_TRANSITION | REVOKED | promote_to_active! | ACTIVE | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T011 | DOCUMENTED_TRANSITION | REVOKED | mark_restricted! | RESTRICTED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T012 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | Public method has no source-status guard | status/timestamp; revoke discards and closes step-up | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T013 | DOCUMENTED_TRANSITION | ACTIVE | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-operator-token:T014 | DOCUMENTED_TRANSITION | RESTRICTED | rotate_refresh! | rotated | usable; matching digest; actor/device/token locks; no previous rotation | rotated_at; revoke old step-up; replacement row; generation+1 | app/models/concerns/refresh_tokenable.rb | CONFIRMED |
| idp-operator-token:T015 | OUT_OF_BAND | NOTHING | promote_to_active! | ACTIVE | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T016 | OUT_OF_BAND | NOTHING | mark_restricted! | RESTRICTED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |
| idp-operator-token:T017 | OUT_OF_BAND | NOTHING | revoke! | REVOKED | Public method has no source-status guard; model/schema validity still applies | Set status; revoke also discards and revokes linked step-up authority | app/models/concerns/token_status_management.rb | CONFIRMED |

EXPIRED is a reference id, but no production setter was found; time/discard/rotation independently make a row unusable without setting EXPIRED. Public promote/restrict APIs lack a source-status guard and can change a revoked/expired id, although retained discard/rotation prevents usability; therefore no universal absorbing terminal is drawn. revoke! is locked and clears bound step-up authority; promote/restrict are status saves without their own row lock. Refresh rotation marks old row unusable and creates a separate replacement, not an old row transition back to ACTIVE. Old digest replay returns replay; surrounding verifier can revoke family. Device current-refresh ownership is distinct. Default constructor uses ACTIVE; restricted issuance is an existing path. Storage includes status plus discard_at/rotated_at/generation rather than a single lifecycle authority; DBSC is independently indexed.

## idp-operator-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `operator_tokens` / `actor token DBSC status FK`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/authentication_base.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-operator-preference-dbsc

Implementation: `DbscBindable / DbscRegistrationService`. Storage: `org_preferences` / `dbsc_status_id`.

Sources: `app/models/concerns/dbsc_bindable.rb`, `app/services/dbsc_registration_service.rb`, `app/services/dbsc_record_adapter.rb`, `app/controllers/concerns/preference_dbsc_registration_endpoint.rb`.

Tests read: `test/models/concerns/dbsc_bindable_test.rb`, `test/services/dbsc/registration_service_test.rb`, `test/controllers/concerns/preference/dbsc_registration_endpoint_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-preference-dbsc:T001 | DOCUMENTED_TRANSITION | NOTHING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-preference-dbsc:T002 | DOCUMENTED_TRANSITION | ACTIVE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-preference-dbsc:T003 | DOCUMENTED_TRANSITION | ACTIVE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-preference-dbsc:T004 | DOCUMENTED_TRANSITION | PENDING | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-preference-dbsc:T005 | DOCUMENTED_TRANSITION | PENDING | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-preference-dbsc:T006 | DOCUMENTED_TRANSITION | FAILED | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-preference-dbsc:T007 | DOCUMENTED_TRANSITION | FAILED | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |
| idp-operator-preference-dbsc:T008 | DOCUMENTED_TRANSITION | REVOKE | verified DbscRegistrationService.call | ACTIVE | Proof/challenge/signature accepted; row lock; no explicit source-status guard | binding_method DBSC; public key; session id; clear challenge | app/services/dbsc_registration_service.rb | CONFIRMED |
| idp-operator-preference-dbsc:T009 | DOCUMENTED_TRANSITION | REVOKE | downgrade_dbsc_status_to_nothing! | NOTHING | Public helper only tests already NOTHING | status only; keeps binding method | app/models/concerns/dbsc_bindable.rb | CONFIRMED |

DBSC is independent of login token lifecycle and device-session dbsc_bound_at. FAILED/REVOKE are reference/predicate vocabulary with no located production setter; proof failure returns ok:false without writing FAILED. Token creation selects PENDING when a challenge is offered, otherwise NOTHING. No PENDING expiry state write: refresh downgrade to NOTHING leaves legacy binding explicit. Preference creation defaults are in topology; no preference pending writer was confirmed. Registration validates proof before acquiring record lock and does not recheck source state in its write; concurrency/replay is controlled by proof validation and challenge transport, not a transition map. Public downgrade can change any non-NOTHING status. No terminal state is universally enforced. Tests are inspected, not executed.

## idp-operator-device-session

Implementation: `DeviceSessionable`. Storage: `operator_device_sessions` / `status_id`.

Sources: `app/models/concerns/device_sessionable.rb`, `app/models/operator_device_session.rb`, `app/models/concerns/refresh_tokenable.rb`.

Tests read: `test/models/concerns/device_sessionable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-device-session:T001 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No own source guard or lock | status and revoked_at/reason | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-operator-device-session:T002 | DOCUMENTED_TRANSITION | REVOKED | revoke! replay | REVOKED | No guard; preserves first revoked_at | reason may change | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-operator-device-session:T003 | OUT_OF_BAND | ACTIVE | bind_dbsc! | ACTIVE | No own lifecycle guard | update_columns digest/thumbprint/dbsc_bound_at | app/models/concerns/device_sessionable.rb | CONFIRMED |
| idp-operator-device-session:T004 | DOCUMENTED_TRANSITION | REVOKED | bind_dbsc! public API | REVOKED | No own lifecycle guard | binding columns can still change | app/models/concerns/device_sessionable.rb | CONFIRMED |

No state reference FK or explicit enum validation beyond status presence. status_id and revoked_at duplicate the revoked predicate. revoke! has no own row lock; surrounding root rotation/revocation callers may supply locks. bind_dbsc! uses update_columns even for revoked rows; binding is a subordinate axis, not reactivation. Token/device composite owner and current refresh FKs do not encode status transitions. No own expires_at/expiry/cancel/failure state; root token lifetimes govern authentication.

## idp-operator-rp-session

Implementation: `RpSession`. Storage: `operator_rp_sessions` / `revoked_at / expires_at`.

Sources: `app/models/concerns/rp_session.rb`, `app/models/operator_rp_session.rb`, `app/operations/rp_session_revoker.rb`.

Tests read: `test/models/rp_session_test.rb`, `test/models/rp_session_retirement_window_test.rb`, `test/operations/rp_session_revoker_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-rp-session:T001 | DOCUMENTED_TRANSITION | active | issue_refresh_token! / rotate_refresh_token! | active | Parent and RP row locks; active root; absolute expiry cap | digest/previous digest/last_used/refresh expiry | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-operator-rp-session:T002 | DOCUMENTED_TRANSITION | active | revoke! | revoked | Parent and RP row locks | revoked_at; logout timestamps/result | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-operator-rp-session:T003 | DOCUMENTED_TRANSITION | revoked | revoke! repeat | revoked | No source-state guard | replaces revocation/logout timestamp | app/models/concerns/rp_session.rb | CONFIRMED |
| idp-operator-rp-session:T004 | DOCUMENTED_TRANSITION | revoked | retirement_pending? clock predicate | retired | now >= max issued access exp + leeway; known max | No DB write | app/models/concerns/rp_session.rb | CONFIRMED |

Labels are timestamp/root validity predicates, not stored status strings. A nonrevoked row may be inactive due to parent or refresh expiry; that inactive condition is not a persisted terminal. Retirement_pending? remains true for an unknown maximum access JWT expiry, including legacy rows: hidden operational non-retirement, not failed state. last_logout_status success/no_session/unsupported/failed describes delivery outcome, not RP lifecycle. Max access expiry is monotonic; same-row refresh rotation tracks previous digest, and token exchange recognizes replay. Parent token expiry immediately removes active authority; issued access tokens can outlive revocation until max expiry/leeway. No universal EXPIRED/cancel state.

## idp-visitor-secret-credential

Implementation: `SecretCredential / SignSecretVerify`. Storage: `visitor_secret_credentials` / `visitor_secret_credential_status_id`.

Sources: `app/models/concerns/secret_credential.rb`, `app/models/visitor_secret_credential_status.rb`, `app/models/visitor_secret_credential.rb`, `app/services/sign_secret_verify.rb`, `app/services/visitor_secret_credentials_create.rb`.

Tests read: `test/models/concerns/secret_credential_test.rb`, `test/models/visitor_secret_credential_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-secret-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | expire_if_needed! | EXPIRED | active; finite discard_at <= now (infinity ignored) | FK status save | app/models/concerns/secret_credential.rb | CONFIRMED |
| idp-visitor-secret-credential:T002 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify accepted single-use | USED | Matching new-axis credential; not expired/locked/revoked/consumed | consumed_at/use_count; status USED | app/services/sign_secret_verify.rb | CONFIRMED |
| idp-visitor-secret-credential:T003 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify mismatch at failure cap | REVOKED | Mismatch; max_failures finite and reached; normally row lock (blank input failure occurs before lock) | Increment failure_count; locked_at; revoked status | app/services/sign_secret_verify.rb | CONFIRMED |
| idp-visitor-secret-credential:T004 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify accepted reusable secret | ACTIVE | Current active unexpired unlocked matching credential; usage policy permits | Increment use_count / last_used_at | app/services/sign_secret_verify.rb | CONFIRMED |
| idp-visitor-secret-credential:T005 | OUT_OF_BAND | ACTIVE | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-secret-credential:T006 | OUT_OF_BAND | EXPIRED | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-secret-credential:T007 | OUT_OF_BAND | REVOKED | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-secret-credential:T008 | OUT_OF_BAND | USED | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-secret-credential:T009 | OUT_OF_BAND | DELETED | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-secret-credential:T010 | OUT_OF_BAND | NOTHING | withdrawal anonymize | REVOKED | Actor association iteration; dynamic status key; no source-status guard | status revoked; discard_at when supported | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |

Current realm ids differ: operator EXPIRED=3/REVOKED=4/USED=5, visitor EXPIRED=2/REVOKED=3/USED=4. `SecretCredential` has no transition graph/locks; expire_if_needed! ignores both infinity sentinels. Verification locks through SignSecretVerify and writes consumed/use_count/status for single-use. Status and timestamps/usage are separate admission authorities. Operator legacy services write staff_secret_status_id whereas concrete storage is staff_identity_secret_status_id; concrete alias_attribute maps these names, so service writes target the storage column. No model cancel path; revoked/deleted enabling is not inherently forbidden by update service. This legacy generic machine is not the current app/client Secret rebuild.

## idp-operator-secret-credential

Implementation: `SecretCredential / SignSecretVerify`. Storage: `operator_secret_credentials` / `staff_identity_secret_status_id`.

Sources: `app/models/concerns/secret_credential.rb`, `app/models/operator_secret_credential_status.rb`, `app/models/operator_secret_credential.rb`, `app/services/sign_secret_verify.rb`, `app/services/operator_secret_credentials_update.rb`, `app/services/operator_secret_credentials_destroy.rb`.

Tests read: `test/models/concerns/secret_credential_test.rb`, `test/models/operator_secret_credential_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-secret-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | expire_if_needed! | EXPIRED | active; finite discard_at <= now (infinity ignored) | FK status save | app/models/concerns/secret_credential.rb | CONFIRMED |
| idp-operator-secret-credential:T002 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify accepted single-use | USED | Matching new-axis credential; not expired/locked/revoked/consumed | consumed_at/use_count; status USED | app/services/sign_secret_verify.rb | CONFIRMED |
| idp-operator-secret-credential:T003 | DOCUMENTED_TRANSITION | ACTIVE | OperatorSecretCredentialsUpdate enabled | ACTIVE | enabled true; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T004 | DOCUMENTED_TRANSITION | ACTIVE | OperatorSecretCredentialsUpdate disabled | REVOKED | enabled false; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T005 | DOCUMENTED_TRANSITION | ACTIVE | OperatorSecretCredentialsDestroy | DELETED | concrete OperatorSecretCredential alias staff_secret_status_id confirmed | discard and status alias; audit | app/services/operator_secret_credentials_destroy.rb | CONFIRMED |
| idp-operator-secret-credential:T006 | DOCUMENTED_TRANSITION | DELETED | OperatorSecretCredentialsUpdate enabled | ACTIVE | enabled true; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T007 | DOCUMENTED_TRANSITION | DELETED | OperatorSecretCredentialsUpdate disabled | REVOKED | enabled false; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T008 | DOCUMENTED_TRANSITION | DELETED | OperatorSecretCredentialsDestroy | DELETED | concrete OperatorSecretCredential alias staff_secret_status_id confirmed | discard and status alias; audit | app/services/operator_secret_credentials_destroy.rb | CONFIRMED |
| idp-operator-secret-credential:T009 | DOCUMENTED_TRANSITION | EXPIRED | OperatorSecretCredentialsUpdate enabled | ACTIVE | enabled true; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T010 | DOCUMENTED_TRANSITION | EXPIRED | OperatorSecretCredentialsUpdate disabled | REVOKED | enabled false; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T011 | DOCUMENTED_TRANSITION | EXPIRED | OperatorSecretCredentialsDestroy | DELETED | concrete OperatorSecretCredential alias staff_secret_status_id confirmed | discard and status alias; audit | app/services/operator_secret_credentials_destroy.rb | CONFIRMED |
| idp-operator-secret-credential:T012 | DOCUMENTED_TRANSITION | REVOKED | OperatorSecretCredentialsUpdate enabled | ACTIVE | enabled true; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T013 | DOCUMENTED_TRANSITION | REVOKED | OperatorSecretCredentialsUpdate disabled | REVOKED | enabled false; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T014 | DOCUMENTED_TRANSITION | REVOKED | OperatorSecretCredentialsDestroy | DELETED | concrete OperatorSecretCredential alias staff_secret_status_id confirmed | discard and status alias; audit | app/services/operator_secret_credentials_destroy.rb | CONFIRMED |
| idp-operator-secret-credential:T015 | DOCUMENTED_TRANSITION | USED | OperatorSecretCredentialsUpdate enabled | ACTIVE | enabled true; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T016 | DOCUMENTED_TRANSITION | USED | OperatorSecretCredentialsUpdate disabled | REVOKED | enabled false; model save; concrete OperatorSecretCredential alias staff_secret_status_id confirmed | status alias assignment/audit | app/services/operator_secret_credentials_update.rb | CONFIRMED |
| idp-operator-secret-credential:T017 | DOCUMENTED_TRANSITION | USED | OperatorSecretCredentialsDestroy | DELETED | concrete OperatorSecretCredential alias staff_secret_status_id confirmed | discard and status alias; audit | app/services/operator_secret_credentials_destroy.rb | CONFIRMED |
| idp-operator-secret-credential:T018 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify mismatch at failure cap | REVOKED | Mismatch; max_failures finite and reached; normally row lock (blank input failure occurs before lock) | Increment failure_count; locked_at; revoked status | app/services/sign_secret_verify.rb | CONFIRMED |
| idp-operator-secret-credential:T019 | DOCUMENTED_TRANSITION | ACTIVE | SignSecretVerify accepted reusable secret | ACTIVE | Current active unexpired unlocked matching credential; usage policy permits | Increment use_count / last_used_at | app/services/sign_secret_verify.rb | CONFIRMED |

Current realm ids differ: operator EXPIRED=3/REVOKED=4/USED=5, visitor EXPIRED=2/REVOKED=3/USED=4. `SecretCredential` has no transition graph/locks; expire_if_needed! ignores both infinity sentinels. Verification locks through SignSecretVerify and writes consumed/use_count/status for single-use. Status and timestamps/usage are separate admission authorities. Operator legacy services write staff_secret_status_id whereas concrete storage is staff_identity_secret_status_id; concrete alias_attribute maps these names, so service writes target the storage column. No model cancel path; revoked/deleted enabling is not inherently forbidden by update service. This legacy generic machine is not the current app/client Secret rebuild.

## idp-client-secret-credential

Implementation: `ClientSecretCredential (current rebuild)`. Storage: `client_secret_credentials` / `confirmed_at / claimed_at / claim_operation_id / revoked_at / discard_at`.

Sources: `app/models/client_secret_credential.rb`, `app/operations/client_secret_storage_confirmation_committer.rb`, `app/operations/client_secret_revocation_committer.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`.

Tests read: `test/operations/client_secret_storage_confirmation_committer_test.rb`, `test/operations/client_secret_revocation_committer_test.rb`, `test/models/client_secret_credential_rebuild_test.rb`, `test/models/client_secret_credential_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-secret-credential:T001 | DOCUMENTED_TRANSITION | candidate | commit_storage_confirmation! | available | Source DB transaction; audited owning issuance; no claim/revoke; accessible | immutable confirmed_at | app/models/client_secret_credential.rb | CONFIRMED |
| idp-client-secret-credential:T002 | DOCUMENTED_TRANSITION | available | commit_management_revocation! | revoked | Bound Base actor; locks; current availability; can_remove guard; audit | revoked_at/discard_at/purge; two source events | app/models/client_secret_credential.rb | CONFIRMED |
| idp-client-secret-credential:T003 | DOCUMENTED_TRANSITION | candidate | issuance cancel/expiry invalidator | discarded | Locked pending allocation; no confirmed/claim/revoke fact | discard/purge; audit; payload retirement | app/operations/client_secret_manual_issuance_invalidator.rb | CONFIRMED |
| idp-client-secret-credential:T004 | DOCUMENTED_TRANSITION | available | correct value and admitted browser flow | claimed | Client and credential locks; durable primary-pending Ticket flow and ceremony; complete value match; local admission or locked pending app OIDC transaction uniquely referencing that flow with matching admitted authorization ceremony | Source claim, immutable operation/flow binding and outbox; OIDC evidence/session HTTP wiring remains incomplete | app/operations/client_secret_claim_committer.rb; app/models/client_secret_credential.rb | CONFIRMED |
| idp-client-secret-credential:T005 | DOCUMENTED_TRANSITION | claimed | canonical root receipt confirmed | discarded | Flow lock; matching committed Token and receipt | consumed_at, discard_at, retention and source audit | app/operations/client_secret_claim_finalizer.rb | CONFIRMED |
| idp-client-secret-credential:T006 | DOCUMENTED_TRANSITION | claimed | terminal unsuccessful flow confirmed | discarded | Same Ticket exclusion as canonical issuance; no successful receipt; matching persisted browser ceremony; terminal ownership repair after Ticket rollback only | Irreversible discard and reason-bearing source audit; unknown outcome remains claimed | app/operations/client_secret_claim_finalizer.rb | CONFIRMED |
| idp-client-secret-credential:T007 | DOCUMENTED_TRANSITION | discarded | physical collection | purged | Retention deadline and hold guards; credential-specific discarded event acknowledged and identity-matched in Chronicle; unconfirmed non-withdrawal candidate also requires acknowledged allocation terminal event | Source DELETE and surviving secret.purged outbox commit atomically; partial terminal delivery holds candidate | app/operations/client_secret_credential_purger.rb | CONFIRMED |


Current ClientSecretCredential does not include SecretCredential and has no status FK. It derives availability from immutable confirmation/claim/revocation/retention facts. ClientSecretClaimCommitter rereads admitted flow and ceremony under Ticket locks and commits an irreversible source claim. AuthenticationBase writes a matching success receipt in the canonical Token transaction; ClientSecretClaimFinalizer consumes and discards only after verifying it. Unknown outcomes remain claimed. Legacy ClientSecretCredentialStatus class/tests remain, but current DB ownership is issuance_id→client_secret_issuances plus client_id. `client_secret_credential_test.rb` still expects issue!/kind/status/legacy methods absent in the current model; mismatch documented without running/reconciling tests. Revocation/confirmation guard ordinary assignments and update_columns; issuing/signing-in and presentation wiring must not be assumed complete from target ADR. No conventional FAILED/CANCELLED/EXPIRED status; issuance cancellation affects unconfirmed allocation only.

## idp-client-withdrawal-ceremony

Implementation: `WithdrawalCeremonyRecordable`. Storage: `client_withdrawal_ceremonies` / `status_id`.

Sources: `app/models/concerns/withdrawal_ceremony_recordable.rb`, `app/models/client_withdrawal_ceremony.rb`, `app/controllers/concerns/withdrawal_ceremony_authentication.rb`.

Tests read: `test/integration/withdrawal_ceremony_session_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-withdrawal-ceremony:T001 | DOCUMENTED_TRANSITION | ACTIVE | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T002 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T003 | DOCUMENTED_TRANSITION | CONSUMED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T004 | DOCUMENTED_TRANSITION | CONSUMED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T005 | DOCUMENTED_TRANSITION | REVOKED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T006 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T007 | DOCUMENTED_TRANSITION | EXPIRED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-client-withdrawal-ceremony:T008 | DOCUMENTED_TRANSITION | EXPIRED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |

No state reference table is used despite integer status_id. Active authentication verifies token digest and TTL 30m; withdrawal additionally requires restricted/terminated subject. consume!/revoke! themselves have no guards/locks and can rewrite terminal ids, leaving both timestamps populated; therefore no universally absorbing terminal is drawn. Expiry is predicate-only; withdrawal EXPIRED=4 is accepted but no production setter found. This proof does not create a normal authenticated session. Callers must supply operation binding and guards; replay protection cannot be inferred from these two setters alone.

## idp-client-enforcement-recovery-ceremony

Implementation: `EnforcementRecoveryCeremonyRecordable`. Storage: `client_enforcement_recovery_ceremonies` / `status_id`.

Sources: `app/models/concerns/enforcement_recovery_ceremony_recordable.rb`, `app/models/client_enforcement_recovery_ceremony.rb`, `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb`.

Tests read: `test/models/enforcement_recovery_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-enforcement-recovery-ceremony:T001 | DOCUMENTED_TRANSITION | ACTIVE | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-client-enforcement-recovery-ceremony:T002 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-client-enforcement-recovery-ceremony:T003 | DOCUMENTED_TRANSITION | CONSUMED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-client-enforcement-recovery-ceremony:T004 | DOCUMENTED_TRANSITION | CONSUMED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-client-enforcement-recovery-ceremony:T005 | DOCUMENTED_TRANSITION | REVOKED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-client-enforcement-recovery-ceremony:T006 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |

No state reference table is used despite integer status_id. Active authentication verifies token digest and TTL 30m; withdrawal additionally requires restricted/terminated subject. consume!/revoke! themselves have no guards/locks and can rewrite terminal ids, leaving both timestamps populated; therefore no universally absorbing terminal is drawn. Expiry is predicate-only; withdrawal EXPIRED=4 is accepted but no production setter found. This proof does not create a normal authenticated session. Callers must supply operation binding and guards; replay protection cannot be inferred from these two setters alone.

## idp-visitor-withdrawal-ceremony

Implementation: `WithdrawalCeremonyRecordable`. Storage: `visitor_withdrawal_ceremonies` / `status_id`.

Sources: `app/models/concerns/withdrawal_ceremony_recordable.rb`, `app/models/visitor_withdrawal_ceremony.rb`, `app/controllers/concerns/withdrawal_ceremony_authentication.rb`.

Tests read: `test/integration/withdrawal_ceremony_session_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-withdrawal-ceremony:T001 | DOCUMENTED_TRANSITION | ACTIVE | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T002 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T003 | DOCUMENTED_TRANSITION | CONSUMED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T004 | DOCUMENTED_TRANSITION | CONSUMED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T005 | DOCUMENTED_TRANSITION | REVOKED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T006 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T007 | DOCUMENTED_TRANSITION | EXPIRED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-withdrawal-ceremony:T008 | DOCUMENTED_TRANSITION | EXPIRED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/withdrawal_ceremony_recordable.rb | CONFIRMED |

No state reference table is used despite integer status_id. Active authentication verifies token digest and TTL 30m; withdrawal additionally requires restricted/terminated subject. consume!/revoke! themselves have no guards/locks and can rewrite terminal ids, leaving both timestamps populated; therefore no universally absorbing terminal is drawn. Expiry is predicate-only; withdrawal EXPIRED=4 is accepted but no production setter found. This proof does not create a normal authenticated session. Callers must supply operation binding and guards; replay protection cannot be inferred from these two setters alone.

## idp-visitor-enforcement-recovery-ceremony

Implementation: `EnforcementRecoveryCeremonyRecordable`. Storage: `visitor_enforcement_recovery_ceremonies` / `status_id`.

Sources: `app/models/concerns/enforcement_recovery_ceremony_recordable.rb`, `app/models/visitor_enforcement_recovery_ceremony.rb`, `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb`.

Tests read: `test/models/enforcement_recovery_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-enforcement-recovery-ceremony:T001 | DOCUMENTED_TRANSITION | ACTIVE | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-enforcement-recovery-ceremony:T002 | DOCUMENTED_TRANSITION | ACTIVE | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-enforcement-recovery-ceremony:T003 | DOCUMENTED_TRANSITION | CONSUMED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-enforcement-recovery-ceremony:T004 | DOCUMENTED_TRANSITION | CONSUMED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-enforcement-recovery-ceremony:T005 | DOCUMENTED_TRANSITION | REVOKED | consume! | CONSUMED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |
| idp-visitor-enforcement-recovery-ceremony:T006 | DOCUMENTED_TRANSITION | REVOKED | revoke! | REVOKED | No public source/expiry guard or row lock | status_id and corresponding timestamp | app/models/concerns/enforcement_recovery_ceremony_recordable.rb | CONFIRMED |

No state reference table is used despite integer status_id. Active authentication verifies token digest and TTL 30m; withdrawal additionally requires restricted/terminated subject. consume!/revoke! themselves have no guards/locks and can rewrite terminal ids, leaving both timestamps populated; therefore no universally absorbing terminal is drawn. Expiry is predicate-only; withdrawal EXPIRED=4 is accepted but no production setter found. This proof does not create a normal authenticated session. Callers must supply operation binding and guards; replay protection cannot be inferred from these two setters alone.

## idp-client-withdrawal

Implementation: `FlowWithdrawal / WithdrawalLifecycle`. Storage: `client_withdrawal_flows` / `status_id`.

Sources: `app/models/concerns/flow_withdrawal.rb`, `app/models/concerns/withdrawal_flow.rb`, `app/models/client_withdrawal_flow.rb`, `app/models/client_withdrawal_flow_status.rb`, `app/services/withdrawal_lifecycle.rb`.

Tests read: `test/models/withdrawal_flow_test.rb`, `test/services/withdrawal_lifecycle_test.rb`, `test/integration/withdrawal_lifecycle_security_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-withdrawal:T001 | DOCUMENTED_TRANSITION | NOTHING | request_withdrawal! | REQUESTED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T002 | DOCUMENTED_TRANSITION | REQUESTED | confirm_withdrawal! | CLOSING | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T003 | DOCUMENTED_TRANSITION | CLOSING | discard_withdrawal! | DISCARDED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T004 | DOCUMENTED_TRANSITION | DISCARDED | recover_withdrawal! | RECOVERED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T005 | DOCUMENTED_TRANSITION | DISCARDED | terminate_withdrawal! | TERMINATED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T006 | DOCUMENTED_TRANSITION | REQUESTED | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T007 | DOCUMENTED_TRANSITION | CLOSING | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-client-withdrawal:T008 | DOCUMENTED_TRANSITION | DISCARDED | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |

RECOVERED=40 and TERMINATED=100 are formal terminals. FAILED=900 has no outgoing edge yet WithdrawalFlow.terminal? excludes it: hidden terminal/dead end. Default creation REQUESTED records NOTHING→REQUESTED event via after_create. Events have from/to FKs with RESTRICT NOT VALID; they are records of transitions, not ownership authority. WithdrawalLifecycle orchestrates actor closing/discarded/terminated timestamps, revokes sessions and issues withdrawal proof; actor state facts are related independent authority. Recovery is an explicit permitted edge from DISCARDED, not generic back. No cancel/expiry status path; recovery deadline is owned by lifecycle/actor retention logic.

## idp-visitor-withdrawal

Implementation: `FlowWithdrawal / WithdrawalLifecycle`. Storage: `visitor_withdrawal_flows` / `status_id`.

Sources: `app/models/concerns/flow_withdrawal.rb`, `app/models/concerns/withdrawal_flow.rb`, `app/models/visitor_withdrawal_flow.rb`, `app/models/visitor_withdrawal_flow_status.rb`, `app/services/withdrawal_lifecycle.rb`.

Tests read: `test/models/withdrawal_flow_test.rb`, `test/services/withdrawal_lifecycle_test.rb`, `test/integration/withdrawal_lifecycle_security_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-withdrawal:T001 | DOCUMENTED_TRANSITION | NOTHING | request_withdrawal! | REQUESTED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T002 | DOCUMENTED_TRANSITION | REQUESTED | confirm_withdrawal! | CLOSING | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T003 | DOCUMENTED_TRANSITION | CLOSING | discard_withdrawal! | DISCARDED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T004 | DOCUMENTED_TRANSITION | DISCARDED | recover_withdrawal! | RECOVERED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T005 | DOCUMENTED_TRANSITION | DISCARDED | terminate_withdrawal! | TERMINATED | Source matches; accessible; row lock | status plus immutable transition event; terminal completed_at | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T006 | DOCUMENTED_TRANSITION | REQUESTED | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T007 | DOCUMENTED_TRANSITION | CLOSING | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |
| idp-visitor-withdrawal:T008 | DOCUMENTED_TRANSITION | DISCARDED | fail_withdrawal! | FAILED | source matches; accessible; row lock | failed_at and event | app/models/concerns/flow_withdrawal.rb | CONFIRMED |

RECOVERED=40 and TERMINATED=100 are formal terminals. FAILED=900 has no outgoing edge yet WithdrawalFlow.terminal? excludes it: hidden terminal/dead end. Default creation REQUESTED records NOTHING→REQUESTED event via after_create. Events have from/to FKs with RESTRICT NOT VALID; they are records of transitions, not ownership authority. WithdrawalLifecycle orchestrates actor closing/discarded/terminated timestamps, revokes sessions and issues withdrawal proof; actor state facts are related independent authority. Recovery is an explicit permitted edge from DISCARDED, not generic back. No cancel/expiry status path; recovery deadline is owned by lifecycle/actor retention logic.

## idp-client-email-verification-challenge

Implementation: `EmailVerificationChallengeable`. Storage: `client_email_ceremony_transactions` / `evp_outcome / expires_at`.

Sources: `app/models/concerns/email_verification_challengeable.rb`, `app/models/client_email_ceremony_transaction.rb`.

Tests read: `test/models/email_verification_challengeable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-email-verification-challenge:T001 | DOCUMENTED_TRANSITION | pending | record_evp_verified! | verified | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-client-email-verification-challenge:T002 | DOCUMENTED_TRANSITION | pending | record_evp_fallback! | fallback | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-client-email-verification-challenge:T003 | DOCUMENTED_TRANSITION | pending | record_evp_rejected! | rejected | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |

This outcome is persisted as a separate EVP submachine; it does not consume the parent ceremony result or verify the email credential. SQL ownership remains the email ceremony transaction, not a new reference FK. TTL shares expires_at (10 minutes); no expired/cancel state. Terminal outcomes refuse replay; unique evp_token_digest prevents cross-challenge token reuse. No production callsites for issue_evp_challenge!/record_evp_* were found outside this declaration; tests exercise model API, so HTTP runtime wiring is UNCONFIRMED. Legacy email ceremonies allow evp_outcome nil.

## idp-client-email-otp

Implementation: `OtpLockable / Email`. Storage: `client_emails` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/client_email.rb`, `app/models/concerns/email.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-email-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-email-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-email-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-email-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-email-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-email-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-client-telephone-otp

Implementation: `OtpLockable / Telephone`. Storage: `client_telephones` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/client_telephone.rb`, `app/models/concerns/telephone.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-telephone-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-telephone-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-telephone-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-telephone-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-telephone-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-client-telephone-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-client-dpop-nonce

Implementation: `DpopProofStateable`. Storage: `client_dpop_proof_states` / `nonce_used_at / expires_at`.

Sources: `app/models/concerns/dpop_proof_stateable.rb`, `app/models/client_dpop_proof_state.rb`, `app/services/dpop_nonce_service.rb`, `app/lib/dpop_proof_verifier.rb`, `app/jobs/dpop_proof_state_purge_job.rb`.

Tests read: `test/models/concerns/dpop_proof_stateable_test.rb`, `test/services/dpop/nonce_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-dpop-nonce:T001 | DOCUMENTED_TRANSITION | unused | consume_nonce! | used | nonce match; expires_at>now; unconsumed lookup | nonce_used_at | app/models/concerns/dpop_proof_stateable.rb | CONFIRMED |

TTL 300 seconds; no reference or expiry state. JTI insertion in the same table is append-only replay bookkeeping, excluded as a separate mutable machine. consume_nonce! uses SELECT lock but has no explicit enclosing transaction across lookup/update; do not claim that alone guarantees one winner. Time expiry rejects use; purge deletes expired rows. Base connection role switching and actual multi-DB runtime are not verified. Nonce handshake and JTI verification are external proof boundaries; rejection is a result.

## idp-client-administrative-access

Implementation: `AdministrativeAccessLock`. Storage: `clients` / `access_state`.

Sources: `app/services/administrative_access_lock.rb`, `app/models/concerns/administrative_access_lockable.rb`, `app/models/client.rb`, `app/models/account_access_event.rb`.

Tests read: `test/services/administrative_access_lock_test.rb`, `test/models/concerns/administrative_access_lockable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-administrative-access:T001 | DOCUMENTED_TRANSITION | enabled | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-client-administrative-access:T002 | DOCUMENTED_TRANSITION | enabled | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-client-administrative-access:T003 | DOCUMENTED_TRANSITION | admin_locked | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-client-administrative-access:T004 | DOCUMENTED_TRANSITION | admin_locked | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |

Actor access_state CHECK default enabled, no reference FK. Model consistency binds lock metadata; audit events persist previous/next strings in Chronicle. No source-state guard: lock repeats reaffirmed event, unlock repeats enabled state. Account update commits before session revocation/event creation on other DBs; no distributed atomicity is inferred. This state is separate from identity/provisioning, withdrawal or Entra entitlement. No time expiry or cancellation: explicit administrator unlock is escape.

## idp-visitor-email-verification-challenge

Implementation: `EmailVerificationChallengeable`. Storage: `visitor_email_ceremony_transactions` / `evp_outcome / expires_at`.

Sources: `app/models/concerns/email_verification_challengeable.rb`, `app/models/visitor_email_ceremony_transaction.rb`.

Tests read: `test/models/email_verification_challengeable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-email-verification-challenge:T001 | DOCUMENTED_TRANSITION | pending | record_evp_verified! | verified | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-visitor-email-verification-challenge:T002 | DOCUMENTED_TRANSITION | pending | record_evp_fallback! | fallback | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-visitor-email-verification-challenge:T003 | DOCUMENTED_TRANSITION | pending | record_evp_rejected! | rejected | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |

This outcome is persisted as a separate EVP submachine; it does not consume the parent ceremony result or verify the email credential. SQL ownership remains the email ceremony transaction, not a new reference FK. TTL shares expires_at (10 minutes); no expired/cancel state. Terminal outcomes refuse replay; unique evp_token_digest prevents cross-challenge token reuse. No production callsites for issue_evp_challenge!/record_evp_* were found outside this declaration; tests exercise model API, so HTTP runtime wiring is UNCONFIRMED. Legacy email ceremonies allow evp_outcome nil.

## idp-visitor-email-otp

Implementation: `OtpLockable / Email`. Storage: `visitor_emails` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/visitor_email.rb`, `app/models/concerns/email.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-email-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-email-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-email-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-email-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-email-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-email-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-visitor-telephone-otp

Implementation: `OtpLockable / Telephone`. Storage: `visitor_telephones` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/visitor_telephone.rb`, `app/models/concerns/telephone.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-telephone-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-telephone-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-telephone-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-telephone-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-telephone-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-visitor-telephone-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-visitor-dpop-nonce

Implementation: `DpopProofStateable`. Storage: `visitor_dpop_proof_states` / `nonce_used_at / expires_at`.

Sources: `app/models/concerns/dpop_proof_stateable.rb`, `app/models/visitor_dpop_proof_state.rb`, `app/services/dpop_nonce_service.rb`, `app/lib/dpop_proof_verifier.rb`, `app/jobs/dpop_proof_state_purge_job.rb`.

Tests read: `test/models/concerns/dpop_proof_stateable_test.rb`, `test/services/dpop/nonce_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-dpop-nonce:T001 | DOCUMENTED_TRANSITION | unused | consume_nonce! | used | nonce match; expires_at>now; unconsumed lookup | nonce_used_at | app/models/concerns/dpop_proof_stateable.rb | CONFIRMED |

TTL 300 seconds; no reference or expiry state. JTI insertion in the same table is append-only replay bookkeeping, excluded as a separate mutable machine. consume_nonce! uses SELECT lock but has no explicit enclosing transaction across lookup/update; do not claim that alone guarantees one winner. Time expiry rejects use; purge deletes expired rows. Base connection role switching and actual multi-DB runtime are not verified. Nonce handshake and JTI verification are external proof boundaries; rejection is a result.

## idp-visitor-administrative-access

Implementation: `AdministrativeAccessLock`. Storage: `visitors` / `access_state`.

Sources: `app/services/administrative_access_lock.rb`, `app/models/concerns/administrative_access_lockable.rb`, `app/models/visitor.rb`, `app/models/account_access_event.rb`.

Tests read: `test/services/administrative_access_lock_test.rb`, `test/models/concerns/administrative_access_lockable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-administrative-access:T001 | DOCUMENTED_TRANSITION | enabled | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-visitor-administrative-access:T002 | DOCUMENTED_TRANSITION | enabled | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-visitor-administrative-access:T003 | DOCUMENTED_TRANSITION | admin_locked | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-visitor-administrative-access:T004 | DOCUMENTED_TRANSITION | admin_locked | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |

Actor access_state CHECK default enabled, no reference FK. Model consistency binds lock metadata; audit events persist previous/next strings in Chronicle. No source-state guard: lock repeats reaffirmed event, unlock repeats enabled state. Account update commits before session revocation/event creation on other DBs; no distributed atomicity is inferred. This state is separate from identity/provisioning, withdrawal or Entra entitlement. No time expiry or cancellation: explicit administrator unlock is escape.

## idp-operator-email-verification-challenge

Implementation: `EmailVerificationChallengeable`. Storage: `operator_email_ceremony_transactions` / `evp_outcome / expires_at`.

Sources: `app/models/concerns/email_verification_challengeable.rb`, `app/models/operator_email_ceremony_transaction.rb`.

Tests read: `test/models/email_verification_challengeable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-email-verification-challenge:T001 | DOCUMENTED_TRANSITION | pending | record_evp_verified! | verified | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-operator-email-verification-challenge:T002 | DOCUMENTED_TRANSITION | pending | record_evp_fallback! | fallback | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |
| idp-operator-email-verification-challenge:T003 | DOCUMENTED_TRANSITION | pending | record_evp_rejected! | rejected | pending; TTL>now; row lock; required token/metadata/reason | digest only; evp_consumed_at; attempts; unique token digest | app/models/concerns/email_verification_challengeable.rb | CONFIRMED |

This outcome is persisted as a separate EVP submachine; it does not consume the parent ceremony result or verify the email credential. SQL ownership remains the email ceremony transaction, not a new reference FK. TTL shares expires_at (10 minutes); no expired/cancel state. Terminal outcomes refuse replay; unique evp_token_digest prevents cross-challenge token reuse. No production callsites for issue_evp_challenge!/record_evp_* were found outside this declaration; tests exercise model API, so HTTP runtime wiring is UNCONFIRMED. Legacy email ceremonies allow evp_outcome nil.

## idp-operator-email-otp

Implementation: `OtpLockable / Email`. Storage: `operator_emails` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/operator_email.rb`, `app/models/concerns/email.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-email-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-email-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-email-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-email-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-email-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-email-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-operator-telephone-otp

Implementation: `OtpLockable / Telephone`. Storage: `operator_telephones` / `otp_expires_at / otp_attempts_count / locked_at`.

Sources: `app/models/concerns/otp_lockable.rb`, `app/models/operator_telephone.rb`, `app/models/concerns/telephone.rb`, `app/services/sign_otp_ceremony.rb`, `app/controllers/concerns/common_otp.rb`.

Tests read: `test/models/concerns/otp_lockable_test.rb`, `test/services/sign_otp_ceremony_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-telephone-otp:T001 | DOCUMENTED_TRANSITION | inactive | store_otp | active | Finite future expiry; not actively locked | OTP columns; email sent timestamp | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-telephone-otp:T002 | DOCUMENTED_TRANSITION | active | store_otp reissue | active | No own cooldown/source guard; callers apply policy | Replace OTP generation data | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-telephone-otp:T003 | DOCUMENTED_TRANSITION | active | increment_attempts! threshold | locked | attempts >=5 in 15m window; row lock | locked_at = DB now+15m; validation bypass | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-telephone-otp:T004 | DOCUMENTED_TRANSITION | locked | lockout clock elapsed | active | OTP deadline still future and lock predicate false | No write; conditional derived edge | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-telephone-otp:T005 | DOCUMENTED_TRANSITION | active | OTP deadline elapsed / clear_otp | inactive | Deadline <=now or clear_otp caller | Clock no write; clear uses -infinity | app/models/concerns/otp_lockable.rb | CONFIRMED |
| idp-operator-telephone-otp:T006 | DOCUMENTED_TRANSITION | locked | clear_otp reset_attempts true | inactive | Public method no lock guard | Reset lock/counter/expiry | app/models/concerns/otp_lockable.rb | CONFIRMED |

This is a derived OTP/lock axis on a contact table; credential status_id is separately stored and not inferred from challenge activity. store_otp has no own expiry/lock/reissue policy guard and preserves an existing active lock; diagram active edge is conditional, not unconditional. clear_otp(reset_attempts:false) can leave a lock despite expired OTP, so expired and locked predicates overlap; the diagram presents control-relevant predicates rather than a new enum. Expiry treats blank/infinity/noncomparable values as expired. locked_at actually stores the lockout deadline, not start time. Email attempt window uses otp_last_sent_at; telephone uses created_at. Counter changes serialize with lock and bypass unrelated model validation. SignOtpCeremony supports signup app/com email/telephone; org concern exists but production signup via that service is not inferred. Result locked/invalid_code/verified differs from stored state. No terminal: a new issuance can re-open an expired challenge.

## idp-operator-dpop-nonce

Implementation: `DpopProofStateable`. Storage: `operator_dpop_proof_states` / `nonce_used_at / expires_at`.

Sources: `app/models/concerns/dpop_proof_stateable.rb`, `app/models/operator_dpop_proof_state.rb`, `app/services/dpop_nonce_service.rb`, `app/lib/dpop_proof_verifier.rb`, `app/jobs/dpop_proof_state_purge_job.rb`.

Tests read: `test/models/concerns/dpop_proof_stateable_test.rb`, `test/services/dpop/nonce_service_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-dpop-nonce:T001 | DOCUMENTED_TRANSITION | unused | consume_nonce! | used | nonce match; expires_at>now; unconsumed lookup | nonce_used_at | app/models/concerns/dpop_proof_stateable.rb | CONFIRMED |

TTL 300 seconds; no reference or expiry state. JTI insertion in the same table is append-only replay bookkeeping, excluded as a separate mutable machine. consume_nonce! uses SELECT lock but has no explicit enclosing transaction across lookup/update; do not claim that alone guarantees one winner. Time expiry rejects use; purge deletes expired rows. Base connection role switching and actual multi-DB runtime are not verified. Nonce handshake and JTI verification are external proof boundaries; rejection is a result.

## idp-operator-administrative-access

Implementation: `AdministrativeAccessLock`. Storage: `operators` / `access_state`.

Sources: `app/services/administrative_access_lock.rb`, `app/models/concerns/administrative_access_lockable.rb`, `app/models/operator.rb`, `app/models/account_access_event.rb`.

Tests read: `test/services/administrative_access_lock_test.rb`, `test/models/concerns/administrative_access_lockable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-administrative-access:T001 | DOCUMENTED_TRANSITION | enabled | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-operator-administrative-access:T002 | DOCUMENTED_TRANSITION | enabled | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-operator-administrative-access:T003 | DOCUMENTED_TRANSITION | admin_locked | unlock! | enabled | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |
| idp-operator-administrative-access:T004 | DOCUMENTED_TRANSITION | admin_locked | lock! | admin_locked | Supported actor; Operator executor; reason metadata; account lock; last-enabled-operator guard for lock | access fields; token_valid_after; event; lock revokes sessions | app/services/administrative_access_lock.rb | CONFIRMED |

Actor access_state CHECK default enabled, no reference FK. Model consistency binds lock metadata; audit events persist previous/next strings in Chronicle. No source-state guard: lock repeats reaffirmed event, unlock repeats enabled state. Account update commits before session revocation/event creation on other DBs; no distributed atomicity is inferred. This state is separate from identity/provisioning, withdrawal or Entra entitlement. No time expiry or cancellation: explicit administrator unlock is escape.

## idp-security-one-time-reveal

Implementation: `SecurityOneTimeReveal / IdentityOneTimeReveal`. Storage: `security_one_time_reveals` / `consumed_at / expires_at`.

Sources: `app/models/security_one_time_reveal.rb`, `app/services/identity_one_time_reveal.rb`, `app/controllers/concerns/passkey_registration_flow.rb`, `app/controllers/base/com/identity/recovery_secrets_controller.rb`.

Tests read: `test/models/security_one_time_reveal_test.rb`, `test/services/identity/one_time_reveal_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-security-one-time-reveal:T001 | DOCUMENTED_TRANSITION | unused | IdentityOneTimeReveal.consume! | consumed | Signed claims; actor/session/purpose; expires_at>now; DB row lock | consume before decrypting/returning payload | app/models/security_one_time_reveal.rb | CONFIRMED |

TTL default 15 minutes; expiry makes unused row unreadable with no stored expired state. No reference/cancel/failure state. Consume commits before decrypt/JSON decoding; invalid encrypted payload can therefore burn the reveal even when service returns nil (hidden terminal). One-time actor/session/purpose binding under transaction prevents replay. Uses AppTicketRecord for this existing shared security store; do not infer separate realm tables. Recovery-secret presentation is distinct from credential consumption.

## idp-client-passkey-credential

Implementation: `IdentityPasskeyCeremonyFinalCommitter / IdentityCredentialRemovalCommitter`. Storage: `client_passkeys` / `status_id`.

Sources: `app/models/client_passkey.rb`, `app/models/client_passkey_status.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/operations/identity_credential_removal_committer.rb`.

Tests read: `test/models/client_passkey_test.rb`, `test/operations/identity_credential_removal_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-passkey-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-passkey-credential:T002 | DOCUMENTED_TRANSITION | DISABLED | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-passkey-credential:T003 | DOCUMENTED_TRANSITION | NOTHING | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-passkey-credential:T004 | OUT_OF_BAND | ACTIVE | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-passkey-credential:T005 | OUT_OF_BAND | DISABLED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-passkey-credential:T006 | OUT_OF_BAND | REVOKED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-passkey-credential:T007 | OUT_OF_BAND | DELETED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-passkey-credential:T008 | OUT_OF_BAND | NOTHING | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-passkey-credential:T009 | OUT_OF_BAND | ACTIVE | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-passkey-credential:T010 | OUT_OF_BAND | DISABLED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-passkey-credential:T011 | OUT_OF_BAND | REVOKED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-passkey-credential:T012 | OUT_OF_BAND | DELETED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-client-passkey-credential:T013 | OUT_OF_BAND | NOTHING | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

Registration creates ACTIVE through model default; SQL default and FK are recorded in topology. Operator model explicitly defaults ACTIVE=1, while checked-in SQL default is 0; raw SQL inserts therefore differ from model creation. Slot limit is four under owner lock; retained revoked/deleted history does not consume slots. Removal is idempotent on revoked/deleted and guards the last usable authentication method. Other declared states have no production entry setter identified; model attributes remain assignable. No expiry/cancel state; cancellation belongs to ceremony. Authentication updates sign_count and last_used_at independently of lifecycle.

## idp-visitor-passkey-credential

Implementation: `IdentityPasskeyCeremonyFinalCommitter / IdentityCredentialRemovalCommitter`. Storage: `visitor_passkeys` / `status_id`.

Sources: `app/models/visitor_passkey.rb`, `app/models/visitor_passkey_status.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/operations/identity_credential_removal_committer.rb`.

Tests read: `test/models/visitor_passkey_test.rb`, `test/operations/identity_credential_removal_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-passkey-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T002 | DOCUMENTED_TRANSITION | DISABLED | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T003 | DOCUMENTED_TRANSITION | NOTHING | IdentityCredentialRemovalCommitter | DELETED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T004 | OUT_OF_BAND | ACTIVE | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T005 | OUT_OF_BAND | DISABLED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T006 | OUT_OF_BAND | REVOKED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T007 | OUT_OF_BAND | DELETED | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T008 | OUT_OF_BAND | NOTHING | withdrawal anonymizer direct write | REVOKED | Withdrawal early termination; no credential source guard | Direct REVOKED and discard_at before cross-DB child purge | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-passkey-credential:T009 | OUT_OF_BAND | ACTIVE | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-passkey-credential:T010 | OUT_OF_BAND | DISABLED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-passkey-credential:T011 | OUT_OF_BAND | REVOKED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-passkey-credential:T012 | OUT_OF_BAND | DELETED | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |
| idp-visitor-passkey-credential:T013 | OUT_OF_BAND | NOTHING | SignUpArtifactCleanup dependent retention | DELETED | Selected pending_passkey_registration_id; status column exists; lock; no source-status guard | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

Registration creates ACTIVE through model default; SQL default and FK are recorded in topology. Operator model explicitly defaults ACTIVE=1, while checked-in SQL default is 0; raw SQL inserts therefore differ from model creation. Slot limit is four under owner lock; retained revoked/deleted history does not consume slots. Removal is idempotent on revoked/deleted and guards the last usable authentication method. Other declared states have no production entry setter identified; model attributes remain assignable. No expiry/cancel state; cancellation belongs to ceremony. Authentication updates sign_count and last_used_at independently of lifecycle.

## idp-operator-passkey-credential

Implementation: `IdentityPasskeyCeremonyFinalCommitter / IdentityCredentialRemovalCommitter`. Storage: `operator_passkeys` / `status_id`.

Sources: `app/models/operator_passkey.rb`, `app/models/operator_passkey_status.rb`, `app/operations/identity_passkey_ceremony_final_committer.rb`, `app/operations/identity_credential_removal_committer.rb`.

Tests read: `test/models/operator_passkey_test.rb`, `test/operations/identity_credential_removal_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-passkey-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | IdentityCredentialRemovalCommitter | REVOKED | Owner and credential locks; owning Base context; last method guard; already revoked/deleted returns unchanged | Status update; CredentialSecurityTransition invalidates admissions | app/operations/identity_credential_removal_committer.rb | CONFIRMED |

Registration creates ACTIVE through model default; SQL default and FK are recorded in topology. Operator model explicitly defaults ACTIVE=1, while checked-in SQL default is 0; raw SQL inserts therefore differ from model creation. Slot limit is four under owner lock; retained revoked/deleted history does not consume slots. Removal is idempotent on revoked/deleted and guards the last usable authentication method. Other declared states have no production entry setter identified; model attributes remain assignable. No expiry/cancel state; cancellation belongs to ceremony. Authentication updates sign_count and last_used_at independently of lifecycle.

## idp-client-secret-issuance

Implementation: `ClientSecretIssuance / reservation, confirmation and invalidation operations`. Storage: `client_secret_issuances` / `presented_at / confirmed_at / canceled_at / expires_at`.

Sources: `app/models/client_secret_issuance.rb`, `app/operations/client_secret_manual_reservation_issuer.rb`, `app/operations/client_secret_storage_confirmation_committer.rb`, `app/operations/client_secret_manual_issuance_invalidator.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`.

Tests read: `test/models/client_secret_issuance_test.rb`, `test/operations/client_secret_storage_confirmation_committer_test.rb`, `test/operations/client_secret_storage_confirmation_concurrency_test.rb`, `test/operations/client_secret_issuance_expiry_invalidator_test.rb`, `test/jobs/client_secret_issuance_collection_job_test.rb`.

`ClientSecretIssuanceCollectionJob` scans at most 500 allocations per execution,
captures a fixed upper ID bound, and durably queues its next cursor past retained
rows. A fresh periodic lifecycle scan recovers lost enqueue. The continuation
reuses the expiry invalidator to clear expired payloads, and existing purgers
recheck authority, retention, dependencies, holds and Chronicle before deletion.
Cursor position grants no transition authority. Worker-stop/start continuation
was observed with actual Solid Queue on the guarded disposable database fleet.
The lifecycle signup phase separately queues bounded fixed-horizon continuations;
live signup allocations do not prevent later terminal-flow reconciliation.
Credential claim reconciliation and collection use their own lifecycle continuation
phase so unresolved claims or held credentials do not block later source rows.
Each continuation rechecks the purge suspension flag and existing operation guards.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-secret-issuance:T008 | DOCUMENTED_TRANSITION | signup batch; activation absent | signup cancel, expiry or failure | signup batch discarded | Source Client lock then durable terminal Ticket flow lock; no signup completion; no candidate claim | Retire all candidates and issuance, clear payload, persist reason-bearing discarded outboxes in source transaction; reservation count excludes discarded issuance | app/operations/client_secret_passkey_reservation_issuer.rb | CONFIRMED |
| idp-client-secret-issuance:T007 | DOCUMENTED_TRANSITION | confirmed signup batch; activation absent | completed signup reconciliation | confirmed signup batch; activation recorded | Locked durable completed app signup flow; same Client; saved batch; source Client lock; source status ACTIVE or VERIFIED_WITH_SIGN_UP and login allowed | Source completion fact and secret.signup_completed outbox commit together; retries preserve original fact | app/operations/client_secret_passkey_reservation_issuer.rb | CONFIRMED |
| idp-client-secret-issuance:T001 | DOCUMENTED_TRANSITION | pending_confirmation | storage confirmation | confirmed | Bound Base actor/session; scoped step-up; matching audited presentation set; owner lock | Confirm issuance and candidates; erase encrypted payload | app/operations/client_secret_storage_confirmation_committer.rb | CONFIRMED |
| idp-client-secret-issuance:T002 | DOCUMENTED_TRANSITION | pending_presentation | manual cancel | canceled | Owner lock; context binding; manual issuance; terminal refusal; audit written first | Cancel timestamp; discard candidates and erase payload | app/operations/client_secret_manual_issuance_invalidator.rb | CONFIRMED |
| idp-client-secret-issuance:T014 | DOCUMENTED_TRANSITION | pending_presentation | protected presentation rejects unavailable payload | canceled | Existing owner, session and scoped Step-Up checks repeated by invalidator; unconfirmed candidate set only; source audit in same transaction | Cancel and discard with existing payload_unavailable reason; erase payload and release reservation; no replacement generation | app/controllers/base/app/secret_presentations_controller.rb; app/operations/client_secret_manual_issuance_invalidator.rb | CONFIRMED |
| idp-client-secret-issuance:T015 | DOCUMENTED_TRANSITION | pending_presentation | signup presentation rejects unavailable payload | canceled | Original signup flow, browser nonce, pending Client and saved Passkey verified through existing delivery boundary; unpresented unconfirmed set only; explicit finite retention | Audited payload_unavailable cancellation and candidate discard in Source transaction; reserve count zero; saved Passkey retained and requirement uncleared; subsequent confirmation denied | app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb; app/operations/client_secret_manual_issuance_invalidator.rb | CONFIRMED |

T013 also accepts T015's original `payload_unavailable` audit after the Ticket
flow is terminal. The immutable cancellation must equal the Source discard time,
and allocation/candidate events must match that time and their durable Chronicle
records. This preserves the earlier retirement reason without deriving a new
reason from a later flow outcome. Live flow and proof-retention guards remain.
| idp-client-secret-issuance:T003 | DOCUMENTED_TRANSITION | pending_confirmation | manual cancel | canceled | Owner lock; context binding; manual issuance; terminal refusal; audit written first | Cancel timestamp; discard candidates and erase payload | app/operations/client_secret_manual_issuance_invalidator.rb | CONFIRMED |
| idp-client-secret-issuance:T004 | DOCUMENTED_TRANSITION | pending_presentation | clock reaches expires_at | expired | Positive planned_count; no terminal fact | No status write; expiry invalidator separately discards candidates | app/models/client_secret_issuance.rb | CONFIRMED |
| idp-client-secret-issuance:T005 | DOCUMENTED_TRANSITION | pending_confirmation | clock reaches expires_at | expired | Positive planned_count; no terminal fact | No status write; expiry invalidator separately discards candidates | app/models/client_secret_issuance.rb | CONFIRMED |
| idp-client-secret-issuance:T006 | DOCUMENTED_TRANSITION | pending_presentation | explicit protected presentation POST | pending_confirmation | Current owner/session/scope/expiry; exact encrypted candidate set | presented_at, source events; encrypted payload erased | app/operations/client_secret_presentation_issuer.rb | CONFIRMED |
| idp-client-secret-issuance:T009 | DOCUMENTED_TRANSITION | expired | lifecycle physical collection | expired_purged | Source Client/issuance locks; retired unconfirmed allocation; no credentials; retention deadline; no hold; terminal Chronicle acknowledgment | DELETE and surviving secret.issuance_purged outbox commit together | app/operations/client_secret_issuance_purger.rb | CONFIRMED |
| idp-client-secret-issuance:T010 | REJECTED_TRANSITION | expired_purged | reservation replay | pending_presentation | Surviving issuance_purged source event | Denied; no new allocation, candidates or source event | app/operations/client_secret_manual_reservation_issuer.rb; app/operations/client_secret_passkey_reservation_issuer.rb | CONFIRMED |
| idp-client-secret-issuance:T011 | DOCUMENTED_TRANSITION | omitted | lifecycle physical collection | omitted_purged | Source Client then Ticket authority then issuance lock; explicit proof retention after authority deadline and completion facts; completed signup if bound; no candidates or holds; delivered Chronicle omission/completion audit | DELETE and count-zero issuance_purged outbox commit together; original authority and Chronicle remain | app/operations/client_secret_issuance_purger.rb; app/jobs/client_secret_lifecycle_job.rb | CONFIRMED |
| idp-client-secret-issuance:T012 | DOCUMENTED_TRANSITION | confirmed | lifecycle call_confirmed! | confirmed_purged | Original authority deadline and allocation expiry plus explicit proof retention; no credentials or receipts; matching storage/creation and signup audits delivered; credential purges committed in Chronicle; no hold | DELETE and surviving issuance_purged outbox in Source transaction; manual issuance public-operation/job journey tested, signup and Passkey collection unverified | app/operations/client_secret_issuance_purger.rb; app/jobs/client_secret_lifecycle_job.rb | CONFIRMED |
| idp-client-secret-issuance:T013 | DOCUMENTED_TRANSITION | signup batch discarded; activation absent | collection call_terminated_signup! | signup_retired_purged | Source Client then matching terminal Ticket signup flow then issuance lock; no credentials or receipts; payload absent; original flow expiry and purge deadline plus explicit proof retention; matching reason-bearing discarded audit and credential purge audits in Chronicle; no hold | DELETE and surviving issuance_purged outbox in Source transaction; canceled zero-count job path and CANCELLED/EXPIRED/FAILED counts 0/1/2 public-operation matrix tested | app/operations/client_secret_issuance_purger.rb; app/jobs/client_secret_issuance_collection_job.rb | CONFIRMED |


No status FK: planned_count=0 implies omitted; positive count requires expiry. Model derives priority confirmed/canceled/expired/presented. Presentation must precede confirmation and expiry; immutable facts resist direct update_columns; cancellation requires matching source audit. ClientSecretPresentationIssuer writes presented_at only after validating and auditing the fixed candidate collection; its protected POST response uses a dedicated document rather than Inertia props. SQL CHECKs and model tests confirm fact invariants. Existing uncommitted Secret rebuild is analyzed as current; no old status-based issuance vocabulary is imported.

## idp-client-session-limit-resolution

Implementation: `ClientSessionLimitResolutionTransaction / Base::App::Sign::In::LimitationsController`. Storage: `client_session_limit_resolution_transactions` / `status`.

Sources: `app/models/client_session_limit_resolution_transaction.rb`, `app/controllers/base/app/sign/in/limitations_controller.rb`.

Tests read: `test/controllers/base/app/sign/in/limitations_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-session-limit-resolution:T001 | DOCUMENTED_TRANSITION | pending | mark_session_selected! | session_selected | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T002 | DOCUMENTED_TRANSITION | pending | mark_resolved! / finalize! | resolved | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T003 | DOCUMENTED_TRANSITION | pending | cancel! | cancelled | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T004 | DOCUMENTED_TRANSITION | session_selected | mark_session_selected! | session_selected | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T005 | DOCUMENTED_TRANSITION | session_selected | mark_resolved! / finalize! | resolved | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T006 | DOCUMENTED_TRANSITION | session_selected | cancel! | cancelled | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T007 | DOCUMENTED_TRANSITION | resolved | mark_session_selected! | session_selected | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T008 | DOCUMENTED_TRANSITION | resolved | mark_resolved! / finalize! | resolved | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T009 | DOCUMENTED_TRANSITION | resolved | cancel! | cancelled | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T010 | DOCUMENTED_TRANSITION | cancelled | mark_session_selected! | session_selected | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T011 | DOCUMENTED_TRANSITION | cancelled | mark_resolved! / finalize! | resolved | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T012 | DOCUMENTED_TRANSITION | cancelled | cancel! | cancelled | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T013 | DOCUMENTED_TRANSITION | expired | mark_session_selected! | session_selected | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T014 | DOCUMENTED_TRANSITION | expired | mark_resolved! / finalize! | resolved | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |
| idp-client-session-limit-resolution:T015 | DOCUMENTED_TRANSITION | expired | cancel! | cancelled | Model setter has no source/TTL lock guard; controller first loads open unexpired challenge bound to actor | Selection/resolution/cancellation timestamps; finalize also consumed/finalized timestamps | app/models/client_session_limit_resolution_transaction.rb | CONFIRMED |

OIDC-only durable capacity resolution; local social sign-in uses main flow instead. Issue reuses open row and rotates challenge/extends TTL15m without changing status; this lookup/update is not serialized. Controller selects owned session then revokes it; successful root session establishment precedes finalize. Cancellation does not revoke existing sessions. expired is accepted/predicate but no production status setter found. Public setters can rewrite resolved/cancelled/expired; they are not universally absorbing terminals. Controller rejects closed or expired resolution; model alone does not guarantee replay/concurrency.

## idp-client-apple-notification

Implementation: `ClientAppleNotificationEvent / AppleNotificationProcessingJob`. Storage: `client_apple_notification_events` / `status`.

Sources: `app/models/client_apple_notification_event.rb`, `app/jobs/apple_notification_processing_job.rb`, `app/services/external_authentication_apple_notification_ingress.rb`, `app/services/external_authentication_apple_notification_processor.rb`.

Tests read: `test/models/client_apple_notification_event_test.rb`, `test/jobs/apple_notification_processing_job_test.rb`, `test/services/external_authentication_apple_notification_processor_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-apple-notification:T001 | DOCUMENTED_TRANSITION | received | processor success | completed | Processor refuses terminal events | Apply provider state; revoke sessions when changed; processed_at | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-apple-notification:T002 | DOCUMENTED_TRANSITION | received | processor failure below retry caps | retrying | Next attempt <10 and elapsed <24h | Exponential retry capped2h; schedule job | app/models/client_apple_notification_event.rb | CONFIRMED |
| idp-client-apple-notification:T003 | DOCUMENTED_TRANSITION | received | processor failure at retry cap | dead_letter | Next attempt >=10 or elapsed >=24h | Record failure; alert | app/models/client_apple_notification_event.rb | CONFIRMED |
| idp-client-apple-notification:T004 | DOCUMENTED_TRANSITION | retrying | processor success | completed | Processor refuses terminal events | Apply provider state; revoke sessions when changed; processed_at | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-apple-notification:T005 | DOCUMENTED_TRANSITION | retrying | processor failure below retry caps | retrying | Next attempt <10 and elapsed <24h | Exponential retry capped2h; schedule job | app/models/client_apple_notification_event.rb | CONFIRMED |
| idp-client-apple-notification:T006 | DOCUMENTED_TRANSITION | retrying | processor failure at retry cap | dead_letter | Next attempt >=10 or elapsed >=24h | Record failure; alert | app/models/client_apple_notification_event.rb | CONFIRMED |

JTI uniqueness supplies ingress deduplication; verified signature/audience/time precede acceptance. Production processor/job guard terminal states, but public complete!/retry_or_dead_letter! themselves have no source-state guard. Job lock.find_by! is outside a surrounding transaction: durable multi-worker serialization is UNCONFIRMED. Identity update, session revocation and event completion span DBs; retry can see prior identity event timestamp and skip transition, so side-effect atomicity is not assumed. Email-enabled/disabled events complete without identity-state changes. Retry-window expiry yields dead_letter, not an EXPIRED state.

## idp-client-external-identity

Implementation: `ClientExternalIdentityRepositoryAdapter / Apple notification processor`. Storage: `client_external_identities` / `state`.

Sources: `app/models/client_external_identity.rb`, `app/services/external_authentication_apple_notification_processor.rb`, `app/adapters/external_authentication/client_external_identity_repository_adapter.rb`.

Tests read: `test/models/client_external_identity_test.rb`, `test/services/external_authentication_apple_notification_processor_test.rb`, `test/adapters/external_authentication/client_external_identity_repository_adapter_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-external-identity:T001 | DOCUMENTED_TRANSITION | active | consent-revoked | consent_revoked | Not account_deleted; provider event newer than last_provider_event_at | Persist state/event time; revoke all sessions when applied | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-external-identity:T002 | DOCUMENTED_TRANSITION | active | account-deleted | account_deleted | Not account_deleted; provider event newer than last_provider_event_at | Persist state/event time; revoke all sessions when applied | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-external-identity:T003 | DOCUMENTED_TRANSITION | consent_revoked | consent-revoked | consent_revoked | Not account_deleted; provider event newer than last_provider_event_at | Persist state/event time; revoke all sessions when applied | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-external-identity:T004 | DOCUMENTED_TRANSITION | consent_revoked | account-deleted | account_deleted | Not account_deleted; provider event newer than last_provider_event_at | Persist state/event time; revoke all sessions when applied | app/services/external_authentication_apple_notification_processor.rb | CONFIRMED |
| idp-client-external-identity:T005 | OUT_OF_BAND | active | repository.activate! | active | Provider matches; account_deleted refused | state direct update | app/adapters/external_authentication/client_external_identity_repository_adapter.rb | CONFIRMED |
| idp-client-external-identity:T006 | OUT_OF_BAND | consent_revoked | repository.activate! | active | Provider matches; account_deleted refused | state direct update | app/adapters/external_authentication/client_external_identity_repository_adapter.rb | CONFIRMED |

String CHECK/no state reference. Consent revocation can reactivate through repository; account deletion cannot. Provider-event ordering uses timestamp comparison without row lock in processor. Event result and identity state are separate. Public repository destroy physically removes identity, separate from account_deleted; authentication metadata refresh does not change lifecycle. No cancel or deadline: entitlement remains until provider/admin action.

## idp-client-totp-credential

Implementation: `ClientTotpCredential / IdentityTotpEnrollmentFinalCommitter`. Storage: `client_totp_credentials` / `user_identity_totp_credential_status_id`.

Sources: `app/models/client_totp_credential.rb`, `app/models/client_totp_credential_status.rb`, `app/operations/identity_totp_enrollment_final_committer.rb`, `app/operations/identity_step_up_totp_verification_committer.rb`, `app/operations/identity_credential_removal_committer.rb`.

Tests read: `test/models/client_totp_credential_test.rb`, `test/models/client_totp_credential_enrollment_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-totp-credential:T001 | DOCUMENTED_TRANSITION | ACTIVE | record_totp_failure! below100 | ACTIVE | Caller holds row lock; active | Increment consecutive failures | app/models/client_totp_credential.rb | CONFIRMED |
| idp-client-totp-credential:T002 | DOCUMENTED_TRANSITION | ACTIVE | record_totp_failure! at100 | REVOKED | Caller holds row lock; active; count reaches100 | Counter capped100; save validate:false | app/models/client_totp_credential.rb | CONFIRMED |
| idp-client-totp-credential:T003 | DOCUMENTED_TRANSITION | ACTIVE | record_totp_success! | ACTIVE | Caller holds row lock; active; code acceptance checked by operation | Reset counter and record OTP time | app/models/client_totp_credential.rb | CONFIRMED |
| idp-client-totp-credential:T004 | DOCUMENTED_TRANSITION | ACTIVE | credential removal | DELETED | Owner/credential locks; owning context; last method guard | Security transition side effects | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-totp-credential:T005 | DOCUMENTED_TRANSITION | INACTIVE | credential removal | DELETED | Owner/credential locks; owning context; last method guard | Security transition side effects | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-totp-credential:T006 | DOCUMENTED_TRANSITION | NOTHING | credential removal | DELETED | Owner/credential locks; owning context; last method guard | Security transition side effects | app/operations/identity_credential_removal_committer.rb | CONFIRMED |
| idp-client-totp-credential:T007 | OUT_OF_BAND | ACTIVE | withdrawal anonymizer direct write | REVOKED | Early termination; model allows write into REVOKED | Direct status update / discard | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-totp-credential:T008 | OUT_OF_BAND | INACTIVE | withdrawal anonymizer direct write | REVOKED | Early termination; model allows write into REVOKED | Direct status update / discard | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-totp-credential:T009 | OUT_OF_BAND | NOTHING | withdrawal anonymizer direct write | REVOKED | Early termination; model allows write into REVOKED | Direct status update / discard | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-totp-credential:T010 | OUT_OF_BAND | DELETED | withdrawal anonymizer direct write | REVOKED | Early termination; model allows write into REVOKED | Direct status update / discard | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-totp-credential:T011 | OUT_OF_BAND | REVOKED | withdrawal anonymizer direct write | REVOKED | Early termination; model allows write into REVOKED | Direct status update / discard | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |

SQL/model default NOTHING=5; production enrollment explicitly creates ACTIVE=1 (new row, not NOTHING->ACTIVE). Two-slot limit counts ACTIVE and INACTIVE under owner lock. REVOKED is model-terminal; validation:false and update_columns remain lower-level bypass routes, not invented production transitions. No production entry setter for INACTIVE identified. OTP replay uses last_otp_at; lock and current credential check owned by verification operation. No credential expiry/cancel path.

## idp-identity-totp-enrollment

Implementation: `IdentityCeremonyCandidateRecord / app/services/identity_totp_ceremony_candidate_store.rb`. Storage: `identity_totp_ceremony_candidates` / `consumed_at / expires_at`.

Sources: `app/models/concerns/identity_ceremony_candidate_record.rb`, `app/services/identity_totp_ceremony_candidate_store.rb`, `app/operations/identity_totp_enrollment_issuer.rb`, `app/operations/identity_totp_enrollment_verification_committer.rb`, `app/operations/identity_totp_enrollment_final_committer.rb`.

Tests read: `test/operations/identity_totp_enrollment_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-identity-totp-enrollment:T001 | DOCUMENTED_TRANSITION | available | store.consume! | consumed | Row lock; ref exists; unconsumed; expiry checked at integer seconds | consumed_at; payload returned | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |
| idp-identity-totp-enrollment:T002 | OUT_OF_BAND | available | store.delete | consumed | Ref exists; no expiry/consumed guard or row lock | Direct consumed_at update | app/services/identity_totp_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-totp-enrollment:T003 | OUT_OF_BAND | expired | store.delete | consumed | Ref exists; no expiry guard | Direct consumed_at update | app/services/identity_totp_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-totp-enrollment:T004 | DOCUMENTED_TRANSITION | consumed | store.delete | consumed | Ref exists; no immutability guard | Replaces consumed_at | app/services/identity_totp_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-totp-enrollment:T005 | DOCUMENTED_TRANSITION | available | clock reaches deadline | expired | expires_at <= now | Predicate only | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |
| idp-identity-totp-enrollment:T006 | DOCUMENTED_TRANSITION | unverified | accepted enrollment code | available | Bound pending parent and token; candidate and actor locks | Candidate proof time; parent becomes verified | app/operations/identity_totp_enrollment_verification_committer.rb | CONFIRMED |
| idp-identity-totp-enrollment:T007 | DOCUMENTED_TRANSITION | available | Base enrollment final commit | consumed | Current verified parent, candidate digest and authorization binding; locks | Create ACTIVE credential; consume child, candidate and parent | app/operations/identity_totp_enrollment_final_committer.rb | CONFIRMED |
| idp-identity-totp-enrollment:T008 | DOCUMENTED_TRANSITION | unverified | clock reaches deadline | expired | Candidate expiry | Predicate only | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |

Shared AppTicket candidate, no state FK. Store consume is single-use and TTL guarded; delete is actually a direct consumed_at write and can replace terminal timestamps. Fetch validates payload; social consumed payload reconstruction can fail after burn, a hidden terminal. Candidate binding must be rechecked by final committer, not supplied by consume(ref) itself. TOTP supports both preverified store path and new step-up-bound unverified enrollment. Expired candidate may be marked consumed by delete; terminal arrows describe proof usability rather than immutable row state.

## idp-identity-secret-credential-candidate

Implementation: `IdentityCeremonyCandidateRecord / app/services/identity_secret_credential_ceremony_candidate_store.rb`. Storage: `identity_secret_credential_ceremony_candidates` / `consumed_at / expires_at`.

Sources: `app/models/concerns/identity_ceremony_candidate_record.rb`, `app/services/identity_secret_credential_ceremony_candidate_store.rb`.

Tests read: UNKNOWN: no dedicated test identified.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-identity-secret-credential-candidate:T001 | DOCUMENTED_TRANSITION | available | store.consume! | consumed | Row lock; ref exists; unconsumed; expiry checked at integer seconds | consumed_at; payload returned | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |
| idp-identity-secret-credential-candidate:T002 | OUT_OF_BAND | available | store.delete | consumed | Ref exists; no expiry/consumed guard or row lock | Direct consumed_at update | app/services/identity_secret_credential_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-secret-credential-candidate:T003 | OUT_OF_BAND | expired | store.delete | consumed | Ref exists; no expiry guard | Direct consumed_at update | app/services/identity_secret_credential_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-secret-credential-candidate:T004 | DOCUMENTED_TRANSITION | consumed | store.delete | consumed | Ref exists; no immutability guard | Replaces consumed_at | app/services/identity_secret_credential_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-secret-credential-candidate:T005 | DOCUMENTED_TRANSITION | available | clock reaches deadline | expired | expires_at <= now | Predicate only | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |

Shared AppTicket candidate, no state FK. Store consume is single-use and TTL guarded; delete is actually a direct consumed_at write and can replace terminal timestamps. Fetch validates payload; social consumed payload reconstruction can fail after burn, a hidden terminal. Candidate binding must be rechecked by final committer, not supplied by consume(ref) itself. TOTP supports both preverified store path and new step-up-bound unverified enrollment. Expired candidate may be marked consumed by delete; terminal arrows describe proof usability rather than immutable row state.

## idp-identity-social-candidate

Implementation: `IdentityCeremonyCandidateRecord / app/services/identity_social_ceremony_candidate_store.rb`. Storage: `identity_social_ceremony_candidates` / `consumed_at / expires_at`.

Sources: `app/models/concerns/identity_ceremony_candidate_record.rb`, `app/services/identity_social_ceremony_candidate_store.rb`.

Tests read: `test/services/identity_social_ceremony_candidate_store_failures_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-identity-social-candidate:T001 | DOCUMENTED_TRANSITION | available | store.consume! | consumed | Row lock; ref exists; unconsumed; expiry checked at integer seconds | consumed_at; payload returned | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |
| idp-identity-social-candidate:T002 | OUT_OF_BAND | available | store.delete | consumed | Ref exists; no expiry/consumed guard or row lock | Direct consumed_at update | app/services/identity_social_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-social-candidate:T003 | OUT_OF_BAND | expired | store.delete | consumed | Ref exists; no expiry guard | Direct consumed_at update | app/services/identity_social_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-social-candidate:T004 | DOCUMENTED_TRANSITION | consumed | store.delete | consumed | Ref exists; no immutability guard | Replaces consumed_at | app/services/identity_social_ceremony_candidate_store.rb | CONFIRMED |
| idp-identity-social-candidate:T005 | DOCUMENTED_TRANSITION | available | clock reaches deadline | expired | expires_at <= now | Predicate only | app/models/concerns/identity_ceremony_candidate_record.rb | CONFIRMED |

Shared AppTicket candidate, no state FK. Store consume is single-use and TTL guarded; delete is actually a direct consumed_at write and can replace terminal timestamps. Fetch validates payload; social consumed payload reconstruction can fail after burn, a hidden terminal. Candidate binding must be rechecked by final committer, not supplied by consume(ref) itself. TOTP supports both preverified store path and new step-up-bound unverified enrollment. Expired candidate may be marked consumed by delete; terminal arrows describe proof usability rather than immutable row state.

## idp-operator-organization-invitation

Implementation: `OrganizationInvitation / OrgOperatorLifecycleInvitationAcceptance`. Storage: `organization_invitations` / `consumed_at / expires_at`.

Sources: `app/models/organization_invitation.rb`, `app/services/org_operator_lifecycle_invitation_acceptance.rb`.

Tests read: `test/models/organization_invitation_test.rb`, `test/services/org/operator_lifecycle/invitation_acceptance_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-organization-invitation:T001 | DOCUMENTED_TRANSITION | active | consume! | consumed | Row lock; active? repeated under lock | consumed_at | app/models/organization_invitation.rb | CONFIRMED |
| idp-operator-organization-invitation:T002 | DOCUMENTED_TRANSITION | active | clock reaches deadline | expired | expires_at <= now | No state write | app/models/organization_invitation.rb | CONFIRMED |

Default TTL7days. find_valid optionally checks case-insensitive email; consumption lock prevents duplicate wins. Invitation acceptance creates/activates Operator through lifecycle service; logical cross-DB IDs are not FKs merely because belongs_to exists. No stored cancel/failure state. Expired_at remains independent of consumed_at, so expired? can be true for already-consumed row.

## idp-operator-operator-lifecycle

Implementation: `OrgOperatorLifecycleApprove / Reject / Execute`. Storage: `operator_lifecycle_requests` / `status`.

Sources: `app/models/operator_lifecycle_request.rb`, `app/services/org_operator_lifecycle_approve.rb`, `app/services/org_operator_lifecycle_reject.rb`, `app/services/org_operator_lifecycle_execute.rb`.

Tests read: `test/models/operator_lifecycle_request_test.rb`, `test/services/org/operator_lifecycle/approve_test.rb`, `test/services/org/operator_lifecycle/execute_test.rb`, `test/services/org_operator_lifecycle_reject_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-operator-lifecycle:T001 | DOCUMENTED_TRANSITION | pending | approve | approved | Pending; actor differs requester | Approver and timestamp | app/services/org_operator_lifecycle_approve.rb | CONFIRMED |
| idp-operator-operator-lifecycle:T002 | DOCUMENTED_TRANSITION | pending | reject | rejected | Pending; actor differs requester | Rejector/time/reason | app/services/org_operator_lifecycle_reject.rb | CONFIRMED |
| idp-operator-operator-lifecycle:T003 | DOCUMENTED_TRANSITION | approved | execute | executed | Approved; actor differs requester; last active operator preserved | Join invitation or withdraw/suspend/terminate/restore actor; revoke sessions / Entra mapping | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |

Cancelled is declared closed but no production entry writer identified; isolated state intentional. No expiry path. lock_version provides optimistic stale-save checks; pending/approved guards occur before update, not an explicit locked decision. Execution transaction is org_principal, while invitation/session writes use the ticket DB; Entra and actor writes share consolidated org_zenith: no distributed atomic guarantee. Restore clears actor withdrawal facts but deliberately does not reactivate Entra. Failed service result leaves request unchanged, not a FAILED state.

## idp-operator-entra-identity

Implementation: `OperatorEntraIdentityProvisioner / Activation / OrgOperatorLifecycleExecute`. Storage: `operator_entra_identities` / `status_id`.

Sources: `app/models/operator_entra_identity.rb`, `app/models/operator_entra_identity_state.rb`, `app/operations/operator_entra_identity_provisioner.rb`, `app/services/operator_entra_identity_activation.rb`, `app/services/org_operator_lifecycle_execute.rb`.

Tests read: `test/models/operator_entra_identity_test.rb`, `test/services/operator_entra_identity_activation_test.rb`, `test/operations/operator_entra_identity_provisioner_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-entra-identity:T001 | OUT_OF_BAND | NOTHING | activate | ACTIVE | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T002 | OUT_OF_BAND | NOTHING | suspend | SUSPENDED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T003 | OUT_OF_BAND | NOTHING | revoke | REVOKED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T004 | OUT_OF_BAND | ACTIVE | activate | ACTIVE | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T005 | OUT_OF_BAND | ACTIVE | suspend | SUSPENDED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T006 | OUT_OF_BAND | ACTIVE | revoke | REVOKED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T007 | OUT_OF_BAND | SUSPENDED | activate | ACTIVE | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T008 | OUT_OF_BAND | SUSPENDED | suspend | SUSPENDED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T009 | OUT_OF_BAND | SUSPENDED | revoke | REVOKED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T010 | OUT_OF_BAND | REVOKED | activate | ACTIVE | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T011 | OUT_OF_BAND | REVOKED | suspend | SUSPENDED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |
| idp-operator-entra-identity:T012 | OUT_OF_BAND | REVOKED | revoke | REVOKED | Supported requested state; existing identity; no source guard/row lock | Direct status_id update | app/services/operator_entra_identity_activation.rb | CONFIRMED |

Provisioning explicit NOTHING=0 denies sign-in; resolver requires ACTIVE. Admin rake activation accepts all previous states, including REVOKED->ACTIVE; therefore no universally absorbing terminal. Lifecycle withdraw/suspend writes SUSPENDED and terminate writes REVOKED directly (same source permissiveness); restore does not reactivate. Model inherits semantic OrgRpRecord, whose current connection owner is OrgZenithRecord; SQL topology is org_zenith. No clock expiry/cancel.

## idp-shared-sequence-carrier

Implementation: `SignInSequenceCarrier / SignInSequence`. Storage: `None (session / Valkey)` / `state / terminal_state`.

Sources: `app/services/sign_in_sequence_carrier.rb`, `app/values/sign_in_sequence.rb`, `app/controllers/concerns/authentication_sequence_gate.rb`.

Tests read: `test/services/sign_in/sequence_carrier_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-sequence-carrier:T001 | DOCUMENTED_TRANSITION | open | complete! | COMPLETED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T002 | DOCUMENTED_TRANSITION | open | fail! | FAILED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T003 | DOCUMENTED_TRANSITION | open | expire! | EXPIRED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T004 | DOCUMENTED_TRANSITION | open | clear! | missing | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T005 | DOCUMENTED_TRANSITION | COMPLETED | complete! | COMPLETED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T006 | DOCUMENTED_TRANSITION | COMPLETED | fail! | FAILED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T007 | DOCUMENTED_TRANSITION | COMPLETED | expire! | EXPIRED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T008 | DOCUMENTED_TRANSITION | COMPLETED | clear! | missing | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T009 | DOCUMENTED_TRANSITION | FAILED | complete! | COMPLETED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T010 | DOCUMENTED_TRANSITION | FAILED | fail! | FAILED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T011 | DOCUMENTED_TRANSITION | FAILED | expire! | EXPIRED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T012 | DOCUMENTED_TRANSITION | FAILED | clear! | missing | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T013 | DOCUMENTED_TRANSITION | EXPIRED | complete! | COMPLETED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T014 | DOCUMENTED_TRANSITION | EXPIRED | fail! | FAILED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T015 | DOCUMENTED_TRANSITION | EXPIRED | expire! | EXPIRED | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T016 | DOCUMENTED_TRANSITION | EXPIRED | clear! | missing | Present carrier for finish; no terminal/TTL guard; clear deletes surface and compatible key | state and terminal_state both overwritten; participant cleared | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T017 | DOCUMENTED_TRANSITION | open | advance! to nonterminal | open | Present and not terminal; supported state and participant; no expiry guard | Replace state/references; renewTTL15m | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T018 | DOCUMENTED_TRANSITION | open | advance! to COMPLETED | COMPLETED | Present and not terminal; supported state and participant | state changes but terminal_state remains null | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T019 | DOCUMENTED_TRANSITION | open | advance! to FAILED | FAILED | Present and not terminal; supported state and participant | state changes but terminal_state remains null | app/services/sign_in_sequence_carrier.rb | CONFIRMED |
| idp-shared-sequence-carrier:T020 | DOCUMENTED_TRANSITION | open | advance! to EXPIRED | EXPIRED | Present and not terminal; supported state and participant | state changes but terminal_state remains null | app/services/sign_in_sequence_carrier.rb | CONFIRMED |

Open state labels accepted: STARTED, PRIMARY_VERIFIED, MFA_PENDING, SESSION_LIMIT_PENDING, GUARDRAIL_PENDING, SESSION_ISSUED, CHECKPOINT_PENDING, DASHBOARD_PENDING. start! can initialize any STATES value with supported participant, and overwrite existing payload; there is no adjacency graph. Diagram groups the fully connected open set to remain readable, rather than inventing progression. advance! also accepts terminal labels but finish! accepts arbitrary terminal_state strings, so UNKNOWN custom values are possible through public API; production wrappers use three labels. Finish can rewrite terminals; clear removes payload. state and terminal_state duplicate terminal authority; validity checks actor/surface/participant/TTL but advance itself ignores TTL. Surface-specific session keys plus legacy migration; not DB authoritative.

## idp-shared-authorization-code

Implementation: `Valkey::AuthState::AuthorizationCodeStore`. Storage: `None (session / Valkey)` / `state`.

Sources: `app/services/valkey/auth_state/authorization_code_store.rb`, `app/operations/oidc_authorization_code_issuer.rb`.

Tests read: `test/services/valkey/auth_state/authorization_code_store_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-authorization-code:T001 | DOCUMENTED_TRANSITION | issued | consume! / Lua CAS | consumed | Expected binding matches; state issued; atomic EVAL; logical expiry checked before CAS | Consumed tombstone; replay returns outcome with no state rewrite | app/services/valkey/auth_state/authorization_code_store.rb | CONFIRMED |
| idp-shared-authorization-code:T002 | DOCUMENTED_TRANSITION | consumed | link_family! | consumed | Atomic same-owner idempotency; refuse changed owner or replay marker | RP session/refresh family refs | app/services/valkey/auth_state/authorization_code_store.rb | CONFIRMED |
| idp-shared-authorization-code:T003 | DOCUMENTED_TRANSITION | consumed | mark_replay! | consumed | Atomic; consumed; first marker retained | Replay evidence; exchange caller can revoke family | app/services/valkey/auth_state/authorization_code_store.rb | CONFIRMED |

No SQL FK. Code TTL10s with longer retained key for logical expiry/replay; consumed tombstone minimum60s. PKCE S256 issue; expected field check precedes replay classification. Link/replay Lua scripts close consume-to-family-link race; mismatches do not burn. Legacy exchange consumes before SQL root/RP commit: later failure can burn code. Current durable OIDC grantclaim is separate authority.

## idp-shared-opaque-admission

Implementation: `Valkey::AuthState::OpaqueAdmissionStore`. Storage: `None (session / Valkey)` / `state`.

Sources: `app/services/valkey/auth_state/opaque_admission_store.rb`, `app/services/base_auth_admission_coordinator.rb`.

Tests read: `test/services/valkey/auth_state/opaque_admission_store_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-opaque-admission:T001 | DOCUMENTED_TRANSITION | issued | consume! / Lua CAS | consumed | Expected binding matches; state issued; atomic EVAL; relies on Redis wall-clock TTL, no expires_at check in Lua | Consumed tombstone; replay returns outcome with no state rewrite | app/services/valkey/auth_state/opaque_admission_store.rb | CONFIRMED |

No SQL FK. Purpose-specific Base/Auth handoff and result code TTL60s, atomic primary/reference index issuance and CAS consumption. Actor/surface/subject/session/ceremony binding checked when supplied by caller. Mismatch does not burn; wrong/used code replay refused. Lua does not compare payload expires_at; TTL controls availability. Multi-tab generation is separately checked by durable ceremony/flow consumer. No persisted FAILED/EXPIRED/CANCELLED state.

## idp-client-step-up-session

Implementation: `StepUpSessionConsumable / BaseStepUpAdmissionIssuer`. Storage: `client_step_up_sessions` / `status / discard_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/client_step_up_session.rb`, `app/operations/base_step_up_admission_issuer.rb`.

Tests read: `test/models/client_step_up_session_test.rb`, `test/models/step_up_session_consumption_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-step-up-session:T001 | DOCUMENTED_TRANSITION | PENDING | consume_pending! completion block | removed | Row lock; PENDING; discard_at>now; block returns non-nil | Destroy row after one completion | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-session:T002 | DOCUMENTED_TRANSITION | PENDING | clock reaches discard_at | expired | Deadline | No status write | app/models/client_step_up_session.rb | CONFIRMED |
| idp-client-step-up-session:T003 | DOCUMENTED_TRANSITION | PENDING | Base admission reissue | PENDING | Actor/token locks; matching current transaction or replacement | Bind transaction; reset proof fields | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-client-step-up-session:T004 | DOCUMENTED_TRANSITION | VERIFIED | Base admission replacement | PENDING | Actor/token locks; existing transaction matching guards; persist_session! writes pending | Reset status, method, verified_at and deadline | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-client-step-up-session:T005 | DOCUMENTED_TRANSITION | expired | Base admission replacement | PENDING | New eligible ceremony under actor/token locks | Bind fresh pending parent | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |

No reference/status ID. VERIFIED accepted by model but production status writer was not found; new verification writes parent ceremony evidence, not this status. consume_pending! is a public legacy completion API with concurrency tests; production callers were not found, so runtime reachability PARTIAL. Admission may reset an existing row to PENDING; TTL in discard_at, not EXPIRED. Token revocation discards linked session and revokes parent; generic retention can delete rows. No stored cancelled state. Session proof metadata and parent ceremony are separate authority axes.

## idp-client-step-up-passkey-challenge

Implementation: `StepUpSessionConsumable`. Storage: `client_step_up_sessions` / `passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/client_step_up_session.rb`, `app/operations/identity_step_up_passkey_verification_committer.rb`.

Tests read: `test/models/step_up_passkey_challenge_test.rb`, `test/operations/identity_step_up_passkey_verification_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-step-up-passkey-challenge:T001 | DOCUMENTED_TRANSITION | empty | issue_bound_passkey_challenge! | issued | Session/parent locks; bound pending parent and token; allowed passkey; session PENDING | Create ref; deadline=min(existing-or10m,parentTTL) | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-passkey-challenge:T002 | DOCUMENTED_TRANSITION | issued | issue_bound_passkey_challenge! | issued | Same bound parent and session; deadline cannot extend | Replace challenge/ref; reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-passkey-challenge:T003 | DOCUMENTED_TRANSITION | burned | issue_bound_passkey_challenge! | issued | Parent still pending and session PENDING; existing deadline still live | New reference, reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-passkey-challenge:T004 | DOCUMENTED_TRANSITION | issued | consume_bound_passkey_challenge! | burned | Parent/session locks; exact unconsumed reference; binding valid | Burn committed before challenge TTL/origin/RP validation; later assertion can fail | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-passkey-challenge:T005 | DOCUMENTED_TRANSITION | issued | clock reaches challenge deadline | expired | Challenge TTL | Predicate only | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-client-step-up-passkey-challenge:T006 | DOCUMENTED_TRANSITION | expired | consume_bound_passkey_challenge! | burned | Parent and session still live; matching ref | Burn then raise challenge expired | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |

Challenge deadline10m capped by parent; reissue preserves original live deadline. Consume validates parent before burn; after matching ref it commits burn even for expired challenge or origin/RP mismatch, so failed assertion cannot replay that ref. Public reissue can reset consumed_at while parent remains pending, so burn is per reference/generation and not globally absorbing. No lifecycle status/ref FK for challenge; SQL stores it on step-up-session row.

## idp-client-step-up-email-challenge

Implementation: `StepUpEmailChallenge`. Storage: `client_step_up_sessions` / `email_delivery_state / email_code_generation / email_code_consumed_at / email_code_expires_at`.

Sources: `app/models/concerns/step_up_email_challenge.rb`, `app/operations/identity_step_up_email_code_issuer.rb`, `app/operations/identity_step_up_email_delivery_recorder.rb`, `app/operations/identity_step_up_email_verification_committer.rb`.

Tests read: `test/models/step_up_email_challenge_test.rb`, `test/operations/identity_step_up_email_verification_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-step-up-email-challenge:T001 | DOCUMENTED_TRANSITION | empty | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T002 | DOCUMENTED_TRANSITION | pending | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T003 | DOCUMENTED_TRANSITION | delivered | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T004 | DOCUMENTED_TRANSITION | failed | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T005 | DOCUMENTED_TRANSITION | consumed | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T006 | DOCUMENTED_TRANSITION | expired | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T007 | DOCUMENTED_TRANSITION | pending | mark_bound_email_delivery! success | delivered | Current positive generation; pending; parent/session live; codeTTLlive | delivery state only | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T008 | DOCUMENTED_TRANSITION | pending | mark_bound_email_delivery! failure | failed | Same guarded current generation | delivery state only | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T009 | DOCUMENTED_TRANSITION | delivered | consume_bound_email_code! | consumed | Current credential/ref/code digest; six digits; unconsumed; live; locks | Code consumed timestamp; parent records email_otp verification | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T010 | DOCUMENTED_TRANSITION | pending | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T011 | DOCUMENTED_TRANSITION | delivered | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-client-step-up-email-challenge:T012 | DOCUMENTED_TRANSITION | failed | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |

Delivery state pending/delivered/failed is distinct from consumed timestamp and parent status. Only delivered code can verify; failed/pending cannot authenticate. Reissue increments generation without extending parent deadline, and may reset old consumed/expired code while parent pending; stale delivery callback is rejected. Parent record_verification advances pending->verified in same locked operation. Row eligibility and credential availability are rechecked by operations. Expiry is derived and no cancellation state; parent cancellation invalidates use.

## idp-visitor-step-up-session

Implementation: `StepUpSessionConsumable / BaseStepUpAdmissionIssuer`. Storage: `visitor_step_up_sessions` / `status / discard_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/visitor_step_up_session.rb`, `app/operations/base_step_up_admission_issuer.rb`.

Tests read: `test/models/visitor_step_up_session_test.rb`, `test/models/step_up_session_consumption_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-step-up-session:T001 | DOCUMENTED_TRANSITION | PENDING | consume_pending! completion block | removed | Row lock; PENDING; discard_at>now; block returns non-nil | Destroy row after one completion | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-session:T002 | DOCUMENTED_TRANSITION | PENDING | clock reaches discard_at | expired | Deadline | No status write | app/models/visitor_step_up_session.rb | CONFIRMED |
| idp-visitor-step-up-session:T003 | DOCUMENTED_TRANSITION | PENDING | Base admission reissue | PENDING | Actor/token locks; matching current transaction or replacement | Bind transaction; reset proof fields | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-visitor-step-up-session:T004 | DOCUMENTED_TRANSITION | VERIFIED | Base admission replacement | PENDING | Actor/token locks; existing transaction matching guards; persist_session! writes pending | Reset status, method, verified_at and deadline | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-visitor-step-up-session:T005 | DOCUMENTED_TRANSITION | expired | Base admission replacement | PENDING | New eligible ceremony under actor/token locks | Bind fresh pending parent | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |

No reference/status ID. VERIFIED accepted by model but production status writer was not found; new verification writes parent ceremony evidence, not this status. consume_pending! is a public legacy completion API with concurrency tests; production callers were not found, so runtime reachability PARTIAL. Admission may reset an existing row to PENDING; TTL in discard_at, not EXPIRED. Token revocation discards linked session and revokes parent; generic retention can delete rows. No stored cancelled state. Session proof metadata and parent ceremony are separate authority axes.

## idp-visitor-step-up-passkey-challenge

Implementation: `StepUpSessionConsumable`. Storage: `visitor_step_up_sessions` / `passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/visitor_step_up_session.rb`, `app/operations/identity_step_up_passkey_verification_committer.rb`.

Tests read: `test/models/step_up_passkey_challenge_test.rb`, `test/operations/identity_step_up_passkey_verification_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-step-up-passkey-challenge:T001 | DOCUMENTED_TRANSITION | empty | issue_bound_passkey_challenge! | issued | Session/parent locks; bound pending parent and token; allowed passkey; session PENDING | Create ref; deadline=min(existing-or10m,parentTTL) | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-passkey-challenge:T002 | DOCUMENTED_TRANSITION | issued | issue_bound_passkey_challenge! | issued | Same bound parent and session; deadline cannot extend | Replace challenge/ref; reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-passkey-challenge:T003 | DOCUMENTED_TRANSITION | burned | issue_bound_passkey_challenge! | issued | Parent still pending and session PENDING; existing deadline still live | New reference, reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-passkey-challenge:T004 | DOCUMENTED_TRANSITION | issued | consume_bound_passkey_challenge! | burned | Parent/session locks; exact unconsumed reference; binding valid | Burn committed before challenge TTL/origin/RP validation; later assertion can fail | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-passkey-challenge:T005 | DOCUMENTED_TRANSITION | issued | clock reaches challenge deadline | expired | Challenge TTL | Predicate only | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-visitor-step-up-passkey-challenge:T006 | DOCUMENTED_TRANSITION | expired | consume_bound_passkey_challenge! | burned | Parent and session still live; matching ref | Burn then raise challenge expired | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |

Challenge deadline10m capped by parent; reissue preserves original live deadline. Consume validates parent before burn; after matching ref it commits burn even for expired challenge or origin/RP mismatch, so failed assertion cannot replay that ref. Public reissue can reset consumed_at while parent remains pending, so burn is per reference/generation and not globally absorbing. No lifecycle status/ref FK for challenge; SQL stores it on step-up-session row.

## idp-visitor-step-up-email-challenge

Implementation: `StepUpEmailChallenge`. Storage: `visitor_step_up_sessions` / `email_delivery_state / email_code_generation / email_code_consumed_at / email_code_expires_at`.

Sources: `app/models/concerns/step_up_email_challenge.rb`, `app/operations/identity_step_up_email_code_issuer.rb`, `app/operations/identity_step_up_email_delivery_recorder.rb`, `app/operations/identity_step_up_email_verification_committer.rb`.

Tests read: `test/models/step_up_email_challenge_test.rb`, `test/operations/identity_step_up_email_verification_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-step-up-email-challenge:T001 | DOCUMENTED_TRANSITION | empty | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T002 | DOCUMENTED_TRANSITION | pending | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T003 | DOCUMENTED_TRANSITION | delivered | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T004 | DOCUMENTED_TRANSITION | failed | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T005 | DOCUMENTED_TRANSITION | consumed | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T006 | DOCUMENTED_TRANSITION | expired | issue_bound_email_code! | pending | Session/parent locks; matching pending email_otp parent; session PENDING | New generation/digest; reset consumed_at; deadline=min10m,parentTTL) | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T007 | DOCUMENTED_TRANSITION | pending | mark_bound_email_delivery! success | delivered | Current positive generation; pending; parent/session live; codeTTLlive | delivery state only | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T008 | DOCUMENTED_TRANSITION | pending | mark_bound_email_delivery! failure | failed | Same guarded current generation | delivery state only | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T009 | DOCUMENTED_TRANSITION | delivered | consume_bound_email_code! | consumed | Current credential/ref/code digest; six digits; unconsumed; live; locks | Code consumed timestamp; parent records email_otp verification | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T010 | DOCUMENTED_TRANSITION | pending | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T011 | DOCUMENTED_TRANSITION | delivered | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |
| idp-visitor-step-up-email-challenge:T012 | DOCUMENTED_TRANSITION | failed | clock reaches code deadline | expired | Code TTL elapsed | Derived code unusability; delivery state unchanged | app/models/concerns/step_up_email_challenge.rb | CONFIRMED |

Delivery state pending/delivered/failed is distinct from consumed timestamp and parent status. Only delivered code can verify; failed/pending cannot authenticate. Reissue increments generation without extending parent deadline, and may reset old consumed/expired code while parent pending; stale delivery callback is rejected. Parent record_verification advances pending->verified in same locked operation. Row eligibility and credential availability are rechecked by operations. Expiry is derived and no cancellation state; parent cancellation invalidates use.

## idp-operator-step-up-session

Implementation: `StepUpSessionConsumable / BaseStepUpAdmissionIssuer`. Storage: `operator_step_up_sessions` / `status / discard_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/operator_step_up_session.rb`, `app/operations/base_step_up_admission_issuer.rb`.

Tests read: `test/models/operator_step_up_session_test.rb`, `test/models/step_up_session_consumption_concurrency_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-step-up-session:T001 | DOCUMENTED_TRANSITION | PENDING | consume_pending! completion block | removed | Row lock; PENDING; discard_at>now; block returns non-nil | Destroy row after one completion | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-session:T002 | DOCUMENTED_TRANSITION | PENDING | clock reaches discard_at | expired | Deadline | No status write | app/models/operator_step_up_session.rb | CONFIRMED |
| idp-operator-step-up-session:T003 | DOCUMENTED_TRANSITION | PENDING | Base admission reissue | PENDING | Actor/token locks; matching current transaction or replacement | Bind transaction; reset proof fields | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-operator-step-up-session:T004 | DOCUMENTED_TRANSITION | VERIFIED | Base admission replacement | PENDING | Actor/token locks; existing transaction matching guards; persist_session! writes pending | Reset status, method, verified_at and deadline | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |
| idp-operator-step-up-session:T005 | DOCUMENTED_TRANSITION | expired | Base admission replacement | PENDING | New eligible ceremony under actor/token locks | Bind fresh pending parent | app/operations/base_step_up_admission_issuer.rb | CONFIRMED |

No reference/status ID. VERIFIED accepted by model but production status writer was not found; new verification writes parent ceremony evidence, not this status. consume_pending! is a public legacy completion API with concurrency tests; production callers were not found, so runtime reachability PARTIAL. Admission may reset an existing row to PENDING; TTL in discard_at, not EXPIRED. Token revocation discards linked session and revokes parent; generic retention can delete rows. No stored cancelled state. Session proof metadata and parent ceremony are separate authority axes.

## idp-operator-step-up-passkey-challenge

Implementation: `StepUpSessionConsumable`. Storage: `operator_step_up_sessions` / `passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at`.

Sources: `app/models/concerns/step_up_session_consumable.rb`, `app/models/operator_step_up_session.rb`, `app/operations/identity_step_up_passkey_verification_committer.rb`.

Tests read: `test/models/step_up_passkey_challenge_test.rb`, `test/operations/identity_step_up_passkey_verification_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-step-up-passkey-challenge:T001 | DOCUMENTED_TRANSITION | empty | issue_bound_passkey_challenge! | issued | Session/parent locks; bound pending parent and token; allowed passkey; session PENDING | Create ref; deadline=min(existing-or10m,parentTTL) | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-passkey-challenge:T002 | DOCUMENTED_TRANSITION | issued | issue_bound_passkey_challenge! | issued | Same bound parent and session; deadline cannot extend | Replace challenge/ref; reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-passkey-challenge:T003 | DOCUMENTED_TRANSITION | burned | issue_bound_passkey_challenge! | issued | Parent still pending and session PENDING; existing deadline still live | New reference, reset consumed_at | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-passkey-challenge:T004 | DOCUMENTED_TRANSITION | issued | consume_bound_passkey_challenge! | burned | Parent/session locks; exact unconsumed reference; binding valid | Burn committed before challenge TTL/origin/RP validation; later assertion can fail | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-passkey-challenge:T005 | DOCUMENTED_TRANSITION | issued | clock reaches challenge deadline | expired | Challenge TTL | Predicate only | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |
| idp-operator-step-up-passkey-challenge:T006 | DOCUMENTED_TRANSITION | expired | consume_bound_passkey_challenge! | burned | Parent and session still live; matching ref | Burn then raise challenge expired | app/models/concerns/step_up_session_consumable.rb | CONFIRMED |

Challenge deadline10m capped by parent; reissue preserves original live deadline. Consume validates parent before burn; after matching ref it commits burn even for expired challenge or origin/RP mismatch, so failed assertion cannot replay that ref. Public reissue can reset consumed_at while parent remains pending, so burn is per reference/generation and not globally absorbing. No lifecycle status/ref FK for challenge; SQL stores it on step-up-session row.

## idp-client-email-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `client_emails` / `user_email_status_id`.

Sources: `app/models/client_email.rb`, `app/models/client_email_status.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/client_email_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-email-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_email_ceremony_final_committer.rb | CONFIRMED |
| idp-client-email-credential:T002 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | sign-up contact finalization | VERIFIED_WITH_SIGN_UP | Bound signup candidate/OTP; finalizer/controller guards | Direct contact status and principal verification | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-credential:T003 | DOCUMENTED_TRANSITION | UNVERIFIED | signup Base ceremony final commit | VERIFIED_WITH_SIGN_UP | Actor UNVERIFIED_WITH_SIGN_UP; signed binding and locked contact | Update actor VERIFIED_WITH_SIGN_UP | app/operations/identity_email_ceremony_final_committer.rb | CONFIRMED |
| idp-client-email-credential:T004 | OUT_OF_BAND | UNVERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T005 | OUT_OF_BAND | VERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T006 | OUT_OF_BAND | SUSPENDED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T007 | OUT_OF_BAND | DELETED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T008 | OUT_OF_BAND | NOTHING | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T009 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T010 | OUT_OF_BAND | VERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-email-credential:T011 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | SignUpArtifactCleanup dependent retention | DELETED | Selected pending contact; current column exists; deleted reference ID resolves; lock | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-client-telephone-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `client_telephones` / `user_identity_telephone_status_id`.

Sources: `app/models/client_telephone.rb`, `app/models/client_telephone_status.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/client_telephone_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-telephone-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_telephone_ceremony_final_committer.rb | CONFIRMED |
| idp-client-telephone-credential:T002 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | sign-up contact finalization | VERIFIED_WITH_SIGN_UP | Bound signup candidate/OTP; finalizer/controller guards | Direct contact status and principal verification | app/operations/sign_app_up_telephone_registration_finalizer.rb | CONFIRMED |
| idp-client-telephone-credential:T003 | OUT_OF_BAND | NOTHING | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T004 | OUT_OF_BAND | VERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T005 | OUT_OF_BAND | UNVERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T006 | OUT_OF_BAND | SUSPENDED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T007 | OUT_OF_BAND | DELETED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T008 | OUT_OF_BAND | LEGACY_NOTHING | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T009 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T010 | OUT_OF_BAND | VERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-client-telephone-credential:T011 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | SignUpArtifactCleanup dependent retention | DELETED | Selected pending contact; current column exists; deleted reference ID resolves; lock | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-client-actor-withdrawal

Implementation: `Withdrawable / app/services/withdrawal_lifecycle.rb`. Storage: `clients` / `withdrawal_started_at / deactivated_at / withdrawn_at / terminated_at / discard_at / purge_eligible_at`.

Sources: `app/models/concerns/withdrawable.rb`, `app/services/withdrawal_lifecycle.rb`, `app/controllers/concerns/authentication_withdrawal_gate.rb`.

Tests read: `test/services/withdrawal_lifecycle_test.rb`, `test/services/org/operator_lifecycle/execute_test.rb`, `test/integration/withdrawal_lifecycle_security_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-actor-withdrawal:T001 | DOCUMENTED_TRANSITION | active | start withdrawal request | active | Actor lock; create REQUESTED flow | No actor withdrawal timestamps yet | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T002 | DOCUMENTED_TRANSITION | active | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T003 | DOCUMENTED_TRANSITION | closing | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T004 | DOCUMENTED_TRANSITION | suspended | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T005 | DOCUMENTED_TRANSITION | suspended | recover! | active | Can recover after1hour before purge; privacy request permits; actor lock | Recover flow; clear timestamps; Infinity retention | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T006 | OUT_OF_BAND | suspended | terminate! after7days | terminated | Early terminatable check before actor lock | Flow TERMINATED; set terminated_at; anonymize/purge children; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-client-actor-withdrawal:T007 | DOCUMENTED_TRANSITION | suspended | clock reaches finite purge deadline | terminated | Finite purge_eligible_at <= now | Derived predicate, no status write | app/models/concerns/withdrawable.rb | CONFIRMED |

Derived predicates overlap: withdrawn_at independent; terminated wins over suspended; active excludes all, while closing uses withdrawal_started_at. closing is declared but start! currently only writes REQUESTED flow, no actor withdrawal_started_at; incoming actor closing writer UNCONFIRMED. Client/visitor suspend public method has no source guard and can preserve expired purge facts, so a call can remain derived terminated rather than enter suspended; diagram applies resulting future-purge condition only. Operator restore can clear termination facts via approved action; no absorbing terminal assumed. Eligibility gates act separately from actor status_id and access_state. Flow/token/audit/child operations include separate DB owners; no distributed atomicity is inferred. Actor and Entra rows share org_zenith in the current consolidated checkout.

## idp-visitor-email-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `visitor_emails` / `visitor_email_status_id`.

Sources: `app/models/visitor_email.rb`, `app/models/visitor_email_status.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/visitor_email_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-email-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_email_ceremony_final_committer.rb | CONFIRMED |
| idp-visitor-email-credential:T002 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | sign-up contact finalization | VERIFIED_WITH_SIGN_UP | Bound signup candidate/OTP; finalizer/controller guards | Direct contact status and principal verification | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-credential:T003 | OUT_OF_BAND | UNVERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T004 | OUT_OF_BAND | VERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T005 | OUT_OF_BAND | SUSPENDED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T006 | OUT_OF_BAND | DELETED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T007 | OUT_OF_BAND | NOTHING | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T008 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T009 | OUT_OF_BAND | VERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-email-credential:T010 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | SignUpArtifactCleanup dependent retention | DELETED | Selected pending contact; current column exists; deleted reference ID resolves; lock | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-visitor-telephone-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `visitor_telephones` / `visitor_telephone_status_id`.

Sources: `app/models/visitor_telephone.rb`, `app/models/visitor_telephone_status.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/visitor_telephone_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-telephone-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_telephone_ceremony_final_committer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T002 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | sign-up contact finalization | VERIFIED_WITH_SIGN_UP | Bound signup candidate/OTP; finalizer/controller guards | Direct contact status and principal verification | app/operations/sign_com_up_telephone_registration_finalizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T003 | OUT_OF_BAND | UNVERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T004 | OUT_OF_BAND | VERIFIED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T005 | OUT_OF_BAND | SUSPENDED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T006 | OUT_OF_BAND | DELETED | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T007 | OUT_OF_BAND | NOTHING | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T008 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T009 | OUT_OF_BAND | VERIFIED_WITH_SIGN_UP | withdrawal anonymize | SUSPENDED | Withdrawal early termination guard owned by service; no contact source guard | Overwrite contact and clear OTP/digest | app/operations/withdrawal_personal_data_anonymizer.rb | CONFIRMED |
| idp-visitor-telephone-credential:T010 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | SignUpArtifactCleanup dependent retention | DELETED | Selected pending contact; current column exists; deleted reference ID resolves; lock | Schedule discard/purge and direct dynamic status-column update | app/services/sign_up_artifact_cleanup.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-visitor-actor-withdrawal

Implementation: `Withdrawable / app/services/withdrawal_lifecycle.rb`. Storage: `visitors` / `withdrawal_started_at / deactivated_at / withdrawn_at / terminated_at / discard_at / purge_eligible_at`.

Sources: `app/models/concerns/withdrawable.rb`, `app/services/withdrawal_lifecycle.rb`, `app/controllers/concerns/authentication_withdrawal_gate.rb`.

Tests read: `test/services/withdrawal_lifecycle_test.rb`, `test/services/org/operator_lifecycle/execute_test.rb`, `test/integration/withdrawal_lifecycle_security_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-actor-withdrawal:T001 | DOCUMENTED_TRANSITION | active | start withdrawal request | active | Actor lock; create REQUESTED flow | No actor withdrawal timestamps yet | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T002 | DOCUMENTED_TRANSITION | active | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T003 | DOCUMENTED_TRANSITION | closing | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T004 | DOCUMENTED_TRANSITION | suspended | suspend! | suspended | Actor lock; confirm/discard withdrawal flow; no actor source guard | Set start/deactivate/discard; default purge31days; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T005 | DOCUMENTED_TRANSITION | suspended | recover! | active | Can recover after1hour before purge; privacy request permits; actor lock | Recover flow; clear timestamps; Infinity retention | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T006 | OUT_OF_BAND | suspended | terminate! after7days | terminated | Early terminatable check before actor lock | Flow TERMINATED; set terminated_at; anonymize/purge children; revoke tokens | app/services/withdrawal_lifecycle.rb | CONFIRMED |
| idp-visitor-actor-withdrawal:T007 | DOCUMENTED_TRANSITION | suspended | clock reaches finite purge deadline | terminated | Finite purge_eligible_at <= now | Derived predicate, no status write | app/models/concerns/withdrawable.rb | CONFIRMED |

Derived predicates overlap: withdrawn_at independent; terminated wins over suspended; active excludes all, while closing uses withdrawal_started_at. closing is declared but start! currently only writes REQUESTED flow, no actor withdrawal_started_at; incoming actor closing writer UNCONFIRMED. Client/visitor suspend public method has no source guard and can preserve expired purge facts, so a call can remain derived terminated rather than enter suspended; diagram applies resulting future-purge condition only. Operator restore can clear termination facts via approved action; no absorbing terminal assumed. Eligibility gates act separately from actor status_id and access_state. Flow/token/audit/child operations include separate DB owners; no distributed atomicity is inferred. Actor and Entra rows share org_zenith in the current consolidated checkout.

## idp-operator-email-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `operator_emails` / `staff_identity_email_status_id`.

Sources: `app/models/operator_email.rb`, `app/models/operator_email_status.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/operator_email_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-email-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_email_ceremony_final_committer.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-operator-telephone-credential

Implementation: `Identity contact final committer / sign-up controllers / withdrawal anonymizer`. Storage: `operator_telephones` / `staff_identity_telephone_status_id`.

Sources: `app/models/operator_telephone.rb`, `app/models/operator_telephone_status.rb`, `app/operations/identity_telephone_ceremony_final_committer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`.

Tests read: `test/models/operator_telephone_test.rb`, `test/operations/identity_telephone_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-telephone-credential:T001 | DOCUMENTED_TRANSITION | UNVERIFIED | Base ceremony final commit | VERIFIED | Signed result bound to actor/session; pending contact under row lock | Consume ceremony on ticket DB before principal status commit | app/operations/identity_telephone_ceremony_final_committer.rb | CONFIRMED |

No independent transition map: controllers/operations directly write state FK. Fixed declarations with no incoming production state writer remain isolated intentionally; DELETED is a reference/uniqueness exclusion, not presumed destroy event. Base contact removal uses physical destroy with ownership/last-method guards rather than assigning DELETED. OTP lock/expiry lives on separate columns and is diagrammed separately. Anonymizer rewrites any client/visitor contact to SUSPENDED with no source guard; no universally absorbing row state is assumed. Operator old ACTIVE/INACTIVE/PENDING labels coexist with UNVERIFIED/VERIFIED. Exact default and model aliases are in topology/model; no status time expiry.

## idp-operator-actor-withdrawal

Implementation: `Withdrawable / app/services/org_operator_lifecycle_execute.rb`. Storage: `operators` / `withdrawal_started_at / deactivated_at / withdrawn_at / discard_at / purge_eligible_at`.

Sources: `app/models/concerns/withdrawable.rb`, `app/services/org_operator_lifecycle_execute.rb`, `app/controllers/concerns/authentication_withdrawal_gate.rb`.

Tests read: `test/services/withdrawal_lifecycle_test.rb`, `test/services/org/operator_lifecycle/execute_test.rb`, `test/integration/withdrawal_lifecycle_security_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-actor-withdrawal:T001 | OUT_OF_BAND | active | suspend / withdraw | suspended | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T002 | OUT_OF_BAND | active | terminate | terminated | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T003 | OUT_OF_BAND | active | restore | active | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T004 | OUT_OF_BAND | closing | suspend / withdraw | suspended | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T005 | OUT_OF_BAND | closing | terminate | terminated | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T006 | OUT_OF_BAND | closing | restore | active | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T007 | OUT_OF_BAND | suspended | suspend / withdraw | suspended | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T008 | OUT_OF_BAND | suspended | terminate | terminated | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T009 | OUT_OF_BAND | suspended | restore | active | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T010 | OUT_OF_BAND | terminated | suspend / withdraw | suspended | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T011 | OUT_OF_BAND | terminated | terminate | terminated | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T012 | OUT_OF_BAND | terminated | restore | active | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T013 | OUT_OF_BAND | withdrawn | suspend / withdraw | suspended | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T014 | OUT_OF_BAND | withdrawn | terminate | terminated | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T015 | OUT_OF_BAND | withdrawn | restore | active | Approved request; actor differs requester; last active operator guard on deactivation | Direct actor facts; session revoke and Entra SUSPENDED/REVOKED; restore leaves Entra unchanged | app/services/org_operator_lifecycle_execute.rb | CONFIRMED |
| idp-operator-actor-withdrawal:T016 | DOCUMENTED_TRANSITION | suspended | clock reaches finite purge deadline | terminated | Finite purge_eligible_at <= now | Derived predicate, no status write | app/models/concerns/withdrawable.rb | CONFIRMED |

Derived predicates overlap: withdrawn_at independent; terminated wins over suspended; active excludes all, while closing uses withdrawal_started_at. closing is declared but start! currently only writes REQUESTED flow, no actor withdrawal_started_at; incoming actor closing writer UNCONFIRMED. Client/visitor suspend public method has no source guard and can preserve expired purge facts, so a call can remain derived terminated rather than enter suspended; diagram applies resulting future-purge condition only. Operator restore can clear termination facts via approved action; no absorbing terminal assumed. Eligibility gates act separately from actor status_id and access_state. Flow/token/audit/child operations include separate DB owners; no distributed atomicity is inferred. Actor and Entra rows share org_zenith in the current consolidated checkout.

## idp-client-actor-provisioning

Implementation: `ClientStatus / sign-up finalizers`. Storage: `clients` / `status_id`.

Sources: `app/models/client_status.rb`, `app/operations/identity_email_ceremony_final_committer.rb`, `app/operations/sign_app_up_telephone_registration_finalizer.rb`, `app/controllers/concerns/sign_up_sequence_controller_support.rb`, `app/operations/social_auth_signup_finalizer.rb`.

Tests read: `test/models/client_test.rb`, `test/operations/identity_email_ceremony_final_committer_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-actor-provisioning:T001 | OUT_OF_BAND | UNVERIFIED_WITH_SIGN_UP | contact/signup final commit | VERIFIED_WITH_SIGN_UP | Pending Client signup status; verified bound contact/finalization | Direct status_id write | app/operations/identity_email_ceremony_final_committer.rb | CONFIRMED |

All fixed reference IDs are preserved, but only current post-creation production transition 9->10 confirmed. Social signup creates VERIFIED_WITH_SIGN_UP directly, not 9->10. Actor withdrawal now uses timestamp/flow authorities, not legacy WITHDRAWN/DELETED reference transitions; those transitions UNKNOWN. Client default NOTHING and explicit ordinary ACTIVE creation are distinct entry states, no inferred transition. Visitor/Operator ACTIVE/NOTHING/RESERVED are creation classifications with no production existing-row status mutation found, recorded as excluded lookup candidates in discovery.

## idp-shared-acme-logout

Implementation: `AcmeLogoutTransactionable / AcmeLogoutTransactionCoordinator`. Storage: `acme_logout_transactions` / `status / expected_step / completed_steps`.

Sources: `app/models/concerns/acme_logout_transactionable.rb`, `app/models/acme_logout_transaction.rb`, `app/services/acme_logout_transaction_coordinator.rb`, `app/controllers/concerns/sign_oidc_logout.rb`.

Tests read: `test/models/acme_logout_transaction_test.rb`, `test/models/acme_logout_race_branch_coverage_test.rb`, `test/services/acme_logout_transaction_coordinator_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-acme-logout:T001 | DOCUMENTED_TRANSITION | initiated | advance expected logout step | in_progress | Row lock; expected step; live TTL; failed/finalized refuse; completed step replay no-op | Append completed_steps and move expected_step | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T002 | DOCUMENTED_TRANSITION | in_progress | advance expected logout step | in_progress | Row lock; expected step; live TTL; failed/finalized refuse; completed step replay no-op | Append completed_steps and move expected_step | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T003 | DOCUMENTED_TRANSITION | expired | advance expected logout step | in_progress | Row lock; expected step; live TTL; failed/finalized refuse; completed step replay no-op | Append completed_steps and move expected_step | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T004 | DOCUMENTED_TRANSITION | initiated | finalize! | finalized | Row lock; live TTL; expected_step finalized; no failed source guard | Append finalized and finalized_at | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T005 | DOCUMENTED_TRANSITION | in_progress | finalize! | finalized | Row lock; live TTL; expected_step finalized; no failed source guard | Append finalized and finalized_at | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T006 | DOCUMENTED_TRANSITION | failed | finalize! | finalized | Row lock; live TTL; expected_step finalized; no failed source guard | Append finalized and finalized_at | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T007 | DOCUMENTED_TRANSITION | expired | finalize! | finalized | Row lock; live TTL; expected_step finalized; no failed source guard | Append finalized and finalized_at | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T008 | DOCUMENTED_TRANSITION | initiated | fail! | failed | Not finalized or failed; no own row lock | failed_at and status | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T009 | DOCUMENTED_TRANSITION | in_progress | fail! | failed | Not finalized or failed; no own row lock | failed_at and status | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |
| idp-shared-acme-logout:T010 | DOCUMENTED_TRANSITION | expired | fail! | failed | Not finalized or failed; no own row lock | failed_at and status | app/models/concerns/acme_logout_transactionable.rb | CONFIRMED |

Ordered step sequences: sign origin_cleared->acme_cleared; acme/base origin_cleared->sign_cleared; core/side/palm origin_cleared->acme_cleared->sign_cleared; then finalize. Steps are exact runtime events, not target external_result. Status EXPIRED declared but no writer; clock expiry refuses calls without writing. Edges from declared expired require a future expires_at (public API tests/model-permitted only); no invented clock transition to stored expired. finalize! lacks failed guard and can finalize failed row when expected step ready/live; failed is therefore not absorbing. fail! not serialized. Duplicate completed step is no-op; locked advance/finalize recheck. TTL10m. SQL status, expected_step and completed_steps duplicate progress authority, and SQL/model constraints recorded.

## idp-shared-webauthn-challenge

Implementation: `Webauthn::ChallengeStore`. Storage: `None (Rails session)` / `passkey_challenges entry / expires_at`.

Sources: `app/services/webauthn/challenge_store.rb`.

Tests read: `test/unit/webauthn/challenge_store_test.rb`, `test/services/challenge_store_and_jump_gateway_refusals_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-webauthn-challenge:T001 | DOCUMENTED_TRANSITION | issued | consume! / consume_with_actor! | removed | Entry deletion occurs before TTL/purpose/surface/RP/origin/actor validation | Burn even on rejection; return challenge or raise | app/services/webauthn/challenge_store.rb | CONFIRMED |
| idp-shared-webauthn-challenge:T002 | DOCUMENTED_TRANSITION | issued | discard | removed | Entry exists | Idempotent removal | app/services/webauthn/challenge_store.rb | CONFIRMED |
| idp-shared-webauthn-challenge:T003 | DOCUMENTED_TRANSITION | issued | issue! cleanup / capacity eviction | removed | TTL elapsed or oldest entry when capacity>=5 | Delete old entry before creating another | app/services/webauthn/challenge_store.rb | CONFIRMED |

Session-only same-browser challenges, distinct from durable PasskeyCeremonyTransaction. TTL10m, maximum5, purposes registration/authentication/emergency_sign_in/step_up. Missing, expired and mismatching outcome errors are not stored states; consumption deletes first. Cookie/session request concurrency has no DB lock or CAS in this class, so cross-request single-winner behavior is UNCONFIRMED. Browser-bound snapshot loss/multi-tab overwrite cannot be assumed prevented.

## idp-client-enforcement-case

Implementation: `EnforcementCaseApplyOperation / EndOperation / convergence jobs`. Storage: `app_enforcement_cases` / `state / ended_at`.

Sources: `app/models/concerns/enforcement_case_applicable.rb`, `app/models/app_enforcement_case.rb`, `app/operations/enforcement_case_apply_operation.rb`, `app/operations/enforcement_case_end_operation.rb`, `app/jobs/enforcement_expiry_job.rb`, `app/jobs/enforcement_reconciliation_job.rb`, `app/controllers/base/org/support/enforcement_cases/approvals_controller.rb`.

Tests read: `test/operations/enforcement_case_apply_failure_test.rb`, `test/models/enforcement_case_apply_ordering_test.rb`, `test/jobs/enforcement_expiry_job_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-enforcement-case:T001 | DOCUMENTED_TRANSITION | draft | controller requires approval | pending_approval | Creation requires approval; save pending state | Attach principal ref and request decision | app/controllers/base/org/support/enforcement_cases_controller.rb | CONFIRMED |
| idp-client-enforcement-case:T002 | DOCUMENTED_TRANSITION | draft | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T003 | DOCUMENTED_TRANSITION | pending_approval | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T004 | OUT_OF_BAND | active | RecordInvalid / RecordNotUnique side-effect failure | failed | Committed security decision; rescue narrow exceptions | update_column state failed; raise | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T005 | DOCUMENTED_TRANSITION | draft | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T006 | DOCUMENTED_TRANSITION | pending_approval | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T007 | DOCUMENTED_TRANSITION | active | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T008 | DOCUMENTED_TRANSITION | failed | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T009 | DOCUMENTED_TRANSITION | ended | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-client-enforcement-case:T010 | DOCUMENTED_TRANSITION | active | EnforcementExpiryJob | closed | expires_at <=now; active and not yet ended | End reason expired; refcount lock release | app/jobs/enforcement_expiry_job.rb | CONFIRMED |
| idp-client-enforcement-case:T011 | DOCUMENTED_TRANSITION | active | reconciliation | active | Pending convergence timestamps; active not ended | Retry revocation/audit, no state rewrite | app/jobs/enforcement_reconciliation_job.rb | CONFIRMED |
| idp-client-enforcement-case:T012 | DOCUMENTED_TRANSITION | closed | end reconcile / repeat | closed | Recorded end reason wins; lock; no duplicate end timestamp | Retry release/audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |

String CHECK; no state reference FK. Case governs authentication-method/principal/identifier effects through actual effect->case FKs; effects have effective/expiry/ended timestamps, not independent transition graphs. EndOperation does not write state=ended: it preserves stored state and writes ended_at; declared ended incoming writer UNKNOWN. Runtime in_force requires active, effective time reached, unexpired and no ended_at independently of jobs. Narrow side-effect failures write failed via update_column despite comments describing decision preserved active; pending_convergence and expiry select active only, so failed recovery path is UNKNOWN (hidden convergence dead end). Other exceptions retain active and may reconcile. Approval controller claims approver under lock; operation itself checks source outside transaction without lock. Superseding closes effect timestamps without necessarily ending old Case. Appeals and verification can end; cancel is not a distinct state. No distributed transaction with actor/token/Chronicle. Principal ref is logical cross-DB, not FK.

## idp-client-enforcement-appeal

Implementation: `EnforcementAppeal / EnforcementReconciliationJob`. Storage: `app_enforcement_appeals` / `state / resolution_code / reviewed_at`.

Sources: `app/models/concerns/enforcement_appeal.rb`, `app/models/app_enforcement_appeal.rb`, `app/jobs/enforcement_reconciliation_job.rb`.

Tests read: `test/models/enforcement_appeal_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-enforcement-appeal:T001 | DOCUMENTED_TRANSITION | submitted | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T002 | DOCUMENTED_TRANSITION | under_review | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T003 | DOCUMENTED_TRANSITION | submitted | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T004 | DOCUMENTED_TRANSITION | under_review | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T005 | DOCUMENTED_TRANSITION | submitted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T006 | DOCUMENTED_TRANSITION | under_review | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T007 | DOCUMENTED_TRANSITION | approved | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T008 | DOCUMENTED_TRANSITION | rejected | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-client-enforcement-appeal:T009 | DOCUMENTED_TRANSITION | redacted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |

Appeal state is separate from parent enforcement Case. under_review declared but entry setter UNKNOWN; resolve accepts submitted/under_review only, including locked replay refusal. Approved requires still in-force Case and reviewer separation; rejection does not end Case. Decision commits before Case-end/audit; reconciliation explicitly rediscovers approved appeal. Redact can replace approved/rejected with redacted without resolution_code clearing; historical resolution and current state can differ, and job selects submitted/approved/rejected only. No cancel or expiry field. All effect/appeal FK directions point to Case; no state reference table.

## idp-visitor-enforcement-case

Implementation: `EnforcementCaseApplyOperation / EndOperation / convergence jobs`. Storage: `com_enforcement_cases` / `state / ended_at`.

Sources: `app/models/concerns/enforcement_case_applicable.rb`, `app/models/com_enforcement_case.rb`, `app/operations/enforcement_case_apply_operation.rb`, `app/operations/enforcement_case_end_operation.rb`, `app/jobs/enforcement_expiry_job.rb`, `app/jobs/enforcement_reconciliation_job.rb`, `app/controllers/base/org/support/enforcement_cases/approvals_controller.rb`.

Tests read: `test/operations/enforcement_case_apply_failure_test.rb`, `test/models/enforcement_case_apply_ordering_test.rb`, `test/jobs/enforcement_expiry_job_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-enforcement-case:T001 | DOCUMENTED_TRANSITION | draft | controller requires approval | pending_approval | Creation requires approval; save pending state | Attach principal ref and request decision | app/controllers/base/org/support/enforcement_cases_controller.rb | CONFIRMED |
| idp-visitor-enforcement-case:T002 | DOCUMENTED_TRANSITION | draft | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T003 | DOCUMENTED_TRANSITION | pending_approval | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T004 | OUT_OF_BAND | active | RecordInvalid / RecordNotUnique side-effect failure | failed | Committed security decision; rescue narrow exceptions | update_column state failed; raise | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T005 | DOCUMENTED_TRANSITION | draft | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T006 | DOCUMENTED_TRANSITION | pending_approval | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T007 | DOCUMENTED_TRANSITION | active | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T008 | DOCUMENTED_TRANSITION | failed | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T009 | DOCUMENTED_TRANSITION | ended | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-visitor-enforcement-case:T010 | DOCUMENTED_TRANSITION | active | EnforcementExpiryJob | closed | expires_at <=now; active and not yet ended | End reason expired; refcount lock release | app/jobs/enforcement_expiry_job.rb | CONFIRMED |
| idp-visitor-enforcement-case:T011 | DOCUMENTED_TRANSITION | active | reconciliation | active | Pending convergence timestamps; active not ended | Retry revocation/audit, no state rewrite | app/jobs/enforcement_reconciliation_job.rb | CONFIRMED |
| idp-visitor-enforcement-case:T012 | DOCUMENTED_TRANSITION | closed | end reconcile / repeat | closed | Recorded end reason wins; lock; no duplicate end timestamp | Retry release/audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |

String CHECK; no state reference FK. Case governs authentication-method/principal/identifier effects through actual effect->case FKs; effects have effective/expiry/ended timestamps, not independent transition graphs. EndOperation does not write state=ended: it preserves stored state and writes ended_at; declared ended incoming writer UNKNOWN. Runtime in_force requires active, effective time reached, unexpired and no ended_at independently of jobs. Narrow side-effect failures write failed via update_column despite comments describing decision preserved active; pending_convergence and expiry select active only, so failed recovery path is UNKNOWN (hidden convergence dead end). Other exceptions retain active and may reconcile. Approval controller claims approver under lock; operation itself checks source outside transaction without lock. Superseding closes effect timestamps without necessarily ending old Case. Appeals and verification can end; cancel is not a distinct state. No distributed transaction with actor/token/Chronicle. Principal ref is logical cross-DB, not FK.

## idp-visitor-enforcement-appeal

Implementation: `EnforcementAppeal / EnforcementReconciliationJob`. Storage: `com_enforcement_appeals` / `state / resolution_code / reviewed_at`.

Sources: `app/models/concerns/enforcement_appeal.rb`, `app/models/com_enforcement_appeal.rb`, `app/jobs/enforcement_reconciliation_job.rb`.

Tests read: `test/models/enforcement_appeal_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-enforcement-appeal:T001 | DOCUMENTED_TRANSITION | submitted | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T002 | DOCUMENTED_TRANSITION | under_review | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T003 | DOCUMENTED_TRANSITION | submitted | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T004 | DOCUMENTED_TRANSITION | under_review | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T005 | DOCUMENTED_TRANSITION | submitted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T006 | DOCUMENTED_TRANSITION | under_review | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T007 | DOCUMENTED_TRANSITION | approved | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T008 | DOCUMENTED_TRANSITION | rejected | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-visitor-enforcement-appeal:T009 | DOCUMENTED_TRANSITION | redacted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |

Appeal state is separate from parent enforcement Case. under_review declared but entry setter UNKNOWN; resolve accepts submitted/under_review only, including locked replay refusal. Approved requires still in-force Case and reviewer separation; rejection does not end Case. Decision commits before Case-end/audit; reconciliation explicitly rediscovers approved appeal. Redact can replace approved/rejected with redacted without resolution_code clearing; historical resolution and current state can differ, and job selects submitted/approved/rejected only. No cancel or expiry field. All effect/appeal FK directions point to Case; no state reference table.

## idp-operator-enforcement-case

Implementation: `EnforcementCaseApplyOperation / EndOperation / convergence jobs`. Storage: `org_enforcement_cases` / `state / ended_at`.

Sources: `app/models/concerns/enforcement_case_applicable.rb`, `app/models/org_enforcement_case.rb`, `app/operations/enforcement_case_apply_operation.rb`, `app/operations/enforcement_case_end_operation.rb`, `app/jobs/enforcement_expiry_job.rb`, `app/jobs/enforcement_reconciliation_job.rb`, `app/controllers/base/org/support/enforcement_cases/approvals_controller.rb`.

Tests read: `test/operations/enforcement_case_apply_failure_test.rb`, `test/models/enforcement_case_apply_ordering_test.rb`, `test/jobs/enforcement_expiry_job_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-enforcement-case:T001 | DOCUMENTED_TRANSITION | draft | controller requires approval | pending_approval | Creation requires approval; save pending state | Attach principal ref and request decision | app/controllers/base/org/support/enforcement_cases_controller.rb | CONFIRMED |
| idp-operator-enforcement-case:T002 | DOCUMENTED_TRANSITION | draft | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T003 | DOCUMENTED_TRANSITION | pending_approval | apply operation | active | Source draft/pending; approver required when policy; transaction; operation does not row-lock source guard | Close superseded effects; save active, then lock actor/revoke/audit | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T004 | OUT_OF_BAND | active | RecordInvalid / RecordNotUnique side-effect failure | failed | Committed security decision; rescue narrow exceptions | update_column state failed; raise | app/operations/enforcement_case_apply_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T005 | DOCUMENTED_TRANSITION | draft | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T006 | DOCUMENTED_TRANSITION | pending_approval | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T007 | DOCUMENTED_TRANSITION | active | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T008 | DOCUMENTED_TRANSITION | failed | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T009 | DOCUMENTED_TRANSITION | ended | end operation | closed | Valid reason; row lock; ended_at first-write; no source state guard | Set ended_at/end_reason; end effects then release admin lock and audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |
| idp-operator-enforcement-case:T010 | DOCUMENTED_TRANSITION | active | EnforcementExpiryJob | closed | expires_at <=now; active and not yet ended | End reason expired; refcount lock release | app/jobs/enforcement_expiry_job.rb | CONFIRMED |
| idp-operator-enforcement-case:T011 | DOCUMENTED_TRANSITION | active | reconciliation | active | Pending convergence timestamps; active not ended | Retry revocation/audit, no state rewrite | app/jobs/enforcement_reconciliation_job.rb | CONFIRMED |
| idp-operator-enforcement-case:T012 | DOCUMENTED_TRANSITION | closed | end reconcile / repeat | closed | Recorded end reason wins; lock; no duplicate end timestamp | Retry release/audit | app/operations/enforcement_case_end_operation.rb | CONFIRMED |

String CHECK; no state reference FK. Case governs authentication-method/principal/identifier effects through actual effect->case FKs; effects have effective/expiry/ended timestamps, not independent transition graphs. EndOperation does not write state=ended: it preserves stored state and writes ended_at; declared ended incoming writer UNKNOWN. Runtime in_force requires active, effective time reached, unexpired and no ended_at independently of jobs. Narrow side-effect failures write failed via update_column despite comments describing decision preserved active; pending_convergence and expiry select active only, so failed recovery path is UNKNOWN (hidden convergence dead end). Other exceptions retain active and may reconcile. Approval controller claims approver under lock; operation itself checks source outside transaction without lock. Superseding closes effect timestamps without necessarily ending old Case. Appeals and verification can end; cancel is not a distinct state. No distributed transaction with actor/token/Chronicle. Principal ref is logical cross-DB, not FK.

## idp-operator-enforcement-appeal

Implementation: `EnforcementAppeal / EnforcementReconciliationJob`. Storage: `org_enforcement_appeals` / `state / resolution_code / reviewed_at`.

Sources: `app/models/concerns/enforcement_appeal.rb`, `app/models/org_enforcement_appeal.rb`, `app/jobs/enforcement_reconciliation_job.rb`.

Tests read: `test/models/enforcement_appeal_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-enforcement-appeal:T001 | DOCUMENTED_TRANSITION | submitted | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T002 | DOCUMENTED_TRANSITION | under_review | resolve! approved | approved | Appeal row lock; reviewer differs apply/approve actors; associated Case locked and in_force | Commit decision then end Case / audit; reconciliation retries | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T003 | DOCUMENTED_TRANSITION | submitted | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T004 | DOCUMENTED_TRANSITION | under_review | resolve! rejected | rejected | Appeal row lock; reviewer separation; unresolved | Persist reviewed time/resolution and audit | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T005 | DOCUMENTED_TRANSITION | submitted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T006 | DOCUMENTED_TRANSITION | under_review | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T007 | DOCUMENTED_TRANSITION | approved | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T008 | DOCUMENTED_TRANSITION | rejected | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |
| idp-operator-enforcement-appeal:T009 | DOCUMENTED_TRANSITION | redacted | redact! | redacted | No source state guard or own row lock | Clear encrypted statement; state redacted and timestamp | app/models/concerns/enforcement_appeal.rb | CONFIRMED |

Appeal state is separate from parent enforcement Case. under_review declared but entry setter UNKNOWN; resolve accepts submitted/under_review only, including locked replay refusal. Approved requires still in-force Case and reviewer separation; rejection does not end Case. Decision commits before Case-end/audit; reconciliation explicitly rediscovers approved appeal. Redact can replace approved/rejected with redacted without resolution_code clearing; historical resolution and current state can differ, and job selects submitted/approved/rejected only. No cancel or expiry field. All effect/appeal FK directions point to Case; no state reference table.

## idp-shared-sign-out-notice

Implementation: `Valkey::AuthState::SignOutNoticeStore`. Storage: `None (Valkey)` / `Key presence / payload expiry`.

Sources: `app/services/valkey/auth_state/sign_out_notice_store.rb`, `app/controllers/concerns/authentication_logout_current_session.rb`.

Tests read: `test/services/valkey/auth_state/sign_out_notice_store_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-shared-sign-out-notice:T001 | DOCUMENTED_TRANSITION | issued | consume / read(delete:true) | absent | Atomic GET+DEL Lua; payload checked after deletion | Burn before expiry/corrupt-payload refusal | app/services/valkey/auth_state/sign_out_notice_store.rb | CONFIRMED |
| idp-shared-sign-out-notice:T002 | DOCUMENTED_TRANSITION | issued | Redis wall-clock TTL | absent | Default5m | Automatic key eviction | app/services/valkey/auth_state/sign_out_notice_store.rb | CONFIRMED |

Notice is transport, not durable SignOutFlow progress. Payload state is opaque caller data, no lifecycle enum. Read without delete does not consume; consume atomically deletes first, then parses/checks logical expiry, so failure may burn. No tombstone: replay is missing. DefaultTTL5m; external browser response carries raw id while storage uses digest. No FK or SQL table.

## idp-client-mfa-readiness

Implementation: `MfaStatusTrackable / MfaStatusCredential`. Storage: `clients` / `mfa_status_id`.

Sources: `app/models/concerns/mfa_status_trackable.rb`, `app/models/concerns/mfa_status_credential.rb`, `app/models/client.rb`, `app/models/client_mfa_status.rb`.

Tests read: `test/models/client_mfa_status_test.rb`, `test/models/operator_mfa_status_test.rb`, `test/models/visitor_mfa_status_test.rb`, `test/models/concerns/mfa_status_trackable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-mfa-readiness:T001 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-client-mfa-readiness:T002 | DOCUMENTED_TRANSITION | UNCONFIGURED | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-client-mfa-readiness:T003 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-client-mfa-readiness:T004 | DOCUMENTED_TRANSITION | ACTIVE | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |

Reference IDs0/1/5; SQL default5. before_validation resolves NOTHING placeholder; after_create and credential after_commit refresh projected capability. Predicate raises on remaining NOTHING rather than silently normalizing. Calculation and save have no row lock/CAS; stale computation/concurrent credential changes are a potential projection boundary, not a demonstrated race. Same-status refresh is a no-op; no self transition is drawn. No lifecycle terminal/expiry/cancel; effective readiness is derived from credentials and duplicated as persisted projection. Does not mean MFA challenge has been passed; last_mfa_login_at is separate proof time.

## idp-visitor-mfa-readiness

Implementation: `MfaStatusTrackable / MfaStatusCredential`. Storage: `visitors` / `mfa_status_id`.

Sources: `app/models/concerns/mfa_status_trackable.rb`, `app/models/concerns/mfa_status_credential.rb`, `app/models/visitor.rb`, `app/models/visitor_mfa_status.rb`.

Tests read: `test/models/client_mfa_status_test.rb`, `test/models/operator_mfa_status_test.rb`, `test/models/visitor_mfa_status_test.rb`, `test/models/concerns/mfa_status_trackable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-mfa-readiness:T001 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-visitor-mfa-readiness:T002 | DOCUMENTED_TRANSITION | UNCONFIGURED | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-visitor-mfa-readiness:T003 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-visitor-mfa-readiness:T004 | DOCUMENTED_TRANSITION | ACTIVE | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |

Reference IDs0/1/5; SQL default5. before_validation resolves NOTHING placeholder; after_create and credential after_commit refresh projected capability. Predicate raises on remaining NOTHING rather than silently normalizing. Calculation and save have no row lock/CAS; stale computation/concurrent credential changes are a potential projection boundary, not a demonstrated race. Same-status refresh is a no-op; no self transition is drawn. No lifecycle terminal/expiry/cancel; effective readiness is derived from credentials and duplicated as persisted projection. Does not mean MFA challenge has been passed; last_mfa_login_at is separate proof time.

## idp-operator-mfa-readiness

Implementation: `MfaStatusTrackable / MfaStatusCredential`. Storage: `operators` / `mfa_status_id`.

Sources: `app/models/concerns/mfa_status_trackable.rb`, `app/models/concerns/mfa_status_credential.rb`, `app/models/operator.rb`, `app/models/operator_mfa_status.rb`.

Tests read: `test/models/client_mfa_status_test.rb`, `test/models/operator_mfa_status_test.rb`, `test/models/visitor_mfa_status_test.rb`, `test/models/concerns/mfa_status_trackable_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-operator-mfa-readiness:T001 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-operator-mfa-readiness:T002 | DOCUMENTED_TRANSITION | UNCONFIGURED | refresh_mfa_status! configured | ACTIVE | Persisted actor; configured_mfa_level_methods.any?; status differs; no row lock | Validated actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-operator-mfa-readiness:T003 | DOCUMENTED_TRANSITION | NOTHING | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |
| idp-operator-mfa-readiness:T004 | DOCUMENTED_TRANSITION | ACTIVE | refresh_mfa_status! unconfigured | UNCONFIGURED | Persisted actor; no configured MFA-level methods; status differs; no row lock | Actor save; updated_at | app/models/concerns/mfa_status_trackable.rb | CONFIRMED |

Reference IDs0/1/5; SQL default5. before_validation resolves NOTHING placeholder; after_create and credential after_commit refresh projected capability. Predicate raises on remaining NOTHING rather than silently normalizing. Calculation and save have no row lock/CAS; stale computation/concurrent credential changes are a potential projection boundary, not a demonstrated race. Same-status refresh is a no-op; no self transition is drawn. No lifecycle terminal/expiry/cancel; effective readiness is derived from credentials and duplicated as persisted projection. Does not mean MFA challenge has been passed; last_mfa_login_at is separate proof time.

## idp-client-email-registration-session

Implementation: `app/controllers/concerns/sign_email_registrable.rb`. Storage: Rails session key `sign_up_email_flow_state`; no SQL table, PK, FK, default or CHECK.

Sources: `app/controllers/concerns/sign_email_registrable.rb`, `app/controllers/auth/app/sign/up/emails_controller.rb`, `app/controllers/auth/app/sign/up/check/email/otps_controller.rb`.

Tests read: `test/controllers/concerns/sign/email_registrable_included_do_test.rb`, `test/controllers/concerns/sign/email_registration_flow_test.rb`, `test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-email-registration-session:T001 | DOCUMENTED_TRANSITION | init | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T002 | DOCUMENTED_TRANSITION | init | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T003 | DOCUMENTED_TRANSITION | init | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T004 | DOCUMENTED_TRANSITION | email_created | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T005 | DOCUMENTED_TRANSITION | email_created | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T006 | DOCUMENTED_TRANSITION | email_created | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T007 | DOCUMENTED_TRANSITION | email_verified | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T008 | DOCUMENTED_TRANSITION | email_verified | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T009 | DOCUMENTED_TRANSITION | email_verified | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T010 | OUT_OF_BAND | init | progress_email_flow!(:destroy) declared helper | init | Helper mapping exists; HTTP destroy caller UNCONFIRMED | Write session state init | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T011 | OUT_OF_BAND | email_created | progress_email_flow!(:destroy) declared helper | init | Helper mapping exists; HTTP destroy caller UNCONFIRMED | Write session state init | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |
| idp-client-email-registration-session:T012 | OUT_OF_BAND | email_verified | progress_email_flow!(:destroy) declared helper | init | Helper mapping exists; HTTP destroy caller UNCONFIRMED | Write session state init | app/controllers/concerns/sign_email_registrable.rb | CONFIRMED |

No helper lock or generation check exists on this session key. Durable sign-up/OTP guards remain separate. Session storage concurrency guarantees are UNCONFIRMED. Source normalization writes init for absent or unrecognized values; unknown input values are not invented lifecycle nodes. Terminality is not absorbing: reset remains available. Client destroy progression is declared in FLOW_PROGRESSIONS but an HTTP destroy caller is UNCONFIRMED. Visitor OTP controller inherits the visitor helper and writes email_verified after verified OTP and before durable flow advancement.

## idp-visitor-email-registration-session

Implementation: `app/controllers/auth/com/sign/up/emails_controller.rb`. Storage: Rails session key `auth_com_up_email_flow_state`; no SQL table, PK, FK, default or CHECK.

Sources: `app/controllers/auth/com/sign/up/emails_controller.rb`, `app/controllers/auth/com/sign/up/check/email/otps_controller.rb`.

Tests read: `test/controllers/concerns/sign/email_registrable_included_do_test.rb`, `test/controllers/concerns/sign/email_registration_flow_test.rb`, `test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb`.

| Transition ID | Mutation kind | From | Event / Trigger | To | Guard | Side effect | Source file | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-visitor-email-registration-session:T001 | DOCUMENTED_TRANSITION | init | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T002 | DOCUMENTED_TRANSITION | init | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T003 | DOCUMENTED_TRANSITION | init | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T004 | DOCUMENTED_TRANSITION | email_created | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T005 | DOCUMENTED_TRANSITION | email_created | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T006 | DOCUMENTED_TRANSITION | email_created | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T007 | DOCUMENTED_TRANSITION | email_verified | progress_email_flow!(:create) | email_created | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T008 | DOCUMENTED_TRANSITION | email_verified | progress_email_flow!(:update) | email_verified | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |
| idp-visitor-email-registration-session:T009 | DOCUMENTED_TRANSITION | email_verified | reset_email_flow! | init | Private helper API has no source guard; real HTTP calls require the documented entry/OTP checks | Write session key; reset clears related continuity references | app/controllers/auth/com/sign/up/emails_controller.rb | CONFIRMED |

No helper lock or generation check exists on this session key. Durable sign-up/OTP guards remain separate. Session storage concurrency guarantees are UNCONFIRMED. Source normalization writes init for absent or unrecognized values; unknown input values are not invented lifecycle nodes. Terminality is not absorbing: reset remains available. Client destroy progression is declared in FLOW_PROGRESSIONS but an HTTP destroy caller is UNCONFIRMED. Visitor OTP controller inherits the visitor helper and writes email_verified after verified OTP and before durable flow advancement.

App Secret OIDC Base readiness: `ClientSignInFlow#prepare_secret_oidc_issuance!` advances `DASHBOARD_PENDING` to `SESSION_ISSUANCE_PENDING` under the authorization transaction and flow locks. It requires matching authenticated OIDC actor, irreversible source claim, completed admitted Auth ceremony, normal authentication context, and all original deadlines. Completed Auth handoff is evidence transport completion, not root login completion.

App Secret OIDC session-limit cancellation uses the existing `SESSION_LIMIT_PENDING` to `FAILED` transition. The limitation DELETE arbitrates with issuance under the Client and OIDC transaction locks, records the canceled resolution and failed flow on Ticket, then retires the source claim with verified `flow_canceled` audit.

App OIDC physical transaction collection locks eligible authorization rows and excludes rows whose Secret flow is referenced by a Source claim or Ticket receipt, plus rows referenced by session-limit resolutions. This preserves terminal reconciliation proof. It does not add a status transition or modify com/org expiry collection. Dependency proof collection remains a separate unfinished lifecycle step.

App Secret OIDC limitation selection now enters `ClientSessionLimitResolutionTransaction#with_secret_revocation_authority!` before selection or existing-session revocation. It locks Client, OIDC authorization, resolution and Secret flow in that order, reloads the persisted challenge/actor/open-state/deadline bindings, and permits the callback only while the flow is `SESSION_LIMIT_PENDING` without a token or issuance time. Cancellation shares that exclusion boundary. This guard restricts the Secret HTTP caller; the direct setter transitions inventoried above remain possible on other paths. Separate-connection cancellation/expiration barriers verify rejection at the public model boundary; complete concurrent HTTP callback/issuance coverage remains pending.

App Secret withdrawal revocation: terminated Client proof under source Client lock authorizes revocation. Unclaimed credentials receive discard and retention facts with withdrawal audit in the same source transaction. Claimed credentials retain continuation/discard eligibility until the existing Ticket terminal reconciliation; withdrawal does not release a claim or physically delete its proof.

App Secret issuance withdrawal cancellation: unconfirmed positive issuance enters canceled state under its terminated Client lock; encrypted payload is erased and reservation released with source cancellation audit. Confirmed and zero-count omitted results remain immutable.

## idp-client-secret-audit-outbox

Source delivery state is distinct from Chronicle commit and business authentication facts.

| Transition ID | Classification | From | Trigger | To | Guards | Effects | Source | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-secret-audit-outbox:T001 | DOCUMENTED_TRANSITION | pending | periodic delivery scan | delivered | Matching immutable Chronicle event identity; source row lock | delivered_at and finite retention timestamps | app/jobs/client_secret_audit_delivery_job.rb | CONFIRMED |
| idp-client-secret-audit-outbox:T002 | DOCUMENTED_TRANSITION | delivered | lifecycle collection | deleted | Deadline reached; no hold; no source credential/issuance or Ticket receipt dependency; Chronicle commit; issuance_purged replay barrier requires absent Client | Source DELETE; Chronicle remains; live-owner barriers remain retained | app/operations/client_secret_audit_outbox_purger.rb | CONFIRMED |
| idp-client-secret-audit-outbox:T003 | REJECTED_TRANSITION | pending | lifecycle collection | deleted | No confirmed delivery | Return undelivered; retain event | app/operations/client_secret_audit_outbox_purger.rb | CONFIRMED |
| idp-client-secret-audit-outbox:T004 | DOCUMENTED_TRANSITION | delivered | bounded scan reaches held or dependent row | delivered | Current purger rejects deletion; fixed upper ID bound; recheck suspension on continuation | Retain row; enqueue next cursor so later rows can be considered | app/jobs/client_secret_audit_outbox_purge_job.rb | CONFIRMED |

## idp-client-secret-sign-in-receipt

Lifecycle receipt collection advances a bounded fixed-horizon cursor past retained
receipts and queues continuation on the existing retention queue. A fresh periodic
scan recovers lost enqueue. `test/integration/app_secret_receipt_collection_journey_test.rb`
establishes two canonical root logins through HTTP, retains the first receipt under
legal hold and collects the later receipt through the real lifecycle continuation.
Both established root tokens remain usable. Cursor position conveys no purge authority.

| Transition ID | Classification | From | Trigger | To | Guards | Effects | Source | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idp-client-secret-sign-in-receipt:T001 | DOCUMENTED_TRANSITION | absent | canonical root login commit | committed | Matching durable claim, Client, flow, ceremony and root token | Immutable receipt in the same Ticket transaction | app/models/client_secret_sign_in_receipt.rb | CONFIRMED |
| idp-client-secret-sign-in-receipt:T002 | DOCUMENTED_TRANSITION | committed | lifecycle proof collection | deleted | Explicit proof retention after latest continuation deadline and terminal Chronicle time; no Source credential; consumed and purged audit match; no hold; Source Client then OIDC/flow/receipt locks | Receipt DELETE; root token remains; bounded continuation passes retained receipts | app/operations/client_secret_sign_in_receipt_purger.rb; app/jobs/client_secret_lifecycle_job.rb | CONFIRMED |
| idp-client-secret-sign-in-receipt:T003 | REJECTED_TRANSITION | committed | generic flow collection | absent | Receipt still references flow | Flow retained; no cascade receipt loss | app/jobs/retention_purge_job.rb | CONFIRMED |
