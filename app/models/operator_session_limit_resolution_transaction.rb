# typed: false
# frozen_string_literal: true

class OperatorSessionLimitResolutionTransaction < OpBaseOrgRecord
  include SessionLimitResolutionTransactionable

  self.belongs_to_required_by_default = false

  PENDING = SessionLimitResolutionTransactionable::PENDING
  SESSION_SELECTED = SessionLimitResolutionTransactionable::SESSION_SELECTED
  RESOLVED = SessionLimitResolutionTransactionable::RESOLVED
  EXPIRED = SessionLimitResolutionTransactionable::EXPIRED
  CANCELLED = SessionLimitResolutionTransactionable::CANCELLED

  belongs_to :state, class_name: "OperatorSessionLimitResolutionState",
                     inverse_of: :operator_session_limit_resolution_transactions
  belongs_to :sign_in_flow, class_name: "OperatorSignInFlow",
                            inverse_of: false
  belongs_to :oidc_authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction",
                                              optional: true, inverse_of: false

  validates :actor_ref, :browser_binding_digest, :started_at, :expires_at,
            presence: true
  validates :challenge_digest, presence: true, uniqueness: true
  # belongs_to_required_by_default is disabled, so keep these explicit checks.
  # rubocop:disable Rails/RedundantPresenceValidationOnBelongsTo
  validates :state_id, :sign_in_flow_id, presence: true
  # rubocop:enable Rails/RedundantPresenceValidationOnBelongsTo
  validates :state_id,
            inclusion: { in: SessionLimitResolutionTransactionable::TRANSITIONS.keys }
  validate :waiting_slot_matches_state
end
