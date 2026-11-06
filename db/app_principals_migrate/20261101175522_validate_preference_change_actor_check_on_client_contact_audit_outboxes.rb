# frozen_string_literal: true

class ValidatePreferenceChangeActorCheckOnClientContactAuditOutboxes < ActiveRecord::Migration[8.2]
  TABLE_NAME = :client_contact_audit_outboxes
  CHECK_NAME = "client_contact_audit_preference_change_actor"
  CHECK_EXPRESSION = <<~SQL.squish
    event_name <> 'preferences_changed' OR
    (contact_kind = 'email' AND actor_ref IS NOT NULL AND actor_ref <> '')
  SQL

  def up
    validate_check_constraint(TABLE_NAME, name: CHECK_NAME)
  end

  def down
    remove_check_constraint(TABLE_NAME, name: CHECK_NAME)
    add_check_constraint(TABLE_NAME, CHECK_EXPRESSION, name: CHECK_NAME, validate: false)
  end
end
