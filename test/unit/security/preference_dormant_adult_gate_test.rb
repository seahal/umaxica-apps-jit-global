# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceDormantAdultGateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the adult content gate is absent from every preference registry" do
    assert_not_includes PreferenceClassRegistry::CHILD_RECORD_TYPES, :adult_content_gate
    assert_not_includes ActorPreferenceExplicitDisplay::ALLOWED_FIELDS, "adult_content_gate"

    %w(App Com Org Client Operator).each do |prefix|
      assert_raises(KeyError) { PreferenceClassRegistry.option_class(prefix, :adult_content_gate) }
      assert_raises(KeyError) { PreferenceClassRegistry.record_class(prefix, :adult_content_gate) }
    end
  end

  test "non-model application code does not read or write the dormant gate" do
    roots = %w(controllers services values policies helpers javascript)
    offenders =
      roots.flat_map do |root|
        Rails.root.glob("app/#{root}/**/*.{rb,erb,js,jsx,ts,tsx}").select do |path|
          path.read.match?(/adult_content_gate|AdultContentGate|r18_display_stopper/)
        end
      end

    assert_empty offenders, "dormant gate referenced outside models: #{offenders.join(", ")}"
  end
end
