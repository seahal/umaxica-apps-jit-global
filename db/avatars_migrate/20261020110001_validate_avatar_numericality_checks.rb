# frozen_string_literal: true

class ValidateAvatarNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:group_avatar_memberships, name: "chk_group_avatar_memberships_position")
  end
end
