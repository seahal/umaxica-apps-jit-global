# typed: false
# frozen_string_literal: true

class ClientSessionLimitResolutionTransaction < AppTicketRecord
  include SessionLimitResolutionTransactionable

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
