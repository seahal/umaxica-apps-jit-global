# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AppPreferencePolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    @record = AppPreference.new
    @policy = AppPreferencePolicy.new(@record, user: @user)
  end

  test "update? allows when record is AppPreference class" do
    policy = AppPreferencePolicy.new(AppPreference, user: @user)

    assert_predicate policy, :update?
  end

  test "update? allows when record is instance of AppPreference" do
    assert_predicate @policy, :update?
  end

  test "update? disallows for other record types" do
    policy = AppPreferencePolicy.new("not_a_preference", user: @user)

    assert_not policy.update?
  end
end
