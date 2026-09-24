# typed: false
# frozen_string_literal: true

class ClientPersonaLifecycle < AppRpRecord
  STATES = AuthorityResourceLifecycleStateValue::VALUES

  belongs_to :client_persona, inverse_of: :lifecycle

  validates :state, presence: true, inclusion: { in: STATES }

  public

  def active?
    state == AuthorityResourceLifecycleStateValue::ACTIVE
  end
end
