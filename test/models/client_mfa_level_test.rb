# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_mfa_levels
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientMfaLevelTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, ClientMfaLevel::NOTHING
    assert_equal 1, ClientMfaLevel::WEAK
    assert_equal 5, ClientMfaLevel::MEDIUM
    assert_equal 9, ClientMfaLevel::FULL
  end

  test "defaults are defined" do
    assert_equal [0, 1, 5, 9], ClientMfaLevel::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal ClientMfaLevel::NOTHING, ClientMfaLevel.nothing_id
  end

  test "has many users" do
    assert_equal :has_many, ClientMfaLevel.reflect_on_association(:users).macro
  end
end
