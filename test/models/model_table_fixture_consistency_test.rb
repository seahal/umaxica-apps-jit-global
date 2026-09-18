# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelTableFixtureConsistencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Concrete model renames that intentionally keep their existing physical tables.
  # Renaming these tables requires a separate data migration.
  RETAINED_TABLE_NAMES = {
    "ClientPersona" => "personas",
    "OperatorOrganization" => "organizations",
  }.freeze

  test "application record table names follow model tableize convention" do
    Rails.application.eager_load!

    mismatches =
      application_record_models.filter_map do |model|
        expected = RETAINED_TABLE_NAMES.fetch(model.name) { model.name.tableize }
        actual = model.table_name
        "#{model.name}: expected #{expected}, got #{actual}" unless expected == actual
      end

    assert_empty mismatches.sort, "Model/table naming mismatches remain:\n#{mismatches.sort.join("\n")}"
  end

  test "fixture file names map to active record table names" do
    Rails.application.eager_load!

    table_names = application_record_models.map(&:table_name).to_set
    fixture_names = Rails.root.glob("test/fixtures/*.yml").map { |path| path.basename(".yml").to_s }
    missing_tables = fixture_names.reject { |fixture_name| table_names.include?(fixture_name) }

    assert_empty missing_tables.sort,
                 "Fixture files without matching model tables remain:\n#{missing_tables.sort.join("\n")}"
  end

  private

  def application_record_models
    ApplicationRecord.descendants.reject do |model|
      model.abstract_class? || model.name.blank? || model.name.include?("::")
    end
  end
end
