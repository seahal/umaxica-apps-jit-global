# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOpBaseApp < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:acme_logout_transactions, name: "chk_acme_logout_transactions_pid")
    validate_check_constraint(:client_device_sessions, name: "chk_client_device_sessions_pid")
    validate_check_constraint(:client_oidc_connections, name: "chk_client_oidc_connections_pid")
    validate_check_constraint(:client_sign_in_flows, name: "chk_client_sign_in_flows_pid")
    validate_check_constraint(:client_sign_out_flows, name: "chk_client_sign_out_flows_pid")
    validate_check_constraint(:client_sign_up_flows, name: "chk_client_sign_up_flows_pid")
    validate_check_constraint(:client_tokens, name: "chk_client_tokens_pid")
    validate_check_constraint(:op_app_grants, name: "chk_op_app_grants_pid")
  end
end
