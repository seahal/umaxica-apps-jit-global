# frozen_string_literal: true

# D-90: the ORG halt audit writes OperatorChronicleEvent::SIGN_FLOW_HALTED (18); the fixed reference
# row must exist in every database built from migrations.
class SeedSignFlowHaltedChronicleEvent < ActiveRecord::Migration[8.2]
  def up
    # Fixed reference IDs have no application validation and must exist before requests run.
    # rubocop:disable Rails/SkipsModelValidations
    connection.insert("INSERT INTO operator_chronicle_events (id) VALUES (18) ON CONFLICT (id) DO NOTHING")
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    # Audit rows may reference the fixed ID after rollback.
  end
end
