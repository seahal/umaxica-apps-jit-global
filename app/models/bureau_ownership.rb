# typed: false
# frozen_string_literal: true

class BureauOwnership < OrgRpRecord
  before_destroy :prevent_independent_destroy

  belongs_to :bureau, inverse_of: :ownership
  belongs_to :operator, inverse_of: :bureau_ownerships

  validates :ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def prevent_independent_destroy
    errors.add(:base, "ownership rows cannot be deleted independently")
    throw(:abort)
  end
end
