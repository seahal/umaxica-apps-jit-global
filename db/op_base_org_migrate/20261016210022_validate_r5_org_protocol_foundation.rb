# typed: false
# frozen_string_literal: true

class ValidateR5OrgProtocolFoundation < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CHECKS = {
    operator_tokens: "chk_operator_tokens_contract_epoch",
    op_org_grants: "chk_op_org_grants_contract_epoch",
    operator_oidc_authorization_transactions: "chk_operator_oidc_authorization_transactions_contract_epoch",
    op_protocol_epochs: %w(chk_op_protocol_epochs_singleton chk_op_protocol_epochs_org_shape),
    op_consumed_jtis: "chk_op_org_consumed_jtis_realm",
    logout_flows: "chk_op_org_logout_flows_realm",
    logout_flow_participants: "chk_op_org_logout_participants_shape",
    op_outbox_events: "chk_op_org_outbox_events_shape",
    op_inbound_event_receipts: "chk_op_org_inbound_event_receipts_realm",
  }.freeze

  def up
    CHECKS.each do |table, constraints|
      Array(constraints).each { |name| validate_check_constraint(table, name:) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 protocol constraints are forward-only"
  end
end
