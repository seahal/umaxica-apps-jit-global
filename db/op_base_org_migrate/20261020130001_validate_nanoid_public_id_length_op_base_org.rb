# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOpBaseOrg < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:op_org_grants, name: "chk_op_org_grants_pid")
    validate_check_constraint(:operator_device_sessions, name: "chk_operator_device_sessions_pid")
    validate_check_constraint(:operator_oidc_connections, name: "chk_operator_oidc_connections_pid")
    validate_check_constraint(:operator_sign_in_flows, name: "chk_operator_sign_in_flows_pid")
    validate_check_constraint(:operator_sign_out_flows, name: "chk_operator_sign_out_flows_pid")
    validate_check_constraint(:operator_sign_up_flows, name: "chk_operator_sign_up_flows_pid")
    validate_check_constraint(:operator_tokens, name: "chk_operator_tokens_pid")
  end
end
