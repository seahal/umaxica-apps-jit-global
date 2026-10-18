# typed: false
# frozen_string_literal: true

module BannerModel
  extend ActiveSupport::Concern

  DISTANT_ENDS_AT = -> { Time.zone.local(9999, 12, 31, 23, 59, 59) }

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    attribute :published, default: false
    attribute :starts_at, default: -> { Time.current }
    attribute :ends_at, default: DISTANT_ENDS_AT

    validates :body, :starts_at, :ends_at, presence: true
    validate :ends_at_after_starts_at

    scope :published, -> { where(published: true) }
    scope :active_now, ->(now = Time.current) { where(starts_at: ..now).where(arel_table[:ends_at].gt(now)) }
    scope :current, ->(now = Time.current) { published.active_now(now).order(starts_at: :desc, id: :desc) }
  end

  def actor
    nil
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, :invalid)
  end
end
