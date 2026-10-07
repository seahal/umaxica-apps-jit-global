# typed: false
# frozen_string_literal: true

module AccountAssignment
  extend ActiveSupport::Concern

  include ::PublicId

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    scope :active, -> { where(revoked_at: nil) }

    before_validation :set_assigned_at, on: :create
    before_create :set_assigned_at

    validates :assigned_at, presence: true
  end

  def active?
    revoked_at.blank?
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(at: Time.current)
    update!(revoked_at: at)
  end

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
