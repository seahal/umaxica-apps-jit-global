# typed: false
# frozen_string_literal: true

require "test_helper"

# FIXME: Move these per-model checks into each model's own test (test/models/<model>_test.rb)
# through a shared assertion in test/support/, and keep this file only as a guard that every model
# calls it, as test/models/public_id_fixed_length_contract_test.rb does for public_id.
# An attribute the model always requires (an unconditional presence validation or a required
# belongs_to) is also NOT NULL in the database, so rows written without model validation cannot
# hold a value the model would reject.
class RequiredAttributeNotNullContractTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app").to_s
  CONDITIONAL_OPTIONS = %i(allow_nil allow_blank if unless on).freeze

  # The parent nullifies these columns on deletion (dependent: :nullify or ON DELETE SET NULL), so
  # NOT NULL would block deleting the parent. Recorded in
  # plans/backlog/2026-10-20-required-belongs-to-nullified-on-parent-delete.md.
  NULLIFIED_ON_PARENT_DELETE = {
    "ClientProfile" => %w(user_id),
    "Member" => %w(user_id),
    "OperatorWorkspaceAccount" => %w(department_id),
  }.freeze

  Rails.application.eager_load!

  def self.required_columns
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .sort_by(&:name)
      .flat_map { |model| required_columns_of(model).map { |column| [model, column] } }
  end

  def self.required_columns_of(model)
    presence = model.validators.select { |validator| validator.kind == :presence }
    # A required belongs_to only re-validates when its foreign key changes, but is always required.
    presence.select { |validator| validator.options.except(:if).slice(*CONDITIONAL_OPTIONS).empty? }
      .select { |validator| validator.options[:if].nil? || validator.options[:message] == :required }
      .flat_map(&:attributes)
      .filter_map do |attribute|
        reflection = model.reflect_on_association(attribute)
        reflection&.belongs_to? ? reflection.foreign_key.to_s : attribute.to_s
      end
      .uniq
      .select { |column| model.columns_hash.key?(column) }
      .reject { |column| NULLIFIED_ON_PARENT_DELETE.fetch(model.name, []).include?(column) }
  end

  required_columns.group_by(&:first).each do |model, columns|
    test "#{model.name} always-required attributes are NOT NULL in the database" do
      columns.each do |_model, column|
        assert_not model.columns_hash.fetch(column).null, "#{model.name}##{column} must be NOT NULL"
      end
    end
  end
end
