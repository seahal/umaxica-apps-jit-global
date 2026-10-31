# frozen_string_literal: true

class ConstrainComPreferenceStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_check_constraint(:com_preference_statuses, "id IN (1, 2)", name: "chk_com_preference_statuses_id", validate: false)
    validate_check_constraint(:com_preference_statuses, name: "chk_com_preference_statuses_id")
  end

  def down
    remove_check_constraint(:com_preference_statuses, name: "chk_com_preference_statuses_id")
  end
end
