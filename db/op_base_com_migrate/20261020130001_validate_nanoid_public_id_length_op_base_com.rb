# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOpBaseCom < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:op_com_grants, name: "chk_op_com_grants_pid")
    validate_check_constraint(:visitor_device_sessions, name: "chk_visitor_device_sessions_pid")
    validate_check_constraint(:visitor_oidc_connections, name: "chk_visitor_oidc_connections_pid")
    validate_check_constraint(:visitor_sign_in_flows, name: "chk_visitor_sign_in_flows_pid")
    validate_check_constraint(:visitor_sign_out_flows, name: "chk_visitor_sign_out_flows_pid")
    validate_check_constraint(:visitor_sign_up_flows, name: "chk_visitor_sign_up_flows_pid")
    validate_check_constraint(:visitor_tokens, name: "chk_visitor_tokens_pid")
  end
end
