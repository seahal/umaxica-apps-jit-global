# frozen_string_literal: true

class FixNanoidPublicIdLengthAppZenith < ActiveRecord::Migration[8.2]
  # adr/identifier-contract.md: NanoID public_id is varchar(21) with an exact-length CHECK.
  # [table, previous varchar limit (nil = unbounded), replaced capacity check name, its expression]
  TABLES = [
    [:app_enforcement_appeals, nil, "app_enforcement_appeals_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:clients, 255, "clients_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_accounts, nil, "client_accounts_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_bulletins, 21, nil, nil],
    [:client_emails, 21, nil, nil],
    [:client_enforcement_recovery_ceremonies, 21, nil, nil],
    [:client_identities, nil, "client_identities_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_passkeys, 21, nil, nil],
    [:personas, nil, "personas_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_persona_ownership_transfer_requests, nil, "client_persona_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_preferences, 21, nil, nil],
    [:client_privacy_requests, 21, nil, nil],
    [:client_processor_erasure_notifications, 21, nil, nil],
    [:client_profiles, nil, "client_profiles_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:client_retention_holds, 21, nil, nil],
    [:client_secret_credentials, 21, nil, nil],
    [:client_secret_issuances, 21, nil, nil],
    [:client_telephones, 21, nil, nil],
    [:client_totp_credentials, 21, nil, nil],
    [:client_withdrawal_ceremonies, 21, nil, nil],
    [:client_withdrawal_flows, 21, nil, nil],
    [:core_app_client_bridges, nil, "core_app_client_bridges_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:enterprises, nil, "enterprises_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:enterprise_ownership_transfer_requests, nil, "enterprise_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:enterprise_units, nil, "enterprise_units_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:persona_assignments, nil, "persona_assignments_public_id_max_length", "char_length(public_id::text) <= 25"],
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
