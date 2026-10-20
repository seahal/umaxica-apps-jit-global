# typed: false
# frozen_string_literal: true

require "test_helper"

# FIXME: Move these per-model checks into each model's own test (test/models/<model>_test.rb)
# through a shared assertion in test/support/, and keep this file only as a guard that every model
# calls it, as test/models/public_id_fixed_length_contract_test.rb does for public_id.
# A model numericality minimum must also hold for rows written without model validation, so each
# greater_than_or_equal_to validator has a database CHECK constraint stating the same minimum.
class NumericalityCheckConstraintContractTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app").to_s

  Rails.application.eager_load!

  def self.ranged_columns
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .sort_by(&:name)
      .flat_map { |model| minimums_of(model).map { |attribute, minimum| [model, attribute, minimum] } }
  end

  def self.minimums_of(model)
    model.validators.each_with_object([]) do |validator, minimums|
      minimum = validator.options[:greater_than_or_equal_to]
      next unless validator.kind == :numericality && minimum.is_a?(Integer)

      validator.attributes.each do |attribute|
        minimums << [attribute.to_s, minimum] if model.columns_hash.key?(attribute.to_s)
      end
    end
  end

  def check_expressions(model)
    model.with_connection { |connection| connection.check_constraints(model.table_name).map(&:expression) }
  end

  ranged_columns.group_by(&:first).each do |model, columns|
    test "#{model.name} numericality minimums are database CHECK constraints" do
      expressions = check_expressions(model)
      columns.each do |_model, attribute, minimum|
        bound = /(?<![\w"])"?#{Regexp.escape(attribute)}"?\s*>=\s*#{minimum}(?!\d)/

        assert expressions.any? { |expression| expression.match?(bound) },
               "#{model.name}##{attribute} must have CHECK (#{attribute} >= #{minimum})"
      end
    end
  end
end
