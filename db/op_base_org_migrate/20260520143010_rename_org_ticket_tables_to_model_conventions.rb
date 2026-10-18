# frozen_string_literal: true

class RenameOrgTicketTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :org_sign_in_cycles, :operator_sign_in_cycles
    rename_table_strict :org_sign_up_cycles, :operator_sign_up_cycles
    rename_table_strict :staff_authorization_codes, :operator_authorization_codes
    rename_table_strict :staff_oidc_connections, :operator_oidc_connections
    rename_table_strict :staff_step_up_sessions, :operator_step_up_sessions
    rename_table_strict :staff_token_binding_methods, :operator_token_binding_methods
    rename_table_strict :staff_token_dbsc_statuses, :operator_token_dbsc_statuses
    rename_table_strict :staff_token_kinds, :operator_token_kinds
    rename_table_strict :staff_token_statuses, :operator_token_statuses
    rename_table_strict :staff_tokens, :operator_tokens
    rename_table_strict :staff_verifications, :operator_verifications
  end

  def down
    rename_table_strict :operator_verifications, :staff_verifications
    rename_table_strict :operator_tokens, :staff_tokens
    rename_table_strict :operator_token_statuses, :staff_token_statuses
    rename_table_strict :operator_token_kinds, :staff_token_kinds
    rename_table_strict :operator_token_dbsc_statuses, :staff_token_dbsc_statuses
    rename_table_strict :operator_token_binding_methods, :staff_token_binding_methods
    rename_table_strict :operator_step_up_sessions, :staff_step_up_sessions
    rename_table_strict :operator_oidc_connections, :staff_oidc_connections
    rename_table_strict :operator_authorization_codes, :staff_authorization_codes
    rename_table_strict :operator_sign_up_cycles, :org_sign_up_cycles
    rename_table_strict :operator_sign_in_cycles, :org_sign_in_cycles
  end
end
