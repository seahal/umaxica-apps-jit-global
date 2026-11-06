# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceResettableTest < ActiveSupport::TestCase
  test "require_reset_confirmation returns self" do
    preference = ComPreference.new
    result = preference.require_reset_confirmation("1")

    assert_same preference, result
    assert_equal "1", preference.confirm_reset
  end

  test "confirm_reset with '1' passes validation on :reset context" do
    preference = ComPreference.new(confirm_reset: "1")
    preference.valid?(:reset)

    assert_not preference.errors.of_kind?(:confirm_reset, :accepted)
  end

  test "confirm_reset with '0' fails validation on :reset context" do
    preference = ComPreference.new(confirm_reset: "0")
    preference.valid?(:reset)

    assert preference.errors.of_kind?(:confirm_reset, :accepted)
  end

  test "confirm_reset with blank fails validation on :reset context" do
    preference = ComPreference.new(confirm_reset: "")
    preference.valid?(:reset)

    assert preference.errors.of_kind?(:confirm_reset, :accepted)
  end

  test "unconfirmed preference fails validation on :reset context" do
    preference = ComPreference.new
    preference.valid?(:reset)

    assert preference.errors.of_kind?(:confirm_reset, :accepted)
  end

  test "confirm_reset validation does not run on default context" do
    preference = ComPreference.new
    preference.valid?

    assert_not preference.errors.of_kind?(:confirm_reset, :accepted)
  end
end
