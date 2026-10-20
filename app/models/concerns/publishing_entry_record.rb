# frozen_string_literal: true

module PublishingEntryRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    # SQL requires a value but permits blank locale strings; preserve that distinction.
    validates :locale, exclusion: { in: [nil], message: :blank }, on: :create

    family = name.deconstantize
    belongs_to :current_revision, class_name: "#{family}::EntryRevision", optional: true
    has_many :revisions, class_name: "#{family}::EntryRevision", inverse_of: :entry,
                         dependent: :restrict_with_exception
    has_many :versions, class_name: "#{family}::EntryVersion", inverse_of: :entry,
                        dependent: :restrict_with_exception
    has_many :slugs, class_name: "#{family}::EntrySlug", inverse_of: :entry,
                     dependent: :restrict_with_exception
    has_many :publications, class_name: "#{family}::Publication", inverse_of: :entry,
                            dependent: :restrict_with_exception
    has_one :canonical_slug, -> { canonical },
            class_name: "#{family}::EntrySlug", inverse_of: :entry, dependent: :restrict_with_exception
    has_one :active_publication, -> { active },
            class_name: "#{family}::Publication", inverse_of: :entry, dependent: :restrict_with_exception
  end

  def archived? = archived_at.present?
end
