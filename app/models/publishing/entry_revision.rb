# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_entry_revisions
# Database name: publishing
#
#  id                            :bigint           not null, primary key
#  body                          :jsonb            not null
#  content_digest                :string(64)       not null
#  locale                        :string           not null
#  schema_version                :integer          not null
#  sequence                      :integer          not null
#  summary                       :text
#  title                         :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  created_by_operator_public_id :string(21)
#  entry_id                      :bigint           not null
#  public_id                     :string(21)       not null
#  restored_from_revision_id     :bigint
#  restored_from_version_id      :bigint
#
# Indexes
#
#  index_publishing_entry_revisions_on_entry_id                    (entry_id)
#  index_publishing_entry_revisions_on_entry_id_and_sequence       (entry_id,sequence) UNIQUE
#  index_publishing_entry_revisions_on_id_and_entry_id             (id,entry_id) UNIQUE
#  index_publishing_entry_revisions_on_id_and_entry_id_and_locale  (id,entry_id,locale) UNIQUE
#  index_publishing_entry_revisions_on_id_and_locale               (id,locale) UNIQUE
#  index_publishing_entry_revisions_on_public_id                   (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_publishing_restore_revision_entry  ([restored_from_revision_id, entry_id] => publishing_entry_revisions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_restore_version_entry   ([restored_from_version_id, entry_id] => publishing_entry_versions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_revision_entry_locale   ([entry_id, locale] => publishing_entries[id, locale]) ON DELETE => restrict
#  fk_rails_...                          (entry_id => publishing_entries.id) ON DELETE => restrict
#
module Publishing
  class EntryRevision < PublishingRecord
    self.table_name = "publishing_entry_revisions"

    include PublicId

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :revisions
    belongs_to :restored_from_revision, class_name: "Publishing::EntryRevision", optional: true
    belongs_to :restored_from_version, class_name: "Publishing::EntryVersion", optional: true

    has_many :media_usages, class_name: "Publishing::RevisionMediaUsage", inverse_of: :entry_revision,
                            dependent: :restrict_with_exception
    has_many :single_taxonomy_assignments, class_name: "Publishing::RevisionSingleTaxonomyAssignment",
                                           inverse_of: :entry_revision, dependent: :destroy
    has_many :multiple_taxonomy_assignments, -> { ordered }, class_name: "Publishing::RevisionMultipleTaxonomyAssignment",
                                                             inverse_of: :entry_revision, dependent: :destroy

    # Drafts may hold archived terms (restoring an old version must not fail),
    # but promotion is blocked until the author resolves them.
    # An assignment blocks promotion when its vocabulary is archived, its term is
    # archived, or any ancestor on the term's breadcrumb is archived.
    def archived_taxonomy_assignments
      taxonomy_assignments.select do |assignment|
        assignment.vocabulary.archived? || assignment.taxonomy_term.archived_in_path.any?
      end
    end

    def promoted? = Publishing::EntryVersion.exists?(entry_revision_id: id)

    # Both assignment kinds with their vocabulary and term loaded, ready for the
    # promotion path to inspect and snapshot without lazy loading.
    def taxonomy_assignments
      single_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).to_a +
        multiple_taxonomy_assignments.includes(:vocabulary, :taxonomy_term).to_a
    end
  end
end
