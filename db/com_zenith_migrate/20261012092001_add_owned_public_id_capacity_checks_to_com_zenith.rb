# frozen_string_literal: true

class AddOwnedPublicIdCapacityChecksToComZenith < ActiveRecord::Migration[8.2]
  TABLES = [:com_enforcement_appeals, :companies, :company_ownership_transfer_requests, :company_units, :core_com_visitor_bridges, :individual_assignments, :individual_ownership_transfer_requests, :individuals, :visitor_accounts, :visitor_identities].freeze
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
