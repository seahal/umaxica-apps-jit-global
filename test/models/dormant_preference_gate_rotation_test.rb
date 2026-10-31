# typed: false
# frozen_string_literal: true

require "test_helper"

class DormantPreferenceGateRotationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "adult content gate tables remain model owned and outside active preference registries" do
    associations = {
      AppPreference => :app_preference_adult_content_gate,
      OrgPreference => :org_preference_adult_content_gate,
      ClientPreference => :client_preference_adult_content_gate,
      OperatorPreference => :operator_preference_adult_content_gate,
    }

    associations.each do |preference_class, association_name|
      assert preference_class.reflect_on_association(association_name)
      assert_respond_to preference_class, :table_name
    end

    assert_not_includes PreferenceClassRegistry::CHILD_RECORD_TYPES, :adult_content_gate
    assert_not PreferenceClassRegistry::TYPE_KEY_MAP.key?(:adult_content_gate)
  end
end
