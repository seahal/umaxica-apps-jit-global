# frozen_string_literal: true

class SignUpOtpDeliveryIssuer
  class << self
    public

    def call(flow:, record:, channel:, verification_token: nil)
      surface =
        case flow
        when ClientSignUpFlow then :app
        when VisitorSignUpFlow then :com
        else raise ArgumentError, "unsupported signup OTP delivery realm"
        end
      otp = record.get_otp
      return false unless otp

      counter = otp.fetch(:otp_counter).to_s
      code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
      destination = (channel.to_sym == :email) ? record.address : record.number
      enqueued = false
      SignUpOtpDeliveryGuard.call(
        flow: flow, channel: channel, contact_ref: record.public_id,
        counter: counter, destination: destination, code: code,
      ) do
        next false unless SignUpOtpChallengeRecorder.call(flow: flow, record: record, channel: channel, code: code)

        OtpAdapter.for(surface: surface, channel: channel).deliver(
          record: record, otp_code: code, purpose: :sign_up,
          public_id: record.public_id, verification_token: verification_token,
          sign_up_flow_ref: flow.public_id, sign_up_otp_counter: counter,
        )
        enqueued = true
      end
      enqueued
    end
  end
end
