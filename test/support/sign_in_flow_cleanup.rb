# frozen_string_literal: true

# Committed-transaction tests delete the sign-in flows they created in teardown. Session-limit
# resolutions and secret sign-in receipts reference those flows with ON DELETE RESTRICT, and an
# OIDC parent can hold a secret sign-in reference, so the references have to go first. A recycled
# synthetic principal id also makes a flow query match rows another run left behind; deleting
# those without their references aborts the teardown midway and leaks the rows after it, which
# then fail foreign-key validation for every later fixture load in the worker.
module SignInFlowCleanup
  def delete_client_sign_in_flows!(scope)
    flow_ids = scope.pluck(:id)
    return if flow_ids.empty?

    ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow_ids).delete_all
    ClientSecretSignInReceipt.where(sign_in_flow_id: flow_ids).delete_all
    ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow_ids).update_all(secret_sign_in_flow_id: nil)
    ClientSignInFlow.where(id: flow_ids).delete_all
  end
end
