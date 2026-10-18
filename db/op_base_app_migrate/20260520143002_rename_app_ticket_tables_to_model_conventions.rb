# frozen_string_literal: true

class RenameAppTicketTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :app_sign_in_cycles, :client_sign_in_cycles
    rename_table_strict :app_sign_up_cycles, :client_sign_up_cycles
    rename_table_strict :user_authorization_codes, :client_authorization_codes
    rename_table_strict :user_oidc_connections, :client_oidc_connections
    rename_table_strict :user_step_up_sessions, :client_step_up_sessions
    rename_table_strict :user_token_binding_methods, :client_token_binding_methods
    rename_table_strict :user_token_dbsc_statuses, :client_token_dbsc_statuses
    rename_table_strict :user_token_kinds, :client_token_kinds
    rename_table_strict :user_token_statuses, :client_token_statuses
    rename_table_strict :user_tokens, :client_tokens
    rename_table_strict :user_verifications, :client_verifications
  end

  def down
    rename_table_strict :client_verifications, :user_verifications
    rename_table_strict :client_tokens, :user_tokens
    rename_table_strict :client_token_statuses, :user_token_statuses
    rename_table_strict :client_token_kinds, :user_token_kinds
    rename_table_strict :client_token_dbsc_statuses, :user_token_dbsc_statuses
    rename_table_strict :client_token_binding_methods, :user_token_binding_methods
    rename_table_strict :client_step_up_sessions, :user_step_up_sessions
    rename_table_strict :client_oidc_connections, :user_oidc_connections
    rename_table_strict :client_authorization_codes, :user_authorization_codes
    rename_table_strict :client_sign_up_cycles, :app_sign_up_cycles
    rename_table_strict :client_sign_in_cycles, :app_sign_in_cycles
  end
end
