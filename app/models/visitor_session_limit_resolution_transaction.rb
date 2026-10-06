# typed: false
# frozen_string_literal: true

class VisitorSessionLimitResolutionTransaction < ComTicketRecord
  include SessionLimitResolutionTransactionable

  belongs_to :state, class_name: "VisitorSessionLimitResolutionState",
                     inverse_of: :visitor_session_limit_resolution_transactions
  belongs_to :sign_in_flow, class_name: "VisitorSignInFlow",
                            inverse_of: false
  belongs_to :oidc_authorization_transaction, class_name: "VisitorOidcAuthorizationTransaction",
                                              optional: true, inverse_of: false

  PENDING = SessionLimitResolutionTransactionable::PENDING
  SESSION_SELECTED = SessionLimitResolutionTransactionable::SESSION_SELECTED
  RESOLVED = SessionLimitResolutionTransactionable::RESOLVED
  EXPIRED = SessionLimitResolutionTransactionable::EXPIRED
  CANCELLED = SessionLimitResolutionTransactionable::CANCELLED
end
