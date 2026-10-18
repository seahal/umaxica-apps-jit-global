# frozen_string_literal: true

class OperatorTelephoneLegacyReferenceInventory
  class << self
    public

    def call(scope:)
      unless scope.is_a?(ActiveRecord::Relation) && scope.klass == OperatorTelephoneCeremonyTransaction
        raise ArgumentError, "legacy reference inventory requires an explicit ORG Telephone ceremony scope"
      end

      OperatorTelephoneCeremonyTransaction.connection_owner.connected_to(role: :writing) do
        now = OperatorTelephoneCeremonyTransaction.database_now
        legacy = scope.where(operation: "registration")
          .where("telephone_candidate_ref ~ ?", "^[1-9][0-9]{0,18}$")
          .where("expires_at > ?", now)
        pending = legacy.where(status: "pending", consumed_at: nil, otp_cancelled_at: nil)
        proofs = pending.where(purpose: "credential_registration", otp_consumed_at: nil)
          .where.not(otp_verifier: nil).where("otp_expires_at > ?", now)
        receipts = legacy.where(purpose: "credential_registration", otp_cancelled_at: nil)
          .where.not(otp_receipt_verifier: nil)
          .where("otp_consumed_at <= ? AND otp_result_expires_at > ?", now, now)

        # Aggregate observations, not authorization or proof of writer/queue quiescence.
        { pending_ceremonies: pending.count,
          deliverable_proofs: proofs.count,
          unexpired_receipts: receipts.count, }.freeze
      end
    end
  end
end
