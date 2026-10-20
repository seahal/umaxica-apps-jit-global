# frozen_string_literal: true

class ValidateNanoidPublicIdLengthComSignal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:visitor_notification_records, name: "chk_visitor_notification_records_pid")
  end
end
