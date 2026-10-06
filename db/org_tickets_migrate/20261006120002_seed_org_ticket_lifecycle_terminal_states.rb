# frozen_string_literal: true

class SeedOrgTicketLifecycleTerminalStates < ActiveRecord::Migration[8.2]
  TERMINAL_TABLES = %w[
    operator_sign_in_flow_statuses
    operator_sign_up_flow_statuses
    operator_sign_out_flow_statuses
  ].freeze

  def up
    safety_assured do
      TERMINAL_TABLES.each do |table_name|
        execute <<~SQL.squish
          INSERT INTO #{table_name} (id)
          VALUES (910), (920), (930)
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "lifecycle terminal reference rows are migration-owned"
  end
end
