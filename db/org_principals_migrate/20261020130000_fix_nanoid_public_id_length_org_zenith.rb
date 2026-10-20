# frozen_string_literal: true

class FixNanoidPublicIdLengthOrgZenith < ActiveRecord::Migration[8.2]
  # adr/identifier-contract.md: NanoID public_id is varchar(21) with an exact-length CHECK.
  # [table, previous varchar limit (nil = unbounded), replaced capacity check name, its expression]
  TABLES = [
    [:agents, nil, "agents_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:agent_assignments, nil, "agent_assignments_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:agent_ownership_transfer_requests, nil, "agent_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:bureaus, nil, "bureaus_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:bureau_ownership_transfer_requests, nil, "bureau_ownership_transfer_requests_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:bureau_units, nil, "bureau_units_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:core_org_operator_bridges, nil, "core_org_operator_bridges_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:operator_accounts, nil, "operator_accounts_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:operator_bulletins, 21, nil, nil],
    [:operator_capability_grants, 21, nil, nil],
    [:operator_emails, 21, nil, nil],
    [:operator_entra_identities, 21, nil, nil],
    [:operator_identities, nil, "operator_identities_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:operator_lifecycle_requests, 21, nil, nil],
    [:operator_preferences, 21, nil, nil],
    [:operator_secret_credentials, 21, nil, nil],
    [:operator_telephones, 25, nil, nil],
    [:operator_workspace_accounts, nil, "operator_workspace_accounts_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:org_enforcement_appeals, nil, "org_enforcement_appeals_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:organization_entra_connections, 21, nil, nil],
  ].freeze

  def up
    TABLES.each do |table, previous_limit, capacity_check, _expression|
      remove_check_constraint(table, name: capacity_check) if capacity_check
      # Narrowing the type is reviewed here: every stored value is a 21-character NanoID.
      unless previous_limit == 21
        with_public_id_triggers_recreated(table) do
          safety_assured { change_column(table, :public_id, :string, limit: 21) }
        end
      end
      add_check_constraint(table, "char_length(public_id) = 21", name: "chk_#{table}_pid", validate: false)
    end
  end

  def down
    TABLES.reverse_each do |table, previous_limit, capacity_check, expression|
      remove_check_constraint(table, name: "chk_#{table}_pid")
      unless previous_limit == 21
        with_public_id_triggers_recreated(table) do
          safety_assured { change_column(table, :public_id, :string, limit: previous_limit) }
        end
      end
      add_check_constraint(table, expression, name: capacity_check) if capacity_check
    end
  end

  private

  # PostgreSQL cannot change the type of a column named in a trigger definition (the public_id
  # immutability triggers use UPDATE OF public_id). Each trigger is recreated from its own definition.
  def with_public_id_triggers_recreated(table)
    definitions = select_rows(<<~SQL.squish)
      SELECT t.tgname, pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
      WHERE c.relname = #{quote(table.to_s)} AND NOT t.tgisinternal AND pg_get_triggerdef(t.oid) LIKE '%public_id%'
    SQL
    safety_assured do
      definitions.each { |name, _| execute("DROP TRIGGER #{quote_column_name(name)} ON #{quote_table_name(table)}") }
      yield
      definitions.each { |_, definition| execute(definition) }
    end
  end
end
