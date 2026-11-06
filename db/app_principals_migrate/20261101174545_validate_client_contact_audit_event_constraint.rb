# frozen_string_literal: true

class ValidateClientContactAuditEventConstraint < ActiveRecord::Migration[8.2]
  TABLE_NAME = :client_contact_audit_outboxes
  EVENT_CHECK = "client_contact_audit_event"
  EVENT_CHECK_EXPRESSION = "event_name IN ('finalized', 'released', 'preferences_changed')"

  def up
    validate_check_constraint(TABLE_NAME, name: EVENT_CHECK)
  end

  def down
    remove_check_constraint(TABLE_NAME, name: EVENT_CHECK)
    add_check_constraint(TABLE_NAME, EVENT_CHECK_EXPRESSION, name: EVENT_CHECK, validate: false)
  end
end
