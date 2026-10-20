# typed: false
# frozen_string_literal: true

class IndividualLifecycle < ComRpRecord
  validates :individual_id, uniqueness: true

  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :individual, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
