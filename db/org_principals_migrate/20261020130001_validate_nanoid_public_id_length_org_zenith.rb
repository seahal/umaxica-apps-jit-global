# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOrgZenith < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:agents, name: "chk_agents_pid")
    validate_check_constraint(:agent_assignments, name: "chk_agent_assignments_pid")
    validate_check_constraint(:agent_ownership_transfer_requests, name: "chk_agent_ownership_transfer_requests_pid")
    validate_check_constraint(:bureaus, name: "chk_bureaus_pid")
    validate_check_constraint(:bureau_ownership_transfer_requests, name: "chk_bureau_ownership_transfer_requests_pid")
    validate_check_constraint(:bureau_units, name: "chk_bureau_units_pid")
    validate_check_constraint(:core_org_operator_bridges, name: "chk_core_org_operator_bridges_pid")
    validate_check_constraint(:operator_accounts, name: "chk_operator_accounts_pid")
    validate_check_constraint(:operator_bulletins, name: "chk_operator_bulletins_pid")
    validate_check_constraint(:operator_capability_grants, name: "chk_operator_capability_grants_pid")
    validate_check_constraint(:operator_emails, name: "chk_operator_emails_pid")
    validate_check_constraint(:operator_entra_identities, name: "chk_operator_entra_identities_pid")
    validate_check_constraint(:operator_identities, name: "chk_operator_identities_pid")
    validate_check_constraint(:operator_lifecycle_requests, name: "chk_operator_lifecycle_requests_pid")
    validate_check_constraint(:operator_preferences, name: "chk_operator_preferences_pid")
    validate_check_constraint(:operator_secret_credentials, name: "chk_operator_secret_credentials_pid")
    validate_check_constraint(:operator_telephones, name: "chk_operator_telephones_pid")
    validate_check_constraint(:operator_workspace_accounts, name: "chk_operator_workspace_accounts_pid")
    validate_check_constraint(:org_enforcement_appeals, name: "chk_org_enforcement_appeals_pid")
    validate_check_constraint(:organization_entra_connections, name: "chk_organization_entra_connections_pid")
  end
end
