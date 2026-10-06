# frozen_string_literal: true

class ValidateOperatorRefreshDeliveryReceipt < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint :operator_rp_sessions, name: "chk_operator_rp_sessions_refresh_delivery_all_or_none"
  end
end
