# typed: false
# frozen_string_literal: true

require "test_helper"

# FIXME: Move these per-model checks into each model's own test (test/models/<model>_test.rb)
# through a shared assertion in test/support/, and keep this file only as a guard that every model
# calls it, as test/models/public_id_fixed_length_contract_test.rb does for public_id.
# Every application column that is NOT NULL without a database default rejects nil in model
# validation, before SQL. Primary keys and Rails-managed timestamps are filled by the framework.
# Only nil-rejecting validator kinds run, so the check needs no database rows.
class NotNullColumnNilValidationContractTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app").to_s
  NIL_REJECTING_KINDS = %i(presence inclusion exclusion numericality).freeze

  # [model name pattern, column, reason]. A nil check on these columns changes established behavior.
  NIL_ALLOWED_BEFORE_SQL = [
    [/\AAvatar\z/, "active_handle_id", "assigned during creation after validation"],
    [/OwnershipTransferRequest\z/, "requested_at", "blank requests skip party and expiry checks"],
    [/OwnershipTransferRequest\z/, "expires_at", "blank requests skip party and expiry checks"],
    [/\APublishing::.*::Entry(Revision|Version)\z/, "content_digest",
     "create-time digest format validation rejects nil; updates rely on the database refusal",],
    [/\APublishing::.*::Entry(Revision|Version)\z/, "body", "the JSON-object validation reports nil"],
    [/\APublishing::.*::VersionMultipleTaxonomyAssignment\z/, "position_snapshot",
     "derived from position by apply_snapshot and the snapshot trigger",],
  ].freeze

  Rails.application.eager_load!

  def self.required_columns
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .sort_by(&:name)
      .flat_map do |model|
        model.columns
          .select { |column| !column.null && column.default.nil? && !column.default_function }
          .reject { |column| column.name == model.primary_key.to_s }
          .reject { |column| model.record_timestamps && %w(created_at updated_at).include?(column.name) }
          .reject { |column| nil_allowed_before_sql?(model, column.name) }
          .map { |column| [model, column.name] }
      end
  end

  def self.nil_allowed_before_sql?(model, column)
    NIL_ALLOWED_BEFORE_SQL.any? { |pattern, name, _reason| name == column && model.name.match?(pattern) }
  end

  def nil_errors?(model, attribute)
    record = model.new
    record.public_send(:"#{attribute}=", nil)
    association =
      model.reflect_on_all_associations(:belongs_to).find { |reflection|
        reflection.foreign_key.to_s == attribute
      }
    names = [attribute.to_sym, association&.name].compact
    names.each do |name|
      model.validators_on(name).select { |validator| NIL_REJECTING_KINDS.include?(validator.kind) }
        .each { |validator| validator.validate(record) }
    end
    names.any? { |name| record.errors.details[name].any? }
  end

  required_columns.group_by(&:first).each do |model, columns|
    test "#{model.name} NOT NULL columns reject nil before SQL" do
      columns.each do |_model, attribute|
        assert nil_errors?(model, attribute), "#{model.name}##{attribute} must reject nil"
      end
    end
  end
end
