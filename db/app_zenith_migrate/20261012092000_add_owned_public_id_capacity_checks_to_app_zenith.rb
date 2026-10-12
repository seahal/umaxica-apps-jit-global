# frozen_string_literal: true

class AddOwnedPublicIdCapacityChecksToAppZenith < ActiveRecord::Migration[8.2]
  TABLES = [:app_enforcement_appeals, :client_accounts, :client_identities, :client_persona_ownership_transfer_requests, :client_profiles, :core_app_client_bridges, :enterprise_ownership_transfer_requests, :enterprise_units, :enterprises, :persona_assignments, :personas].freeze
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
