# frozen_string_literal: true

class SeedClientStepUpReferenceRows < ActiveRecord::Migration[8.2]
  # State and delivery IDs are stable protocol storage values.
  # rubocop:disable Rails/SkipsModelValidations -- reference rows have no model behavior to validate.
  def up
    connection.insert(<<~SQL.squish)
      INSERT INTO client_step_up_context_states (id) VALUES (10), (20), (90), (91), (92)
    SQL
    connection.insert(<<~SQL.squish)
      INSERT INTO client_step_up_audit_outbox_delivery_states (id) VALUES (10), (20)
    SQL
  end

  def down
    connection.delete("DELETE FROM client_step_up_audit_outbox_delivery_states WHERE id IN (10, 20)")
    connection.delete("DELETE FROM client_step_up_context_states WHERE id IN (10, 20, 90, 91, 92)")
  end
  # rubocop:enable Rails/SkipsModelValidations
end
