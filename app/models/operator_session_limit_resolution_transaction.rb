# typed: false
# frozen_string_literal: true

class OperatorSessionLimitResolutionTransaction < OrgTicketRecord
  include SessionLimitResolutionTransactionable

  belongs_to :state, class_name: "OperatorSessionLimitResolutionState",
                     inverse_of: :operator_session_limit_resolution_transactions
  belongs_to :sign_in_flow, class_name: "OperatorSignInFlow",
                            inverse_of: false
  belongs_to :oidc_authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction",
                                              optional: true, inverse_of: false

  PENDING = SessionLimitResolutionTransactionable::PENDING
  SESSION_SELECTED = SessionLimitResolutionTransactionable::SESSION_SELECTED
  RESOLVED = SessionLimitResolutionTransactionable::RESOLVED
  EXPIRED = SessionLimitResolutionTransactionable::EXPIRED
  CANCELLED = SessionLimitResolutionTransactionable::CANCELLED
end
