# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_roles
# Database name: avatar
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AvatarRoleTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, AvatarRole::NOTHING
    assert_equal 2, AvatarRole::VIEWER
    assert_equal 3, AvatarRole::EDITOR
    assert_equal 4, AvatarRole::ADMIN
  end

  test "defaults are defined" do
    assert_equal [1, 2, 3, 4], AvatarRole::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal AvatarRole::NOTHING, AvatarRole.nothing_id
  end

  test "has many avatar_role_permissions" do
    assert_equal :has_many, AvatarRole.reflect_on_association(:avatar_role_permissions).macro
  end

  test "has many avatar_permissions through avatar_role_permissions" do
    assert_equal :has_many, AvatarRole.reflect_on_association(:avatar_permissions).macro
  end

  test "has many avatar_memberships" do
    assert_equal :has_many, AvatarRole.reflect_on_association(:avatar_memberships).macro
  end
end
