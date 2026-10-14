# frozen_string_literal: true

module StrictLoadingAssociationPreloader
  module_function

  # Active Record's dependent callbacks traverse every declared dependent relation.
  def for_destruction(record)
    dependent_associations =
      record.class.reflect_on_all_associations.filter_map do |reflection|
        reflection.name if reflection.options[:dependent]
      end

    record.class.includes(*dependent_associations).find(record.id)
  end
end
