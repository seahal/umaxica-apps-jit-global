# frozen_string_literal: true

class AddPreferencesChangedToClientContactAuditEvents < ActiveRecord::Migration[8.2]
  TABLE_NAME = :client_contact_audit_outboxes
  EVENT_CHECK = "client_contact_audit_event"

  def up
    remove_check_constraint(TABLE_NAME, name: EVENT_CHECK)
    add_check_constraint(
      TABLE_NAME,
      "event_name IN ('finalized', 'released', 'preferences_changed')",
      name: EVENT_CHECK,
      validate: false,
    )
  end

  def down
    preference_event_exists = connection.select_value(<<~SQL.squish).present?
      SELECT 1
      FROM client_contact_audit_outboxes
      WHERE event_name = 'preferences_changed'
      LIMIT 1
    SQL
    if preference_event_exists
      raise ActiveRecord::IrreversibleMigration,
            "preferences_changed audit records must be retained before removing their event type"
    end

    remove_check_constraint(TABLE_NAME, name: EVENT_CHECK)
    add_check_constraint(TABLE_NAME, "event_name IN ('finalized', 'released')", name: EVENT_CHECK)
  end
end
