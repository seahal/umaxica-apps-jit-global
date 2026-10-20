# frozen_string_literal: true

class CascadeAppZenithDependentDeletes < ActiveRecord::Migration[8.2]
  # [table, referenced table, column, constraint, replaced constraint]; the parent model already declares
  # dependent: :delete_all, so the database deletes the same children instead of blocking the parent.
  FOREIGN_KEYS = [
    [:client_processor_erasure_notifications, :client_privacy_requests, :client_privacy_request_id, "fk_client_erasure_notifications_on_privacy_request_id", "fk_rails_41d98680b9"],
    [:client_withdrawal_flow_events, :client_withdrawal_flows, :client_withdrawal_flow_id, "fk_client_withdrawal_flow_events_on_flow_id", "fk_rails_b55e5a56c4"],
    [:client_withdrawal_ceremonies, :clients, :client_id, "fk_client_withdrawal_ceremonies_on_client_id", "fk_rails_9386315187"],
  ].freeze

  def change
    FOREIGN_KEYS.each do |table, to_table, column, name, replaced|
      add_foreign_key(table, to_table, column:, name:, on_delete: :cascade, validate: false)
      remove_foreign_key(table, to_table, column:, name: replaced)
    end
  end
end
