# frozen_string_literal: true

module PublishingPublicationRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    family = name.deconstantize
    belongs_to :entry, class_name: "#{family}::Entry", inverse_of: :publications
    belongs_to :entry_version, class_name: "#{family}::EntryVersion", inverse_of: :publications

    scope :active, -> {
      now = Time.current
      where(cancelled_at: nil)
        .where(effective_from: ..now)
        .where("effective_until IS NULL OR effective_until > ?", now)
    }
  end

  def cancelled? = cancelled_at.present?

  def terminated? = terminated_at.present?
end
