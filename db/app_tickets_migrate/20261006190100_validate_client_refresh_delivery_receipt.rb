# frozen_string_literal: true

class ValidateClientRefreshDeliveryReceipt < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint :client_rp_sessions, name: "chk_client_rp_sessions_refresh_delivery_all_or_none"
  end
end
