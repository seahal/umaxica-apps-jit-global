# typed: false
# frozen_string_literal: true

class BureauLifecycle < OrgRpRecord
  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :bureau, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
