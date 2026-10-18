# frozen_string_literal: true
class RenameVisitorReauthSessionsToStepUpSessions < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_index :visitor_reauth_sessions,
                   :index_visitor_reauth_sessions_on_visitor_token_id,
                   :index_visitor_step_up_sessions_on_visitor_token_id
      rename_table :visitor_reauth_sessions, :visitor_step_up_sessions
    end
    remove_check_constraint :visitor_step_up_sessions, name: :chk_customer_reauth_sessions_retention_order
    add_check_constraint :visitor_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_visitor_step_up_sessions_retention_order, validate: false
  end

  def down
    remove_check_constraint :visitor_step_up_sessions, name: :chk_visitor_step_up_sessions_retention_order
    add_check_constraint :visitor_step_up_sessions,
                         "discarded_at <= purged_at",
                         name: :chk_customer_reauth_sessions_retention_order, validate: false
    safety_assured do
      rename_index :visitor_step_up_sessions,
                   :index_visitor_step_up_sessions_on_visitor_token_id,
                   :index_visitor_reauth_sessions_on_visitor_token_id
      rename_table :visitor_step_up_sessions, :visitor_reauth_sessions
    end
  end
end
