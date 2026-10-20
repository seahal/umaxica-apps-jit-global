# frozen_string_literal: true

class AddOrgZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :operator_workspace_account_memberships, :operators, column: :staff_id, name: "fk_operator_workspace_account_memberships_on_staff_id",
                                                           on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_entra_identities, :organization_entra_connections, column: :connection_id, name: "fk_operator_entra_identities_on_connection_id",
                                                                   on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_accounts, :operators, column: :staff_id, name: "fk_operator_accounts_on_staff_id",
                                      on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_workspace_accounts, :operator_workspace_account_statuses, column: :status_id, name: "fk_operator_workspace_accounts_on_status_id",
                                                                          on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_workspace_accounts, :operators, column: :staff_id, name: "fk_operator_workspace_accounts_on_staff_id",
                                                on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_workspace_accounts, :departments, column: :department_id, name: "fk_operator_workspace_accounts_on_department_id",
                                                  on_delete: :nullify, validate: false,
    )
    add_foreign_key(
      :core_org_operator_bridges, :operators, column: :operator_id, name: "fk_core_org_operator_bridges_on_operator_id",
                                              on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_lifecycle_requests, :operators, column: :target_operator_id, name: "fk_operator_lifecycle_requests_on_target_operator_id",
                                                on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_lifecycle_requests, :operators, column: :approved_by_operator_id, name: "fk_operator_lifecycle_requests_on_approved_by_operator_id",
                                                on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_lifecycle_requests, :operators, column: :rejected_by_operator_id, name: "fk_operator_lifecycle_requests_on_rejected_by_operator_id",
                                                on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_lifecycle_requests, :operators, column: :executed_by_operator_id, name: "fk_operator_lifecycle_requests_on_executed_by_operator_id",
                                                on_delete: :restrict, validate: false,
    )
  end
end
