# frozen_string_literal: true

class TelephoneSignUpOtpDeliveryIssuer
  class << self
    public

    def call(flow:, telephone:, session_nonce:)
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: session_nonce)
      return issued unless issued.success?

      surface =
        case flow
        when ClientSignUpFlow then :app
        when VisitorSignUpFlow then :com
        else raise ArgumentError, "unsupported Telephone signup delivery realm"
        end
      accepted = false
      current =
        TelephoneSignUpOtpDeliveryGuard.call(
          flow: flow, telephone: telephone, transaction: issued.transaction,
          generation: issued.transaction.otp_generation, destination: telephone.number, code: issued.code,
        ) do
          delivery = OtpTelephoneAdapter.new(surface: surface).deliver(
            record: telephone, otp_code: issued.code, purpose: :sign_up, sign_up_flow_ref: flow.public_id,
            sign_up_telephone_transaction_ref: issued.transaction.transaction_id,
            sign_up_telephone_otp_generation: issued.transaction.otp_generation,
          )
          accepted = delivery.accepted?
        end
      return issued if current && accepted

      TelephoneSignUpOtpIssueResult.new(status: :delivery_refused, transaction: nil, code: nil)
    end
  end
end
