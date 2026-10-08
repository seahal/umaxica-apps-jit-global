# frozen_string_literal: true

class EmailSignUpOtpDeliveryIssuer
  class << self
    public

    def call(flow:, email:, session_nonce:, verification_token: nil)
      issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: session_nonce)
      return issued unless issued.success?

      notifier =
        case flow
        when ClientSignUpFlow then Notify::App::OtpNotifier
        when VisitorSignUpFlow then Notify::Com::OtpNotifier
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
