# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/identifier-contract.md fixes NanoID public_id at 21 characters. The boundary and partition
# checks live in each model's own test (test/models/<model>_test.rb) through
# assert_public_id_fixed_length; this guard keeps a newly added PublicId model from skipping it.
class PublicIdFixedLengthContractTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app").to_s

  Rails.application.eager_load!

  def self.public_id_models
    ActiveRecord::Base.descendants
      .reject(&:abstract_class?)
      .select { |model| model.name && model.include?(PublicId) }
      .select { |model| Object.const_source_location(model.name)&.first&.start_with?(APP_ROOT) }
      .select { |model| model.with_connection { |connection| connection.table_exists?(model.table_name) } }
      .select { |model| model.columns_hash.key?("public_id") }
      .sort_by(&:name)
  end

  test "NanoID generation stays at the fixed storage length" do
    assert_equal PublicIdFixedLengthAssertions::PUBLIC_ID_LENGTH, PublicId.generate.length
  end

  test "every PublicId model's own test asserts the fixed public_id length" do
    missing =
      self.class.public_id_models.reject do |model|
        path = Rails.root.join("test/models/#{model.name.underscore}_test.rb")
        path.exist? && path.read.include?("assert_public_id_fixed_length(::#{model.name})")
      end

    assert_empty missing.map(&:name), "Add assert_public_id_fixed_length to these models' tests"
  end
end
