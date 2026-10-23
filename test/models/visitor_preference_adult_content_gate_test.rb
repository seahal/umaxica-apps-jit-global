# typed: false
# frozen_string_literal: true

require "test_helper"

class VisitorPreferenceAdultContentGateTest < ActiveSupport::TestCase
  setup do
    VisitorPreferenceAdultContentGateOption.ensure_defaults!
  end

  test "set_option_id defaults to NOTHING when option_id is nil" do
    visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
    preference = VisitorPreference.create!(visitor: visitor)
    gate = VisitorPreferenceAdultContentGate.new(preference: preference, option_id: nil)

    gate.valid?

    assert_equal [], gate.errors.full_messages
    assert_equal VisitorPreferenceAdultContentGateOption::NOTHING, gate.option_id
  end
end
