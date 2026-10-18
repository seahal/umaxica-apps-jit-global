# frozen_string_literal: true
class RenameStaffReauthSessionsToStepUpSessions < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_index :staff_reauth_sessions,
                   :index_staff_reauth_sessions_on_staff_token_id,
                   :index_staff_step_up_sessions_on_staff_token_id
      rename_table :staff_reauth_sessions, :staff_step_up_sessions
    end
    remove_check_constraint :staff_step_up_sessions, name: :chk_staff_reauth_sessions_retention_order
    add_check_constraint :staff_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_staff_step_up_sessions_retention_order, validate: false
  end

  def down
    remove_check_constraint :staff_step_up_sessions, name: :chk_staff_step_up_sessions_retention_order
    add_check_constraint :staff_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_staff_reauth_sessions_retention_order, validate: false
    safety_assured do
      rename_index :staff_step_up_sessions,
                   :index_staff_step_up_sessions_on_staff_token_id,
                   :index_staff_reauth_sessions_on_staff_token_id
      rename_table :staff_step_up_sessions, :staff_reauth_sessions
    end
  end
end
