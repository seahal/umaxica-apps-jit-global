# frozen_string_literal: true

# Ticket commit evidence survives every live continuation and source reconciliation.
class ClientSecretSignInReceiptPurger
  class << self
    public

    def call!(receipt:, retention_after:)
      unless receipt.is_a?(ClientSecretSignInReceipt) && receipt.persisted? &&
          retention_after.is_a?(ActiveSupport::Duration) && retention_after.value.finite? &&
          retention_after.value.positive?
        raise ArgumentError, "Secret receipt collection requires a persisted receipt and explicit finite retention"
      end

      AppZenithRecord.connected_to(role: :writing) do
        owner = Client.find_by(public_id: receipt.client_ref)
        if owner
          owner.with_lock { lock_ticket_proofs!(receipt, retention_after, owner) }
        else
          lock_ticket_proofs!(receipt, retention_after, nil)
        end
      end
    end

    private

    def lock_ticket_proofs!(receipt, duration, owner)
      AppTicketRecord.connected_to(role: :writing) do
        ClientSecretSignInReceipt.transaction do
          authorization = ClientOidcAuthorizationTransaction.find_by(secret_sign_in_flow_id: receipt.sign_in_flow_id)
          if authorization
            authorization.with_lock { purge!(receipt, duration, owner, authorization) }
          else
            purge!(receipt, duration, owner, nil)
          end
        end
      end
    end

    def purge!(receipt, duration, owner, authorization)
      flow = ClientSignInFlow.lock.find(receipt.sign_in_flow_id)
      receipt.lock!
      now = ClientSignInFlow.database_now
      unless flow.sign_in_completed? && flow.authentication_method == "secret" &&
          flow.authentication_context == "normal" && flow.completed_at &&
          flow.session_issued_at == receipt.committed_at && flow.public_id.present?
        raise ClientSecretSignInReceipt::InvalidCommit, "Secret receipt collection requires terminal commit facts"
      end

      deadlines = [receipt.committed_at, flow.completed_at, flow.expires_at]
      deadlines += [authorization.expires_at, authorization.login_challenge_expires_at] if authorization
      return :pending if deadlines.max + duration > now
      return :held if (owner && owner.client_retention_holds.active_at(now).exists?) ||
        AppEnforcementCase.principal_effect_blocking?(receipt.client_ref, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(receipt.client_ref, :principal_hard_delete_blocked)
      return :dependent if ClientSecretCredential.exists?(public_id: receipt.credential_ref)

      terminal_at = terminal_audit_time(receipt)
      return :undelivered unless terminal_at
      return :pending if terminal_at + duration > now

      receipt.delete
      :purged
    end

    def terminal_audit_time(receipt)
      ChronicleRecord.connected_to(role: :writing) do
        times =
          %w(secret.consumed secret.purged).map do |action|
            Chronicle.where(
              action: action, request_id: receipt.operation_id, result: "succeeded",
            ).where("metadata ->> 'credential_ref' = ? AND metadata ->> 'client_ref' = ?",
                    receipt.credential_ref, receipt.client_ref,).maximum(:occurred_at)
          end
        times.all? ? times.max : nil
      end
    end
  end
end
