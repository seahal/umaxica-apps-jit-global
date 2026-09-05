# frozen_string_literal: true

# Shared wiring for the four taxonomy assignment tables. Cardinality, locale
# coherence, vocabulary membership, and kind agreement are enforced by
# PostgreSQL; the validations here only turn violations into readable errors
# before the database sees them.
#
# included do installs associations and validations: those are the assignment
# persistence contract, not hidden side effects. Owner belongs_to stays on each
# concrete class so revision vs version ownership remains visible.
module PublishingTaxonomyAssignment
  extend ActiveSupport::Concern

  included do
    belongs_to :vocabulary, class_name: "Publishing::Vocabulary"
    belongs_to :taxonomy_term, class_name: "Publishing::TaxonomyTerm"

    validates :locale, presence: true
    # Resolved per record so that including classes can declare expected_kind
    # after the include.
    validates :vocabulary_kind, inclusion: { in: ->(record) { [record.class.expected_kind] } }
  end

  class_methods do
    # Each table is dedicated to exactly one structural kind, matching its
    # CHECK constraint. Subclass-specific dispatch stays a constant, never a
    # branch on the vocabulary key.
    def expected_kind = raise(NotImplementedError, "#{name} must declare expected_kind")
  end

  def structural_kind = Publishing::TaxonomyKind.fetch(vocabulary_kind)
end
