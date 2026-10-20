# frozen_string_literal: true

class CascadeComZenithDependentDeletes < ActiveRecord::Migration[8.2]
  # [table, referenced table, column, constraint, replaced constraint]; the parent model already declares
  # dependent: :delete_all, so the database deletes the same children instead of blocking the parent.
  FOREIGN_KEYS = [
    [:visitor_processor_erasure_notifications, :visitor_privacy_requests, :visitor_privacy_request_id, "fk_visitor_erasure_notifications_on_privacy_request_id", "fk_rails_4944a6f18c"],
    [:visitor_withdrawal_flow_events, :visitor_withdrawal_flows, :visitor_withdrawal_flow_id, "fk_visitor_withdrawal_flow_events_on_flow_id", "fk_rails_606617dd12"],
    [:visitor_withdrawal_ceremonies, :visitors, :visitor_id, "fk_visitor_withdrawal_ceremonies_on_visitor_id", "fk_rails_5cdc4d0fad"],
  ].freeze

  def change
    FOREIGN_KEYS.each do |table, to_table, column, name, replaced|
      add_foreign_key(table, to_table, column:, name:, on_delete: :cascade, validate: false)
      remove_foreign_key(table, to_table, column:, name: replaced)
    end
  end
end
