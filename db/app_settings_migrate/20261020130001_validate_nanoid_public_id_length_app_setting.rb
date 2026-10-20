# frozen_string_literal: true

class ValidateNanoidPublicIdLengthAppSetting < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:app_preferences, name: "chk_app_preferences_pid")
  end
end
