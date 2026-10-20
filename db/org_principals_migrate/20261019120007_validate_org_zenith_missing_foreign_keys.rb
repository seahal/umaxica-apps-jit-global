# frozen_string_literal: true

class ValidateOrgZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:operator_workspace_account_memberships, name: "fk_operator_workspace_account_memberships_on_staff_id")
    validate_foreign_key(:operator_entra_identities, name: "fk_operator_entra_identities_on_connection_id")
    validate_foreign_key(:operator_accounts, name: "fk_operator_accounts_on_staff_id")
    validate_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_status_id")
    validate_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_staff_id")
    validate_foreign_key(:operator_workspace_accounts, name: "fk_operator_workspace_accounts_on_department_id")
    validate_foreign_key(:core_org_operator_bridges, name: "fk_core_org_operator_bridges_on_operator_id")
    validate_foreign_key(:operator_lifecycle_requests, name: "fk_operator_lifecycle_requests_on_target_operator_id")
    validate_foreign_key(:operator_lifecycle_requests, name: "fk_operator_lifecycle_requests_on_approved_by_operator_id")
    validate_foreign_key(:operator_lifecycle_requests, name: "fk_operator_lifecycle_requests_on_rejected_by_operator_id")
    validate_foreign_key(:operator_lifecycle_requests, name: "fk_operator_lifecycle_requests_on_executed_by_operator_id")
  end
end
