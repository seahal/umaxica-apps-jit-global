# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_binding_methods
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceBindingMethodTest < ActiveSupport::TestCase
  def setup
    Prosopite.pause do
      AppPreferenceBindingMethod::DEFAULTS.each do |id|
        AppPreferenceBindingMethod.find_or_create_by!(id: id)
      end
    end
  end

  test "NOTHING constant is defined" do
    assert_equal 0, AppPreferenceBindingMethod::NOTHING
  end

  test "DBSC constant is defined" do
    assert_equal 1, AppPreferenceBindingMethod::DBSC
  end

  test "LEGACY constant is defined" do
    assert_equal 2, AppPreferenceBindingMethod::LEGACY
  end

  test "DEFAULTS constant contains all methods" do
    expected = [0, 1, 2]

    assert_equal expected, AppPreferenceBindingMethod::DEFAULTS
  end

  test "has_many app_preferences association" do
    assert_respond_to AppPreferenceBindingMethod.new, :app_preferences
  end

  test "ensure_defaults! creates missing binding method records" do
    called = false

    AppPreferenceBindingMethod.stub(
      :insert_missing_fixed_ids!, ->(ids) do
                                    called = true

                                    assert_equal AppPreferenceBindingMethod::DEFAULTS, ids
                                  end,
    ) do
      AppPreferenceBindingMethod.ensure_defaults!
    end

    assert called
  end

  test "ensure_defaults! skips existing records" do
    assert_no_difference("AppPreferenceBindingMethod.count") do
      AppPreferenceBindingMethod.ensure_defaults!
    end
  end

  test "app_preferences association works with dependent restrict" do
    method = AppPreferenceBindingMethod.find(AppPreferenceBindingMethod::NOTHING)
    preference = AppPreference.create!(
      binding_method_id: method.id,
      status_id: AppPreferenceStatus::NOTHING,
    )

    assert_includes method.app_preferences, preference

    # Test restrict_with_error
    assert_not method.destroy
    assert_predicate method.errors[:base], :present?
  end

  test "foreign_key is binding_method_id" do
    assert_equal "binding_method_id", AppPreferenceBindingMethod.reflect_on_association(:app_preferences).foreign_key
  end
end
