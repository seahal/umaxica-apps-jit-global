# frozen_string_literal: true

module PublishingEntrySlugRecord
  extend ActiveSupport::Concern

  STATES = %w(reserved canonical redirect).freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    # SQL requires a value but permits blank locale strings; preserve that distinction.
    validates :locale, exclusion: { in: [nil], message: :blank }, on: :create

    family = name.deconstantize
    belongs_to :entry, class_name: "#{family}::Entry", inverse_of: :slugs
    validates :state, inclusion: { in: STATES }
    scope :canonical, -> { where(state: "canonical") }
  end
end
