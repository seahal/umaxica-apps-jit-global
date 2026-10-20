# frozen_string_literal: true

class ValidateNanoidPublicIdLengthOrgSetting < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:org_preferences, name: "chk_org_preferences_pid")
  end
end
