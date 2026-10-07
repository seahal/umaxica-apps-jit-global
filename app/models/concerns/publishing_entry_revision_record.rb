# frozen_string_literal: true

module PublishingEntryRevisionRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId
    include PublishingEncryptedContent

    family = name.deconstantize
    belongs_to :entry, class_name: "#{family}::Entry", inverse_of: :revisions
    belongs_to :restored_from_revision, class_name: "#{family}::EntryRevision", optional: true
    belongs_to :restored_from_version, class_name: "#{family}::EntryVersion", optional: true
    has_many :media_usages, class_name: "#{family}::RevisionMediaUsage", inverse_of: :entry_revision,
                            dependent: :restrict_with_exception
    has_many :single_taxonomy_assignments, class_name: "#{family}::RevisionSingleTaxonomyAssignment",
                                           inverse_of: :entry_revision, dependent: :destroy
    has_many :multiple_taxonomy_assignments, -> { ordered },
             class_name: "#{family}::RevisionMultipleTaxonomyAssignment",
             inverse_of: :entry_revision, dependent: :destroy
  end

  def archived_taxonomy_assignments
    taxonomy_assignments.select do |assignment|
      assignment.vocabulary.archived? || assignment.taxonomy_term.archived_in_path.any?
    end
  end

  def promoted?
    entry.versions.exists?(entry_revision_id: id)
  end

  def taxonomy_assignments
    single_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).to_a +
      multiple_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).to_a
  end
end
