# typed: false
# frozen_string_literal: true

class EnterpriseLifecycle < AppRpRecord
  validates :enterprise_id, uniqueness: true

  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :enterprise, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
