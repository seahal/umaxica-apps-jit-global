# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_entry_versions
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
#  entry_revision_id             :bigint           not null
#  public_id                     :string(21)       not null
#
# Indexes
#
#  index_publishing_entry_versions_on_entry_id                    (entry_id)
#  index_publishing_entry_versions_on_entry_id_and_sequence       (entry_id,sequence) UNIQUE
#  index_publishing_entry_versions_on_entry_revision_id           (entry_revision_id) UNIQUE
#  index_publishing_entry_versions_on_id_and_entry_id             (id,entry_id) UNIQUE
#  index_publishing_entry_versions_on_id_and_entry_id_and_locale  (id,entry_id,locale) UNIQUE
#  index_publishing_entry_versions_on_id_and_locale               (id,locale) UNIQUE
#  index_publishing_entry_versions_on_public_id                   (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_publishing_version_entry_locale    ([entry_id, locale] => publishing_entries[id, locale]) ON DELETE => restrict
#  fk_publishing_version_revision_entry  ([entry_revision_id, entry_id] => publishing_entry_revisions[id, entry_id]) ON DELETE => restrict
#  fk_rails_...                          (entry_id => publishing_entries.id) ON DELETE => restrict
#
module Publishing
  class EntryVersion < PublishingRecord
    self.table_name = "publishing_entry_versions"

    include PublicId

    # Version rows are immutable release snapshots; only the initial insert is
    # allowed. Declared before the associations so that immutability, not a
    # dependent-record restriction, is the reason a destroy fails. PostgreSQL
    # triggers enforce the same rule against writes that bypass Active Record.
    before_update { raise ActiveRecord::ReadOnlyRecord, "Publishing::EntryVersion is immutable" }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "Publishing::EntryVersion is immutable" }

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :versions
    belongs_to :entry_revision, class_name: "Publishing::EntryRevision"

    has_many :publications, class_name: "Publishing::Publication", inverse_of: :entry_version,
                            dependent: :restrict_with_exception
    has_many :media_usages, class_name: "Publishing::VersionMediaUsage", inverse_of: :entry_version,
                            dependent: :restrict_with_exception
    # restrict_with_exception, not destroy: a published version's taxonomy
    # history is frozen, and PostgreSQL rejects the delete regardless.
    has_many :single_taxonomy_assignments, class_name: "Publishing::VersionSingleTaxonomyAssignment",
                                           inverse_of: :entry_version, dependent: :restrict_with_exception
    has_many :multiple_taxonomy_assignments, -> { ordered }, class_name: "Publishing::VersionMultipleTaxonomyAssignment",
                                                             inverse_of: :entry_version,
                                                             dependent: :restrict_with_exception
  end
end
