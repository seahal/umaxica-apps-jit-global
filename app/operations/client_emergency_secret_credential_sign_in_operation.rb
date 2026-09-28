# typed: false
# frozen_string_literal: true

# Cross-database integrity contract for App Emergency Secret Credential sign-in
# (adr/emergency-secret-credential-commit-acknowledgement.md).
#
# The credential lives in app_zenith; the app session (ClientToken) lives in app_ticket. No single
# transaction spans both, so the sign-in runs in three durable steps:
#
# 1. claim!    app_zenith: lock the credential row, verify it, and record one claim_operation_id.
#              From here no other request can verify the credential.
# 2. issue_session!
#              app_ticket: create the session (the caller's block) and a
#              ClientEmergencySignInOperation row in one transaction. The row is the only proof
#              that the session committed.
# 3. consume!  app_zenith: mark the credential used only after observing that proof row.
#
# A crash, rollback, or unknown outcome between the steps leaves the credential claimed. A claimed
# credential never verifies again, so it fails closed; consume!/reconcile! may only finish the same
# operation id, and only when its proof row exists. Nothing here un-claims a credential.
class ClientEmergencySecretCredentialSignInOperation
  SECRET_KIND = "temporary_access"
  USAGE_POLICY = "single_use"

  Claim = Data.define(:operation_id, :credential_public_id)
  Failure = Data.define(:reason)

  # Rejection raised when the caller asks to issue or consume for an operation it does not own.
  class OperationMismatch < StandardError; end

  class << self
    public

    def claim!(credential_public_id:, raw_secret:, now: Time.current)
      raise ArgumentError, "credential_public_id is required" if credential_public_id.blank?

      ClientSecretCredential.transaction do
        credential = ClientSecretCredential.lock.find_by(public_id: credential_public_id.to_s)
        next Failure.new(reason: :not_found) if credential.nil? || !emergency_credential?(credential)

        refusal = refusal_reason(credential, now)
        next Failure.new(reason: refusal) if refusal

        unless secret_matches?(credential, raw_secret)
          record_mismatch!(credential, now)
          next Failure.new(reason: :mismatch)
        end

        operation_id = SecureRandom.uuid
        credential.update!(claim_operation_id: operation_id, claimed_at: now)
        Claim.new(operation_id: operation_id, credential_public_id: credential.public_id)
      end
    end

    # Runs the caller's session-creating block and records the proof row in the same app_ticket
    # transaction. The block must create the ClientToken on the app_ticket connection and return it.
    def issue_session!(claim)
      raise ArgumentError, "a Claim is required" unless claim.is_a?(Claim)

      ClientEmergencySignInOperation.transaction do
        token = yield
        raise TypeError, "the session block must return a ClientToken" unless token.is_a?(ClientToken)

        ClientEmergencySignInOperation.create!(
          operation_id: claim.operation_id,
          credential_public_id: claim.credential_public_id,
          client_token: token,
        )
        token
      end
    end

    # Returns :consumed once the proof row exists (idempotent), :unconfirmed while it does not.
    def consume!(operation_id:, now: Time.current)
      raise ArgumentError, "operation_id is required" if operation_id.blank?

      ClientSecretCredential.transaction do
        credential = ClientSecretCredential.lock.find_by(claim_operation_id: operation_id.to_s)
        raise OperationMismatch, "no credential is claimed by this operation" if credential.nil?
        next :consumed if credential.consumed_at.present?

        proof = ClientEmergencySignInOperation.find_by(operation_id: operation_id.to_s)
        next :unconfirmed if proof.nil?
        raise OperationMismatch, "proof row names another credential" unless
          proof.credential_public_id == credential.public_id

        credential.update!(
          consumed_at: now,
          last_used_at: now,
          use_count: credential.use_count.to_i + 1,
          uses_remaining: 0,
          user_identity_secret_status_id: ClientSecretCredentialStatus::USED,
        )
        :consumed
      end
    end

    # Finishes a claimed credential whose session proof exists; otherwise it stays claimed.
    def reconcile!(credential_public_id:, now: Time.current)
      credential = ClientSecretCredential.find_by!(public_id: credential_public_id.to_s)
      return :unclaimed if credential.claim_operation_id.blank?

      consume!(operation_id: credential.claim_operation_id, now: now)
    end

    private

    def emergency_credential?(credential)
      credential.secret_kind == SECRET_KIND && credential.usage_policy == USAGE_POLICY
    end

    def refusal_reason(credential, now)
      return :claimed if credential.claim_operation_id.present?
      return :consumed if credential.consumed_at.present?
      return :revoked if credential.revoked_at.present?
      return :locked if credential.locked_at.present?
      return :inactive unless credential.active?
      return :not_before if credential.not_before_at.present? && now < credential.not_before_at
      # The expiry instant itself is already expired.
      return :expired if now >= credential.discard_at
      return :locked if credential.max_failures.present? && credential.failure_count >= credential.max_failures

      nil
    end

    def secret_matches?(credential, raw_secret)
      raw = raw_secret.to_s
      return false if raw.empty? || credential.lookup_digest.blank?

      expected = SignSecretLookupDigest.digest(raw)
      ActiveSupport::SecurityUtils.secure_compare(expected, credential.lookup_digest) &&
        credential.authenticate(raw).present?
    end

    # Only a credential mismatch counts toward max_failures.
    def record_mismatch!(credential, now)
      failures = credential.failure_count.to_i + 1
      attributes = { failure_count: failures, last_failed_at: now }
      attributes[:locked_at] = now if credential.max_failures.present? && failures >= credential.max_failures
      credential.update!(attributes)
    end
  end
end
