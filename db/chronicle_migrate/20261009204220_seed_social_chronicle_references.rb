# frozen_string_literal: true

class SeedSocialChronicleReferences < ActiveRecord::Migration[8.2]
  def up
    # Fixed reference IDs have no application validation and must be present before requests run.
    # rubocop:disable Rails/SkipsModelValidations
    connection.insert("INSERT INTO client_chronicle_events (id) VALUES (27), (30) ON CONFLICT (id) DO NOTHING")
    connection.insert("INSERT INTO client_chronicle_levels (id) VALUES (4) ON CONFLICT (id) DO NOTHING")
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    # Historical audit records can still reference these fixed IDs after rollback.
  end
end
