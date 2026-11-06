# frozen_string_literal: true

class AddPreferenceChangeActorCheckToClientContactAuditOutboxes < ActiveRecord::Migration[8.2]
  TABLE_NAME = :client_contact_audit_outboxes
  CHECK_NAME = "client_contact_audit_preference_change_actor"
  CHECK_EXPRESSION = <<~SQL.squish
    event_name <> 'preferences_changed' OR
    (contact_kind = 'email' AND actor_ref IS NOT NULL AND actor_ref <> '')
  SQL

  def change
    add_check_constraint(TABLE_NAME, CHECK_EXPRESSION, name: CHECK_NAME, validate: false)
  end
end
