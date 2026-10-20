# frozen_string_literal: true

class FixNanoidPublicIdLengthOpBaseApp < ActiveRecord::Migration[8.2]
  # adr/identifier-contract.md: NanoID public_id is varchar(21) with an exact-length CHECK.
  # [table, previous varchar limit (nil = unbounded), replaced capacity check name, its expression]
  TABLES = [
    [:acme_logout_transactions, nil, "acme_logout_transactions_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_device_sessions, 21, nil, nil],
    [:client_oidc_connections, 21, nil, nil],
    [:client_sign_in_flows, 21, nil, nil],
    [:client_sign_out_flows, 21, nil, nil],
    [:client_sign_up_flows, 21, nil, nil],
    [:client_tokens, 21, nil, nil],
    [:op_app_grants, 21, nil, nil],
  ].freeze

  def up
    TABLES.each do |table, previous_limit, capacity_check, _expression|
      remove_check_constraint(table, name: capacity_check) if capacity_check
      # Narrowing the type is reviewed here: every stored value is a 21-character NanoID.
      safety_assured { change_column(table, :public_id, :string, limit: 21) } unless previous_limit == 21
      add_check_constraint(table, "char_length(public_id) = 21", name: "chk_#{table}_pid", validate: false)
    end
  end

  def down
    TABLES.reverse_each do |table, previous_limit, capacity_check, expression|
      remove_check_constraint(table, name: "chk_#{table}_pid")
      safety_assured { change_column(table, :public_id, :string, limit: previous_limit) } unless previous_limit == 21
      add_check_constraint(table, expression, name: capacity_check) if capacity_check
    end
  end
end
