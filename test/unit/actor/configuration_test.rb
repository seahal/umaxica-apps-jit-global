# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Actor::ConfigurationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "bracket access uses fetch to access values" do
    config = Actor::Configuration.new(foo: "bar", baz: 42)

    assert_equal "bar", config[:foo]
    assert_equal 42, config[:baz]
    assert_equal Actor::Configuration::NULL_VALUE, config[:missing]
  end

  test "respond_to_missing returns true for any method" do
    config = Actor::Configuration.new(foo: "bar")

    assert_respond_to config, :foo
    assert_respond_to config, :anything
    assert_respond_to config, :some_random_method
  end

  test "hash consistency with equality" do
    config1 = Actor::Configuration.new(foo: "bar", baz: 42)
    config2 = Actor::Configuration.new(foo: "bar", baz: 42)
    config3 = Actor::Configuration.new(foo: "different")

    assert_equal config1, config2
    assert_equal config1.hash, config2.hash
    assert_not_equal config1, config3
    assert_not_equal config1.hash, config3.hash
  end

  test "null value responds to any message" do
    null = Actor::Configuration::NullValue.new

    assert_respond_to null, :anything
    assert_respond_to null, :some_method
    assert_respond_to null, :bogus
  end

  test "null value responds to all predicates" do
    null = Actor::Configuration::NULL_VALUE

    assert_withheld { null.nil? }
    assert_predicate null, :blank?
    assert_not_predicate null, :present?
    assert_predicate null, :null?
    assert_not null.enabled?
    assert_predicate null, :disabled?
    assert_empty null.to_a
    assert_empty null.to_h
    assert_equal "", null.to_s
    assert_equal null, Actor::Configuration::NULL_VALUE
  end

  test "NULL is the empty configuration" do
    assert_predicate Actor::Configuration::NULL, :null?
  end

  test "initialize freezes the configuration" do
    config = Actor::Configuration.new(foo: "bar")

    assert_predicate config, :frozen?
  end

  test "fetch returns a stored value" do
    config = Actor::Configuration.new(foo: "bar")

    assert_equal "bar", config.fetch(:foo)
  end

  test "fetch accepts string keys" do
    config = Actor::Configuration.new(foo: "bar")

    assert_equal "bar", config.fetch("foo")
  end

  test "method_missing returns values for configured keys" do
    config = Actor::Configuration.new(foo: "bar")

    assert_equal "bar", config.foo
  end

  test "method_missing returns NULL_VALUE for unknown keys" do
    config = Actor::Configuration.new

    assert_equal Actor::Configuration::NULL_VALUE, config.unknown
  end

  test "with merges new values into a new configuration" do
    config = Actor::Configuration.new(foo: "bar")
    updated = config.with(foo: "baz", qux: "quux")

    assert_equal "baz", updated.foo
    assert_equal "quux", updated.qux
    assert_equal "bar", config.foo
  end

  test "null? returns true for empty configuration" do
    config = Actor::Configuration.new

    assert_predicate config, :null?
  end

  test "null? returns false for non-empty configuration" do
    config = Actor::Configuration.new(foo: "bar")

    assert_not_predicate config, :null?
  end

  test "to_h returns the internal values" do
    config = Actor::Configuration.new(foo: "bar")

    assert_equal({ foo: "bar" }, config.to_h)
  end

  test "NULL_VALUE chains unknown methods to itself" do
    null = Actor::Configuration::NULL_VALUE

    assert_equal null, null.anything
  end
end
