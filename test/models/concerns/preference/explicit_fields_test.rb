# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceExplicitFieldsTest < ActiveSupport::TestCase
  class DummyPreference
    include PreferenceExplicitFields

    attr_accessor :explicit_fields

    def initialize(explicit_fields: [])
      @explicit_fields = explicit_fields
    end

    def update!(attrs)
      self.explicit_fields = attrs.fetch(:explicit_fields)
    end
  end

  test "explicit_field_names normalizes symbols and strings" do
    preference = DummyPreference.new(explicit_fields: [:language, "region", nil])

    assert_equal ["language", "region", ""], preference.explicit_field_names
  end

  test "missing explicit provenance cannot be inferred or updated" do
    preference = DummyPreference.new(explicit_fields: nil)

    assert_raises(NoMethodError) { preference.explicit_field_names }
    assert_raises(NoMethodError) { preference.mark_field_explicit!(:language) }
    assert_nil preference.explicit_fields
  end

  test "explicit_field? checks normalized field names" do
    preference = DummyPreference.new(explicit_fields: [:language])

    assert preference.explicit_field?(:language)
    assert_not preference.explicit_field?(:region)
  end

  test "mark_field_explicit! adds a field once" do
    preference = DummyPreference.new(explicit_fields: ["language"])

    preference.mark_field_explicit!(:region)
    preference.mark_field_explicit!("region")

    assert_equal ["language", "region"], preference.explicit_fields
  end

  test "mark_field_explicit! is a no-op when the field is already explicit" do
    preference = DummyPreference.new(explicit_fields: ["language"])

    preference.mark_field_explicit!("language")

    assert_equal ["language"], preference.explicit_fields
  end

  test "clear_explicit_fields! clears the explicit field list" do
    preference = DummyPreference.new(explicit_fields: ["language", "region"])

    preference.clear_explicit_fields!

    assert_equal [], preference.explicit_fields
  end

  test "clear_explicit_fields! is a no-op when there are no explicit fields" do
    preference = DummyPreference.new(explicit_fields: [])

    preference.clear_explicit_fields!

    assert_equal [], preference.explicit_fields
  end
end
