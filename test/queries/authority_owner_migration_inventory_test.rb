# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerMigrationInventoryTest < ActiveSupport::TestCase
  test "covers each concrete resource and never treats a legacy binding as an owner" do
    configurations = AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS

    assert_equal %w(agent bureau client_persona company enterprise individual),
                 configurations.map { |configuration| configuration.fetch(:resource_kind).to_s }.sort
    assert_equal %w(app app com com org org),
                 configurations.map { |configuration| configuration.fetch(:surface).to_s }.sort

    configurations.each do |configuration|
      assert_predicate configuration.fetch(:resource_class).name, :present?
      assert_predicate configuration.fetch(:principal_class).name, :present?
      assert_not configuration.fetch(:auto_backfill)
      assert_equal :manual_review, configuration.fetch(:recommended_action)
    end
  end

  test "authority table state is explicit rather than silently treated as ready" do
    expected = %i(not_applied applied)

    assert_equal expected, AuthorityOwnerMigrationInventory::AUTHORITY_SCHEMA_STATES
    assert_raises(KeyError) do
      AuthorityOwnerMigrationInventory::AUTHORITY_TABLES.fetch(:unknown_surface)
    end
  end
end
