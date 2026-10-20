# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOrgSignal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:operator_notifications, name: "chk_operator_notifications_pid")
    validate_check_constraint(:operator_notification_records, name: "chk_operator_notification_records_pid")
  end
end
