# typed: false
# frozen_string_literal: true

class CompanyLifecycle < ComRpRecord
  validates :company_id, uniqueness: true

  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :company, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
