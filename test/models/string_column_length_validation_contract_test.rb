# typed: false
# frozen_string_literal: true

require "test_helper"

# FIXME: Move these per-model checks into each model's own test (test/models/<model>_test.rb)
# through a shared assertion in test/support/, and keep this file only as a guard that every model
# calls it, as test/models/public_id_fixed_length_contract_test.rb does for public_id.
# Every application string column with a physical character limit rejects one character beyond that
# limit before SQL, and accepts exactly the limit. public_id is excluded: adr/identifier-contract.md
# fixes it at exactly 21 characters, which each model's test checks with assert_public_id_fixed_length.
class StringColumnLengthValidationContractTest < ActiveSupport::TestCase
  EXCLUDED_COLUMNS = %w(public_id).freeze

  Rails.application.eager_load!

  APP_ROOT = Rails.root.join("app").to_s

  def self.limited_string_columns
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .sort_by(&:name)
      .flat_map do |model|
        model.columns
          .select { |column| column.type == :string && column.limit && !(column.respond_to?(:array) && column.array) }
          .reject { |column| EXCLUDED_COLUMNS.include?(column.name) }
          .map { |column| [model, column.name, column.limit] }
      end
  end

  def length_errors(model, attribute, value)
    record = model.new
    record.public_send(:"#{attribute}=", value)
    model.validators_on(attribute).grep(ActiveModel::Validations::LengthValidator).each { |validator| validator.validate(record) }
    record.errors.details[attribute.to_sym].pluck(:error)
  end

  # Exact-length columns (length: { is: }) report :wrong_length instead of :too_long.
  OVERSIZE_ERRORS = %i(too_long wrong_length).freeze

  limited_string_columns.group_by(&:first).each do |model, columns|
    test "#{model.name} string columns reject one character beyond the physical limit" do
      columns.each do |_model, attribute, limit|
        assert_not_includes length_errors(model, attribute, "a" * limit), :too_long,
                            "#{model.name}##{attribute} must accept #{limit} characters"
        assert_predicate length_errors(model, attribute, "a" * (limit + 1)).intersection(OVERSIZE_ERRORS), :any?,
                         "#{model.name}##{attribute} must reject #{limit + 1} characters"
      end
    end
  end
end
