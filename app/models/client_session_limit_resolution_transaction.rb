# typed: false
# frozen_string_literal: true

class ClientSessionLimitResolutionTransaction < AppTicketRecord
  include SessionLimitResolutionTransactionable

  self.belongs_to_required_by_default = false

  validates :actor_ref, :browser_binding_digest, :started_at, :expires_at,
            presence: true
  validates :challenge_digest, presence: true, uniqueness: true
  # belongs_to_required_by_default is disabled, so keep these explicit checks.
  # rubocop:disable Rails/RedundantPresenceValidationOnBelongsTo
  validates :state_id, :sign_in_flow_id, presence: true
  # rubocop:enable Rails/RedundantPresenceValidationOnBelongsTo
  validates :state_id,
            inclusion: { in: SessionLimitResolutionTransactionable::TRANSITIONS.keys }

  belongs_to :state, class_name: "ClientSessionLimitResolutionState",
                     inverse_of: :client_session_limit_resolution_transactions
  belongs_to :sign_in_flow, class_name: "ClientSignInFlow",
                            inverse_of: false
  belongs_to :oidc_authorization_transaction, class_name: "ClientOidcAuthorizationTransaction",
                                              optional: true, inverse_of: false

  # These names make the D-31 state vocabulary readable at call sites.
  PENDING = SessionLimitResolutionTransactionable::PENDING
  SESSION_SELECTED = SessionLimitResolutionTransactionable::SESSION_SELECTED
  RESOLVED = SessionLimitResolutionTransactionable::RESOLVED
  EXPIRED = SessionLimitResolutionTransactionable::EXPIRED
  CANCELLED = SessionLimitResolutionTransactionable::CANCELLED
end
