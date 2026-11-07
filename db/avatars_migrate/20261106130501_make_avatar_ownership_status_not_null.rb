# frozen_string_literal: true

class MakeAvatarOwnershipStatusNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :avatar_ownership_periods
  COLUMN = :avatar_ownership_status_id
  CHECK_NAME = "chk_avatar_ownership_periods_status_id_nn"

  def up
    if select_value("SELECT EXISTS (SELECT 1 FROM #{TABLE} WHERE #{COLUMN} IS NULL)")
      raise ActiveRecord::MigrationError,
            "Cannot make avatar_ownership_periods.avatar_ownership_status_id NOT NULL: NULL rows exist"
    end

    validate_check_constraint(TABLE, name: CHECK_NAME)
    change_column_null(TABLE, COLUMN, false)
    remove_check_constraint(TABLE, name: CHECK_NAME)
  end

  def down
    add_check_constraint(TABLE, "#{COLUMN} IS NOT NULL", name: CHECK_NAME, validate: false)
    change_column_null(TABLE, COLUMN, true)
  end
end
