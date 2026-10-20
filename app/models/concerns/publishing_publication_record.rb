# frozen_string_literal: true

module PublishingPublicationRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    # FIXME: ColumnPresenceChecker treats create-only validation as possible NULL despite the DB
    # NOT NULL constraint; keep projected existing-record updates valid and track the report in C11.
    validates :effective_from, presence: true, on: :create

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
