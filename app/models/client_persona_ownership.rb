# typed: false
# frozen_string_literal: true

class ClientPersonaOwnership < AppRpRecord
  validates :client_persona_id, uniqueness: true

  belongs_to :client_persona, inverse_of: :ownership
  belongs_to :client, inverse_of: :client_persona_ownerships

  validates :ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_destroy :prevent_independent_destroy

  private

  def prevent_independent_destroy
    errors.add(:base, "ownership rows cannot be deleted independently")
    throw(:abort)
  end
end
