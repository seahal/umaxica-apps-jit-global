# frozen_string_literal: true

class ValidateCascadeComZenithDependentDeletes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:visitor_processor_erasure_notifications, name: "fk_visitor_erasure_notifications_on_privacy_request_id")
    validate_foreign_key(:visitor_withdrawal_flow_events, name: "fk_visitor_withdrawal_flow_events_on_flow_id")
    validate_foreign_key(:visitor_withdrawal_ceremonies, name: "fk_visitor_withdrawal_ceremonies_on_visitor_id")
  end
end
