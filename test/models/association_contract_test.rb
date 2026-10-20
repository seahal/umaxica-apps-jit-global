# typed: false
# frozen_string_literal: true

require "test_helper"

class AssociationContractTest < ActiveSupport::TestCase
  test "belongs_to associations backed by non-null foreign keys are not optional" do
    Rails.application.eager_load!

    violations =
      application_models.flat_map do |model|
        model.reflect_on_all_associations(:belongs_to).filter_map do |association|
          next unless association.options[:optional]
          next if association.options[:polymorphic]

          table_name = model.table_name
          connection = model.connection
          next unless connection.data_source_exists?(table_name)

          foreign_key = association.foreign_key.to_s
          column = connection.columns(table_name).find { |candidate| candidate.name == foreign_key }
          next unless column && !column.null
          next unless foreign_key_constraint?(connection, table_name, foreign_key)

          "#{model.name}.#{association.name} (#{table_name}.#{foreign_key})"
        end
      end

    assert_empty violations.sort,
                 "Remove optional: true from belongs_to associations backed by NOT NULL foreign keys:\n" \
                 "#{violations.sort.join("\n")}"
  end

  test "associations declaring inverse_of resolve to an existing inverse association" do
    Rails.application.eager_load!

    violations =
      application_models.flat_map do |model|
        model.reflect_on_all_associations.filter_map do |association|
          next unless association.options[:inverse_of]
          next if association.polymorphic?

          association.check_validity_of_inverse!
          nil
        rescue ActiveRecord::InverseOfAssociationNotFoundError
          "#{model.name}.#{association.name} (inverse_of: :#{association.options[:inverse_of]})"
        end
      end

    assert_empty violations.sort,
                 "Declare the inverse association or correct inverse_of:\n#{violations.sort.join("\n")}"
  end

  private

  def application_models
    ActiveRecord::Base.descendants.reject do |model|
      model.abstract_class? || model.name.blank? || framework_model?(model)
    end
  end

  def framework_model?(model)
    model.name.start_with?(
      "ActionMailbox::",
      "ActionText::",
      "ActiveStorage::",
      "ActionPushNative::",
      "SolidQueue::",
    )
  end

  def foreign_key_constraint?(connection, table_name, foreign_key)
    connection.foreign_keys(table_name).any? do |constraint|
      Array(constraint.column).map(&:to_s).include?(foreign_key)
    end
  end
end
