# frozen_string_literal: true

class RestrictGroupAvatarMembershipRoleAndOwnerSurface < ActiveRecord::Migration[8.2]
  def up
    add_check_constraint(
      :group_avatar_memberships,
      "role = 'member'",
      name: "chk_group_avatar_memberships_role",
      validate: false,
    )
  end

  def down
    remove_check_constraint(:group_avatar_memberships, name: "chk_group_avatar_memberships_role")
    remove_check_constraint(:avatar_groups, name: "chk_avatar_groups_account_surface")
    add_check_constraint(
      :avatar_groups,
      "account_surface IN ('app', 'org', 'com')",
      name: "chk_avatar_groups_account_surface",
    )
  end
end
