# typed: false
# frozen_string_literal: true

require "test_helper"

class UniquenessValidator < ActiveModel::EachValidator
  def validate_each(*)
  end
end

class DbscBindableTest < ActiveSupport::TestCase
  class MissingDbscModel
    include ActiveModel::Validations
    include DbscBindable

    def self.attribute_names = []
  end

  class TestDbscModel
    include ActiveModel::Validations
    include DbscBindable

    def self.attribute_names = %w(binding_method_id dbsc_status_id)

    def initialize(attributes)
      @attributes = attributes
    end

    delegate :[], to: :@attributes
  end

  test "raises when binding method attribute is missing" do
    assert_raises(NoMethodError) { MissingDbscModel.dbsc_binding_method_attribute_name }
  end

  test "raises when dbsc status attribute is missing" do
    assert_raises(NoMethodError) { MissingDbscModel.dbsc_status_attribute_name }
  end

  test "nothing predicates read resolved attributes" do
    record = TestDbscModel.new(binding_method_id: 0, dbsc_status_id: 0)

    assert_predicate record, :binding_method_nothing?
    assert_predicate record, :dbsc_status_nothing?
  end

  test "binding method predicates classify configured value" do
    dbsc = TestDbscModel.new(binding_method_id: 1, dbsc_status_id: 0)
    legacy = TestDbscModel.new(binding_method_id: 2, dbsc_status_id: 0)

    assert_predicate dbsc, :binding_method_dbsc?
    assert_predicate dbsc, :dbsc_enabled?
    assert_not_predicate dbsc, :binding_method_legacy?

    assert_predicate legacy, :binding_method_legacy?
    assert_not_predicate legacy, :dbsc_enabled?
  end

  test "dbsc status predicates use model constants" do
    status_class = Class.new
    status_class.const_set(:NOTHING, 0)
    status_class.const_set(:ACTIVE, 1)
    status_class.const_set(:PENDING, 2)
    status_class.const_set(:FAILED, 3)
    status_class.const_set(:REVOKE, 4)

    model_class =
      Class.new do
        include ActiveModel::Validations
        include DbscBindable

        define_singleton_method(:attribute_names) do
          %w(binding_method_id dbsc_status_id)
        end

        define_method(:initialize) do |attributes|
          @attributes = attributes
        end

        delegate :[], to: :@attributes
      end

    model_class.define_singleton_method(:dbsc_status_class) { status_class }
    record = model_class.new(binding_method_id: 0, dbsc_status_id: status_class::ACTIVE)

    assert_predicate record, :dbsc_status_active?
    assert_not_predicate record, :dbsc_status_pending?
  end

  test "all dbsc status predicates use model constants" do
    status_class = Class.new
    status_class.const_set(:PENDING, 10)
    status_class.const_set(:ACTIVE, 20)
    status_class.const_set(:FAILED, 30)
    status_class.const_set(:REVOKE, 40)

    model_class = Class.new(TestDbscModel)
    model_class.define_singleton_method(:dbsc_status_class) { status_class }

    assert_predicate model_class.new(binding_method_id: 0, dbsc_status_id: 10), :dbsc_status_pending?
    assert_predicate model_class.new(binding_method_id: 0, dbsc_status_id: 20), :dbsc_status_active?
    assert_predicate model_class.new(binding_method_id: 0, dbsc_status_id: 30), :dbsc_status_failed?
    assert_predicate model_class.new(binding_method_id: 0, dbsc_status_id: 40), :dbsc_status_revoke?
  end

  test "resolves supported binding method attribute names in precedence order" do
    assert_equal :binding_method_id, attribute_model(%w(binding_method_id)).dbsc_binding_method_attribute_name
    assert_equal :user_token_binding_method_id,
                 attribute_model(%w(user_token_binding_method_id)).dbsc_binding_method_attribute_name
    assert_equal :staff_token_binding_method_id,
                 attribute_model(%w(staff_token_binding_method_id)).dbsc_binding_method_attribute_name
  end

  test "resolves supported dbsc status attribute names in precedence order" do
    assert_equal :dbsc_status_id, attribute_model(%w(dbsc_status_id)).dbsc_status_attribute_name
    assert_equal :user_token_dbsc_status_id,
                 attribute_model(%w(user_token_dbsc_status_id)).dbsc_status_attribute_name
    assert_equal :staff_token_dbsc_status_id,
                 attribute_model(%w(staff_token_dbsc_status_id)).dbsc_status_attribute_name
  end

  private

  def attribute_model(attribute_names)
    Class.new do
      include ActiveModel::Validations
      include DbscBindable

      define_singleton_method(:attribute_names) { attribute_names }
    end
  end
end
