# typed: false
# frozen_string_literal: true

require "test_helper"

# FIXME: Move these per-model checks into each model's own test (test/models/<model>_test.rb)
# through a shared assertion in test/support/, and keep this file only as a guard that every model
# calls it, as test/models/public_id_fixed_length_contract_test.rb does for public_id.
# Unique indexes that include the primary key exist as composite foreign key targets or catalog
# guards. Each has a matching uniqueness validation, so a record created with an explicit id that
# is already taken in that scope fails validation instead of reaching the database index.
class PrimaryKeyUniqueIndexValidationContractTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app").to_s

  Rails.application.eager_load!

  def self.primary_key_unique_indexes
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .sort_by(&:name)
      .flat_map do |model|
        model.with_connection { |connection| connection.indexes(model.table_name) }
          .select { |index| index.unique && index.where.nil? && index.columns.is_a?(Array) }
          .select { |index| index.columns.include?(model.primary_key.to_s) }
          .map { |index| [model, index.name, index.columns.sort] }
      end
  end

  def uniqueness_scopes(model)
    model.validators.select { |validator| validator.kind == :uniqueness }.flat_map do |validator|
      scope = Array(validator.options[:scope]).map(&:to_s)
      validator.attributes.map { |attribute| ([attribute.to_s] + scope).sort }
    end
  end

  primary_key_unique_indexes.group_by(&:first).each do |model, indexes|
    test "#{model.name} primary-key unique indexes have uniqueness validations" do
      scopes = uniqueness_scopes(model)

      indexes.each do |_model, name, columns|
        assert_includes scopes, columns, "#{model.name} needs a uniqueness validation matching #{name}"
      end
    end
  end
end
