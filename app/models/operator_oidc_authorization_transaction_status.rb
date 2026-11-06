# frozen_string_literal: true
# typed: false

class OperatorOidcAuthorizationTransactionStatus < OpBaseOrgRecord
  include ReferenceRecord

  PENDING = OidcAuthorizationTransactionable::STATUS_PENDING
  AUTHENTICATED = OidcAuthorizationTransactionable::STATUS_AUTHENTICATED
  CONSUMED = OidcAuthorizationTransactionable::STATUS_CONSUMED
  CANCELED = OidcAuthorizationTransactionable::STATUS_CANCELED
  DEFAULTS = OidcAuthorizationTransactionable::STATUS_IDS

  has_many :operator_oidc_authorization_transactions,
           class_name: "OperatorOidcAuthorizationTransaction",
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
