# frozen_string_literal: true

class TelephoneSignUpOtpDeliveryIssuer
  class DeliveryUnavailable < StandardError; end

  class << self
    public

    def call(flow:, telephone:, session_nonce:, initial_submission: false, actor_context: nil, after_commit: nil)
      unless flow.is_a?(ClientSignUpFlow) && telephone.is_a?(ClientTelephone)
        raise ArgumentError, "APP Telephone signup delivery requires its own flow and candidate"
      end
      if after_commit && (!initial_submission || !after_commit.is_a?(Proc))
        raise ArgumentError, "Telephone signup after-commit work requires an initial submission callback"
      end

      source_transaction_open =
        Client.connection_class_for_self.connected_to(role: :writing) do
          Client.lease_connection.transaction_open?
        end
      ticket_transaction_open =
        OpBaseAppRecord.connected_to(role: :writing) do
          ClientSignUpFlow.lease_connection.transaction_open?
        end
      if source_transaction_open || ticket_transaction_open
        raise DeliveryUnavailable, "Telephone signup delivery requires committed Source and Ticket changes"
      end

      issued = TelephoneSignUpOtpIssuer.call(
        flow: flow, telephone: telephone, session_nonce: session_nonce, initial_submission:, actor_context:,
      )
      return issued unless issued.success? || issued.status == :registered_destination

      after_commit&.call(issued)
      return issued if issued.status == :registered_destination

      authorized = TelephoneSignUpOtpDeliveryGuard.authorize_for_enqueue?(
        flow: flow, telephone: telephone, transaction: issued.transaction,
        generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
      )
      unless authorized
        return TelephoneSignUpOtpIssueResult.new(status: :delivery_refused, transaction: nil, code: nil)
      end

      delivery = OtpTelephoneAdapter.new(surface: :app).deliver(
        record: telephone, otp_code: issued.code, purpose: :sign_up, sign_up_flow_ref: flow.public_id,
        sign_up_telephone_transaction_ref: issued.transaction.transaction_id,
        sign_up_telephone_otp_generation: issued.transaction.otp_generation,
      )
      raise DeliveryUnavailable, "SMS delivery is unavailable" unless delivery.accepted?

      issued
    end
  end
end
