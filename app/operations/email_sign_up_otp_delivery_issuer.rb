# frozen_string_literal: true

class EmailSignUpOtpDeliveryIssuer
  class DeliveryUnavailable < StandardError; end

  class << self
    public

    def call(flow:, email:, session_nonce:, verification_token: nil, initial_submission: false, actor_context: nil,
             after_commit: nil)
      unless flow.is_a?(ClientSignUpFlow) && email.is_a?(ClientEmail)
        raise ArgumentError, "APP Email signup delivery requires its own flow and candidate"
      end
      if after_commit && (!initial_submission || !after_commit.is_a?(Proc))
        raise ArgumentError, "Email signup after-commit work requires an initial submission callback"
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
        raise DeliveryUnavailable, "Email signup delivery requires committed Source and Ticket changes"
      end

      issued = EmailSignUpOtpIssuer.call(
        flow: flow, email: email, session_nonce: session_nonce, initial_submission:, actor_context:,
      )
      return issued unless issued.success? || issued.status == :registered_destination

      after_commit&.call(issued)
      return issued if issued.status == :registered_destination

      notifier =
        case flow
        when ClientSignUpFlow then Notify::App::OtpNotifier
        else raise ArgumentError, "unsupported Email signup delivery realm"
        end
      notifier.issue(
        record: email, otp_code: issued.code, verification_token: verification_token,
        public_id: email.public_id, purpose: "sign_up", sign_up_flow_ref: flow.public_id,
        sign_up_email_transaction_ref: issued.transaction.transaction_id,
        sign_up_email_otp_generation: issued.transaction.otp_generation,
      )
      Chronicle.capture(
        action: "notification.delivery.email.enqueued", subject: email,
        metadata: { purpose: "sign_up" },
      )
      issued
    end
  end
end
