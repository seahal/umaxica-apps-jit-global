# frozen_string_literal: true

class FixNanoidPublicIdLengthComZenith < ActiveRecord::Migration[8.2]
  # adr/identifier-contract.md: NanoID public_id is varchar(21) with an exact-length CHECK.
  # [table, previous varchar limit (nil = unbounded), replaced capacity check name, its expression]
  TABLES = [
    [:com_enforcement_appeals, nil, "com_enforcement_appeals_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:companies, nil, "companies_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:company_ownership_transfer_requests, nil, "company_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:company_units, nil, "company_units_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:core_com_visitor_bridges, nil, "core_com_visitor_bridges_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:individuals, nil, "individuals_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:individual_assignments, nil, "individual_assignments_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:individual_ownership_transfer_requests, nil, "individual_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:visitors, nil, "visitors_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:visitor_accounts, nil, "visitor_accounts_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:visitor_emails, 21, nil, nil],
    [:visitor_enforcement_recovery_ceremonies, 21, nil, nil],
    [:visitor_identities, nil, "visitor_identities_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:visitor_passkeys, 21, nil, nil],
    [:visitor_preferences, 21, nil, nil],
    [:visitor_privacy_requests, 21, nil, nil],
    [:visitor_processor_erasure_notifications, 21, nil, nil],
    [:visitor_retention_holds, 21, nil, nil],
    [:visitor_secret_credentials, 21, nil, nil],
    [:visitor_telephones, 21, nil, nil],
    [:visitor_withdrawal_ceremonies, 21, nil, nil],
    [:visitor_withdrawal_flows, 21, nil, nil],
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
