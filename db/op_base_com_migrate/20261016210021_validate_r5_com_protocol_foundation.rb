# typed: false
# frozen_string_literal: true

class ValidateR5ComProtocolFoundation < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CHECKS = {
    visitor_tokens: "chk_visitor_tokens_contract_epoch",
    op_com_grants: "chk_op_com_grants_contract_epoch",
    visitor_oidc_authorization_transactions: "chk_visitor_oidc_authorization_transactions_contract_epoch",
    op_protocol_epochs: %w(chk_op_protocol_epochs_singleton chk_op_protocol_epochs_com_shape),
    op_consumed_jtis: "chk_op_com_consumed_jtis_realm",
    logout_flows: "chk_op_com_logout_flows_realm",
    logout_flow_participants: "chk_op_com_logout_participants_shape",
    op_outbox_events: "chk_op_com_outbox_events_shape",
    op_inbound_event_receipts: "chk_op_com_inbound_event_receipts_realm",
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
