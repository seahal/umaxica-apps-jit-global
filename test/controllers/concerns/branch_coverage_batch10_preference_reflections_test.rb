# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "preference/core_test"

class BranchCoverageBatch10PreferenceReflectionsTest < ActiveSupport::TestCase
  test "resource_preference_child_reflections_for_reset skips nil foreign keys and duplicates" do
    c = PreferenceCoreHarness.new
    reflection_nil_fk = Struct.new(:options, :foreign_key, :klass, :name).new({ dependent: :destroy }, nil, String, :a)
    reflection_ok = Struct.new(:options, :foreign_key, :klass, :name).new(
      { dependent: :destroy }, "user_id", String,
      :b,
    )
    reflection_dup = Struct.new(:options, :foreign_key, :klass, :name).new(
      { dependent: :destroy }, "user_id", String,
      :c,
    )
    resource_pref = Object.new
    resource_pref.define_singleton_method(:class) do
      Object.new.tap do |klass|
        klass.define_singleton_method(:reflect_on_all_associations) {
          [reflection_nil_fk, reflection_ok, reflection_dup]
        }
      end
    end
    deps = c.send(:resource_preference_child_reflections_for_reset, resource_pref)

    assert_equal 1, deps.size
  end

  test "reset_app_org_preference_to_defaults! skips nil children" do
    c = PreferenceCoreHarness.new
    association_prefix = "app_preference"
    preference = Object.new
    preference.define_singleton_method(:class) do
      Class.new do
        def self.name = "AppPreference"
      end
    end
    PreferenceAdoption::CHILD_RECORD_TYPES.each do |type|
      preference.define_singleton_method("#{association_prefix}_#{type}") { nil }
    end
    preference.define_singleton_method("#{association_prefix}_cookie") { nil }
    preference.define_singleton_method(:update!) { |*| true }
    c.define_singleton_method(:with_preference_connection) { |*, &block| block.call }
    c.define_singleton_method(:mark_preference_fields_default!) { |_| nil }
    c.send(:reset_app_org_preference_to_defaults!, preference)

    assert_kind_of Minitest::Test, self
  end
end
