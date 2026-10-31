# frozen_string_literal: true

class SeedAppSignFlowReferenceData < ActiveRecord::Migration[8.2]
  REFERENCE_ROWS = {
    client_sign_in_flow_states: [10, 20, 30, 40, 50, 60, 65, 70, 80, 100, 900, 910, 920, 930],
    client_sign_up_flow_statuses: [10, 20, 30, 35, 36, 38, 40, 60, 70, 80, 100, 900, 910, 920, 930],
    client_sign_up_flow_cleanup_statuses: [0, 10, 20, 30, 40],
    client_sign_out_flow_statuses: [0, 10, 20, 30, 40, 100, 900, 910, 920, 930],
    client_sign_out_flow_kinds: [0, 10, 20, 30],
  }.freeze

  def up
    safety_assured do
      self.class.seed_into(connection)
    end
  end

  def self.seed_into(connection, tables: REFERENCE_ROWS.keys)
    tables.each do |table|
      ids = REFERENCE_ROWS.fetch(table)
      ids.each do |id|
        connection.execute("INSERT INTO #{table} (id) VALUES (#{id}) ON CONFLICT (id) DO NOTHING")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "sign-flow reference data is migration-owned"
  end
end
