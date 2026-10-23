# frozen_string_literal: true

# WU-17 (D-35, D-168): the OP protocol contract epoch and client activation are removed. The
# dropped tables carry no state to restore; recovery is rebuilding the database from migrations,
# which the owner accepted (D-168).
class RemoveContractEpochOpBaseCom < ActiveRecord::Migration[8.2]
  COLUMNS = {
    visitor_tokens: "chk_visitor_tokens_contract_epoch",
    op_com_grants: "chk_op_com_grants_contract_epoch",
    visitor_oidc_authorization_transactions: "chk_visitor_oidc_authorization_transactions_contract_epoch",
  }.freeze

  def up
    safety_assured do
      drop_table(:op_client_activations)
      drop_table(:op_protocol_epochs)
      COLUMNS.each do |table, check|
        remove_check_constraint(table, name: check)
        remove_column(table, :contract_epoch)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rebuild from migrations; D-168 accepts the loss"
  end
end
