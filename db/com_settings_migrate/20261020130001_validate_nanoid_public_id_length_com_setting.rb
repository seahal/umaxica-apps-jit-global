# frozen_string_literal: true

class ValidateNanoidPublicIdLengthComSetting < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:com_preferences, name: "chk_com_preferences_pid")
  end
end
