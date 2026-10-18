# frozen_string_literal: true
class RenameUserReauthSessionsToStepUpSessions < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_index :user_reauth_sessions,
                   :index_user_reauth_sessions_on_user_token_id,
                   :index_user_step_up_sessions_on_user_token_id
      rename_table :user_reauth_sessions, :user_step_up_sessions
    end
    remove_check_constraint :user_step_up_sessions, name: :chk_user_reauth_sessions_retention_order
    add_check_constraint :user_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_user_step_up_sessions_retention_order, validate: false
  end

  def down
    remove_check_constraint :user_step_up_sessions, name: :chk_user_step_up_sessions_retention_order
    add_check_constraint :user_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_user_reauth_sessions_retention_order, validate: false
    safety_assured do
      rename_index :user_step_up_sessions,
                   :index_user_step_up_sessions_on_user_token_id,
                   :index_user_reauth_sessions_on_user_token_id
      rename_table :user_step_up_sessions, :user_reauth_sessions
    end
  end
end
