# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceExplicitModelRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PREFIXES = %w(App Com Org Client Operator).freeze
  TYPES = %i(currency date_format time_format motion density page_size).freeze

  test "extended preference records and options are explicit model files" do
    PREFIXES.each do |prefix|
      TYPES.each do |type|
        record_class = PreferenceClassRegistry.record_class(prefix, type)
        option_class = PreferenceClassRegistry.option_class(prefix, type)

        assert_match %r{/app/models/}, record_class.instance_method(:set_option_id).source_location.first
        assert_match %r{/app/models/}, option_class.instance_method(:name).source_location.first
      end
    end
  end

  test "extended preference records are dependent destroy children" do
    PREFIXES.each do |prefix|
      parent_class = PreferenceClassRegistry.fetch(prefix).fetch(:preference)

      TYPES.each do |type|
        association = parent_class.reflect_on_association(:"#{prefix.underscore}_preference_#{type}")

        assert association, "#{parent_class.name} missing #{type} association"
        assert_equal :destroy, association.options[:dependent]
      end
    end
  end
end
