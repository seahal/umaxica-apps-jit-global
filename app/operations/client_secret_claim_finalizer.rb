# frozen_string_literal: true

# Unknown outcomes remain claimed. Terminalization and issuance contend on the same
# Ticket flow row; only a committed matching receipt can prove successful consumption.
class ClientSecretClaimFinalizer
  class << self
    public

    def call!(credential:, purge_after:)
      unless credential.is_a?(ClientSecretCredential) && purge_after.is_a?(ActiveSupport::Duration) &&
          purge_after.value.positive? && purge_after.value.finite?
        raise ArgumentError, "Secret reconciliation requires its credential and finite retention"
      end

      AppZenithRecord.connected_to(role: :writing) do
        credential.client.with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignInFlow.transaction do
              flow = ClientSignInFlow.find_by(public_id: credential.claim_sign_in_flow_ref)
              return :unknown unless flow

              ClientOidcAuthorizationTransaction.lock.find_by(secret_sign_in_flow_id: flow.id)
              flow.lock!
              credential.lock!
              return :retired if credential.discard_at != Float::INFINITY

              finalize_locked!(credential, flow, purge_after)
            end
          end
        end
      end
    end

    private

    def finalize_locked!(credential, flow, purge_after)
      receipt = ClientSecretSignInReceipt.find_by(operation_id: credential.claim_operation_id)
      reason = receipt ? verify_receipt!(credential, flow, receipt) : failure_reason!(credential, flow)
      return reason if %i(unknown pending).include?(reason)

      now = Client.database_now
      credential.commit_sign_in_retirement!(
        actor_context: ActorValuesContext.empty.with(
          subject: credential.client, actor_type: :client, tld: :app, surface: :base,
        ),
        at: now, purge_at: now + purge_after, successful: receipt.present?, flow: flow, reason: reason,
      )
      receipt ? :consumed : :abandoned
    end

    def verify_receipt!(credential, flow, receipt)
      token = flow.token
      unless receipt.credential_ref == credential.public_id && receipt.sign_in_flow_id == flow.id &&
          receipt.client_ref == credential.client.public_id && flow.principal_id == credential.client_id &&
          flow.sign_in_completed? && flow.authentication_method == "secret" && token &&
          receipt.root_token_ref == token.public_id && receipt.committed_at == flow.session_issued_at &&
          token.root_login_established_at == receipt.committed_at
        raise ClientSecretSignInReceipt::InvalidCommit, "Secret reconciliation receipt mismatch"
      end

      "login_committed"
    end

    def failure_reason!(credential, flow)
      return :unknown if flow.sign_in_completed?

      reason = "flow_failed"
      if flow.expired?(ClientSignInFlow.database_now)
        flow.expire_sign_in! unless flow.sign_in_failed?
        reason = "flow_expired"
      elsif !flow.sign_in_failed?
        return :pending
      end
      ceremony = ClientAuthCeremonySession.lock.find_by(id: credential.claim_ceremony_session_id)
      return :unknown unless terminal_ceremony_matches?(ceremony, flow, credential)

      if flow.principal_id.nil?
        # The source claim can commit before an outer Ticket transaction rolls back.
        # Repair only terminal ownership; never admit authentication evidence.
        flow.update!(principal_id: credential.client_id)
      elsif flow.principal_id != credential.client_id
        raise ClientSecretSignInReceipt::InvalidCommit, "Secret terminal flow owner mismatch"
      end
      oidc_canceled = ceremony.admission_purpose == "authentication_handoff" &&
        ClientSessionLimitResolutionTransaction.exists?(
          oidc_authorization_transaction_id: ClientOidcAuthorizationTransaction.where(
            secret_sign_in_flow_id: flow.id,
          ).select(:id), status: ClientSessionLimitResolutionTransaction::STATUS_CANCELLED,
        )
      (ceremony.cancelled_at || oidc_canceled) ? "flow_canceled" : reason
    end

    def terminal_ceremony_matches?(ceremony, flow, credential)
      return false unless ceremony&.admitted?
      if ceremony.admission_purpose == "local_sign_in"
        return ceremony.local_sign_in_flow_ref == flow.public_id
      end
      return false unless ceremony.admission_purpose == "authentication_handoff"

      transaction = ClientOidcAuthorizationTransaction.find_by(
        secret_sign_in_flow_id: flow.id, transaction_id: ceremony.authorization_transaction_ref,
      )
      transaction && flow.principal_id == credential.client_id && flow.token_id.nil? &&
        flow.session_issued_at.nil? && transaction.base_finalized_at.nil? &&
        transaction.browser_session_ref.nil?
    end
  end
end
