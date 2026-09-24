# typed: false
# frozen_string_literal: true

class IndividualLifecycle < ComRpRecord
  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :individual, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
