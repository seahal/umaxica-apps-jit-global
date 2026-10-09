# typed: false
# frozen_string_literal: true

class IndividualOwnership < ComRpRecord
  belongs_to :individual, inverse_of: :ownership
  belongs_to :visitor, inverse_of: :individual_ownerships

  validates :ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_destroy :prevent_independent_destroy

  private

  def prevent_independent_destroy
    errors.add(:base, "ownership rows cannot be deleted independently")
    throw(:abort)
  end
end
