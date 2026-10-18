# frozen_string_literal: true

class ValidateGroupAvatarMembershipRoleAndOwnerSurface < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:group_avatar_memberships, name: "chk_group_avatar_memberships_role")
  end

  def down
    # PostgreSQL constraints cannot be returned to NOT VALID after validation.
  end
end
