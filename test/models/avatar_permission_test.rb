# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_permissions
# Database name: avatar
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AvatarPermissionTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, AvatarPermission::NOTHING
    assert_equal 2, AvatarPermission::READ
    assert_equal 3, AvatarPermission::WRITE
    assert_equal 4, AvatarPermission::ADMIN
  end

  test "defaults are defined" do
    assert_equal [1, 2, 3, 4], AvatarPermission::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal AvatarPermission::NOTHING, AvatarPermission.nothing_id
  end

  test "has many avatar_role_permissions" do
    assert_equal :has_many, AvatarPermission.reflect_on_association(:avatar_role_permissions).macro
  end

  test "has many avatar_roles through avatar_role_permissions" do
    assert_equal :has_many, AvatarPermission.reflect_on_association(:avatar_roles).macro
  end
end
