# typed: false
# frozen_string_literal: true

class BureauLifecycle < OrgRpRecord
  validates :bureau_id, uniqueness: true

  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :bureau, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
