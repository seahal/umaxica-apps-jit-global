# frozen_string_literal: true

# Called by the future O-9 terminal transition while its OP transaction is open.
class SensitiveAdmissionAccountingWriter
  class << self
    public

    def call!(admission:, reason_code:)
      model, source_key =
        case admission
        when ClientSensitiveAdmission then [ClientSensitiveAdmissionAuditOutbox, "o9_app"]
        when OperatorSensitiveAdmission then [OperatorSensitiveAdmissionAuditOutbox, "o9_org"]
        else raise ArgumentError, "unsupported admission realm"
        end
      raise ArgumentError, "accounting requires an OP transaction" unless model.lease_connection.transaction_open?

      admission.lock!
      allowed =
        (admission.status == "redeemed") ? ["completed"] :
             ((admission.status == "cancelled") ? %w(expired user_cancelled) : [])
      raise ArgumentError, "admission is not closed" unless allowed.include?(reason_code)
      raise ArgumentError, "admission closure already recorded" if model.exists?(
        event_type: "sensitive_admission.closed", context_ref: admission.public_ref,
      )

      StepUpAuditOutboxWriter.call(
        source_key: source_key, event_type: "sensitive_admission.closed", realm: admission.realm.upcase,
        client_id: admission.client_id, subject_ref: admission.actor_subject, context_ref: admission.public_ref,
        reason_code: reason_code, payload: { admission_ref: admission.public_ref },
      )
    end
  end
end
