# frozen_string_literal: true

class ValidateNanoidPublicIdLengthAppSignal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:client_notification_records, name: "chk_client_notification_records_pid")
    validate_check_constraint(:member_notifications, name: "chk_member_notifications_pid")
  end
end
