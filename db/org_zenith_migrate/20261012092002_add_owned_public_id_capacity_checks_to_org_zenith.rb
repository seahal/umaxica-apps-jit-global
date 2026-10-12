# frozen_string_literal: true

class AddOwnedPublicIdCapacityChecksToOrgZenith < ActiveRecord::Migration[8.2]
  TABLES = [:agent_assignments, :agent_ownership_transfer_requests, :agents, :bureau_ownership_transfer_requests, :bureau_units, :bureaus, :core_org_operator_bridges, :operator_accounts, :operator_identities, :operator_workspace_accounts, :org_enforcement_appeals].freeze
  EXPRESSION = "char_length(public_id) <= 25"

  def up
    TABLES.each do |table|
      add_check_constraint(
        table,
        EXPRESSION,
        name: "#{table}_public_id_max_length",
        validate: false,
      )
    end
  end

  def down
    TABLES.each do |table|
      remove_check_constraint(table, name: "#{table}_public_id_max_length")
    end
  end
end
