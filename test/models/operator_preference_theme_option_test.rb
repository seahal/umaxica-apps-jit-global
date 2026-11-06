# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_theme_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceThemeOptionTest < ActiveSupport::TestCase
  test "returns light for LIGHT id" do
    option = OperatorPreferenceThemeOption.new(id: OperatorPreferenceThemeOption::LIGHT)

    assert_equal "light", option.name
  end

  test "returns dark for DARK id" do
    option = OperatorPreferenceThemeOption.new(id: OperatorPreferenceThemeOption::DARK)

    assert_equal "dark", option.name
  end

  test "returns system for SYSTEM id" do
    option = OperatorPreferenceThemeOption.new(id: OperatorPreferenceThemeOption::SYSTEM)

    assert_equal "system", option.name
  end

  test "returns nil for NOTHING id" do
    option = OperatorPreferenceThemeOption.new(id: OperatorPreferenceThemeOption::NOTHING)

    assert_nil option.name
  end

  test "returns nil for unknown id" do
    option = OperatorPreferenceThemeOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      OperatorPreferenceTheme.where(option_id: OperatorPreferenceThemeOption::DEFAULTS).delete_all
      OperatorPreferenceThemeOption.where(id: OperatorPreferenceThemeOption::DEFAULTS).destroy_all
    end

    OperatorPreferenceThemeOption.ensure_defaults!

    assert OperatorPreferenceThemeOption.exists?(id: OperatorPreferenceThemeOption::NOTHING)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    OperatorPreferenceThemeOption.ensure_defaults!
    initial_count = OperatorPreferenceThemeOption.count

    OperatorPreferenceThemeOption.ensure_defaults!

    assert_equal initial_count, OperatorPreferenceThemeOption.count
  end

  test "DEFAULTS contains all expected values" do
    assert_equal [0, 1, 2, 3], OperatorPreferenceThemeOption::DEFAULTS
  end

  test "has_many association exists" do
    option = OperatorPreferenceThemeOption.new(id: 1)

    assert_respond_to option, :operator_preference_themes
  end
end
