# Rails Association and PostgreSQL FK Review

Source: 984 Rails `belongs_to` reflections captured through a verified isolated Rails boot and the read-only Global development catalog at 2026-09-24T10:25:33Z. This is a structural coverage screen: an FK covering the association column and target table may be composite and may enforce additional ownership. A missing single association FK is a review item, not automatically a defect. Cross-database and polymorphic associations cannot be represented by an ordinary same-database FK.

Counts: 931 associations with both tables live in the same logical DB; 897 covered by a same-parent FK containing the association column(s); 34 without that coverage; 31 cross-database; 13 polymorphic; 9 with at least one table absent from shared development. The disjoint categories sum to 984, equal to the reflection count.

| Model | Association | Logical DB | Child table/column | Target table | Review |
| --- | --- | --- | --- | --- | --- |
| `AvatarAgentBinding` | `avatar` | avatar | `avatar_agent_bindings(avatar_id)` | `avatars` | No same-parent FK in shared development; check lifecycle and local migrations |
| `AvatarIndividualBinding` | `avatar` | avatar | `avatar_individual_bindings(avatar_id)` | `avatars` | No same-parent FK in shared development; check lifecycle and local migrations |
| `AvatarPersonaBinding` | `avatar` | avatar | `avatar_persona_bindings(avatar_id)` | `avatars` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientAccount` | `user` | app_zenith | `client_accounts(user_id)` | `clients` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientDeviceSession` | `current_refresh_token` | app_ticket | `client_device_sessions(current_refresh_token_id)` | `client_tokens` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientProfile` | `user` | app_zenith | `client_profiles(user_id)` | `clients` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientSessionLimitResolutionTransaction` | `oidc_authorization_transaction` | app_ticket | `client_session_limit_resolution_transactions(oidc_authorization_transaction_id)` | `client_oidc_authorization_transactions` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientToken` | `device_session` | app_ticket | `client_tokens(device_session_id)` | `client_device_sessions` | No same-parent FK in shared development; check lifecycle and local migrations |
| `ClientToken` | `oidc_connection` | app_ticket | `client_tokens(oidc_connection_id)` | `client_oidc_connections` | No same-parent FK in shared development; check lifecycle and local migrations |
| `CoreAppClientBridge` | `client` | app_zenith | `core_app_client_bridges(client_id)` | `clients` | No same-parent FK in shared development; check lifecycle and local migrations |
| `CoreComVisitorBridge` | `visitor` | com_zenith | `core_com_visitor_bridges(visitor_id)` | `visitors` | No same-parent FK in shared development; check lifecycle and local migrations |
| `CoreOrgOperatorBridge` | `operator` | org_zenith | `core_org_operator_bridges(operator_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `HandleAssignment` | `assigned_by_actor` | avatar | `handle_assignments(assigned_by_actor_id)` | `avatars` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorAccount` | `staff` | org_zenith | `operator_accounts(staff_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorDeviceSession` | `current_refresh_token` | org_ticket | `operator_device_sessions(current_refresh_token_id)` | `operator_tokens` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorEntraIdentity` | `connection` | org_zenith | `operator_entra_identities(connection_id)` | `organization_entra_connections` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorLifecycleRequest` | `approved_by_operator` | org_zenith | `operator_lifecycle_requests(approved_by_operator_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorLifecycleRequest` | `executed_by_operator` | org_zenith | `operator_lifecycle_requests(executed_by_operator_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorLifecycleRequest` | `rejected_by_operator` | org_zenith | `operator_lifecycle_requests(rejected_by_operator_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorLifecycleRequest` | `target_operator` | org_zenith | `operator_lifecycle_requests(target_operator_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorToken` | `device_session` | org_ticket | `operator_tokens(device_session_id)` | `operator_device_sessions` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorToken` | `oidc_connection` | org_ticket | `operator_tokens(oidc_connection_id)` | `operator_oidc_connections` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorWorkspaceAccount` | `department` | org_zenith | `operator_workspace_accounts(department_id)` | `departments` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorWorkspaceAccount` | `operator` | org_zenith | `operator_workspace_accounts(staff_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorWorkspaceAccount` | `operator_workspace_account_status` | org_zenith | `operator_workspace_accounts(status_id)` | `operator_workspace_account_statuses` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorWorkspaceAccount` | `staff` | org_zenith | `operator_workspace_accounts(staff_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `OperatorWorkspaceAccountMembership` | `staff` | org_zenith | `operator_workspace_account_memberships(staff_id)` | `operators` | No same-parent FK in shared development; check lifecycle and local migrations |
| `SolidQueue::ClaimedExecution` | `process` | queue | `solid_queue_claimed_executions(process_id)` | `solid_queue_processes` | No same-parent FK in shared development; check lifecycle and local migrations |
| `SolidQueue::Job` | `batch` | queue | `solid_queue_jobs(batch_id)` | `solid_queue_batches` | No same-parent FK in shared development; check lifecycle and local migrations |
| `SolidQueue::Process` | `supervisor` | queue | `solid_queue_processes(supervisor_id)` | `solid_queue_processes` | No same-parent FK in shared development; check lifecycle and local migrations |
| `VisitorAccount` | `visitor` | com_zenith | `visitor_accounts(visitor_id)` | `visitors` | No same-parent FK in shared development; check lifecycle and local migrations |
| `VisitorDeviceSession` | `current_refresh_token` | com_ticket | `visitor_device_sessions(current_refresh_token_id)` | `visitor_tokens` | No same-parent FK in shared development; check lifecycle and local migrations |
| `VisitorToken` | `device_session` | com_ticket | `visitor_tokens(device_session_id)` | `visitor_device_sessions` | No same-parent FK in shared development; check lifecycle and local migrations |
| `VisitorToken` | `oidc_connection` | com_ticket | `visitor_tokens(oidc_connection_id)` | `visitor_oidc_connections` | No same-parent FK in shared development; check lifecycle and local migrations |
