# typed: false
# frozen_string_literal: true

class AvatarOwnershipTransfer < AvatarRecord
  include ::PublicId

  STATES = %w(pending accepted cancelled expired).freeze
  SURFACES = %w(app org).freeze

  belongs_to :avatar, inverse_of: :ownership_transfers

  scope :pending, -> { where(state: "pending") }

  validates :state, inclusion: { in: STATES }
  validates :from_owner_surface, inclusion: { in: SURFACES }
  validates :to_owner_surface, inclusion: { in: SURFACES }
  validates :request_actor_surface, inclusion: { in: SURFACES }
  validates :from_owner_collective_public_id, :to_owner_collective_public_id,
            :request_actor_public_id, presence: true
  validates :expires_at, comparison: { greater_than: :requested_at },
                         if: -> { requested_at.present? && expires_at.present? }
  validate :source_and_target_owners_differ
  validate :actor_surfaces_match_terminal_state

  private

  def source_and_target_owners_differ
    return unless from_owner_surface.present? && from_owner_collective_public_id.present? &&
      to_owner_surface.present? && to_owner_collective_public_id.present?
    return unless [from_owner_surface, from_owner_collective_public_id] ==
      [to_owner_surface, to_owner_collective_public_id]

    errors.add(:to_owner_collective_public_id, :invalid)
  end

  def actor_surfaces_match_terminal_state
    return if state.blank?

    errors.add(:request_actor_surface, :invalid) if request_actor_surface != from_owner_surface
    errors.add(:accept_actor_surface, :invalid) if accepted_at.present? && accept_actor_surface != to_owner_surface
    errors.add(:cancel_actor_surface, :invalid) if cancelled_at.present? && cancel_actor_surface != from_owner_surface
  end
end
