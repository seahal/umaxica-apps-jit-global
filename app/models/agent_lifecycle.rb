# typed: false
# frozen_string_literal: true

class AgentLifecycle < OrgRpRecord
  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :agent, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
