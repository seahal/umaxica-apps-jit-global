# frozen_string_literal: true

class ValidateCascadeAppZenithDependentDeletes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:client_processor_erasure_notifications, name: "fk_client_erasure_notifications_on_privacy_request_id")
    validate_foreign_key(:client_withdrawal_flow_events, name: "fk_client_withdrawal_flow_events_on_flow_id")
    validate_foreign_key(:client_withdrawal_ceremonies, name: "fk_client_withdrawal_ceremonies_on_client_id")
  end
end
