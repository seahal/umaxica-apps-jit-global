# frozen_string_literal: true

class SignUpOtpChallengeRecorder
  class << self
    public

    def call(flow:, record:, channel:, code:)
      surface, owner =
        case flow
        when ClientSignUpFlow then ["app", record.user]
        when VisitorSignUpFlow then ["com", record.visitor]
        else raise ArgumentError, "unsupported signup OTP challenge realm"
        end
      return false if record.sign_up_otp_context&.fetch("verified_at")

      destination = (channel.to_sym == :email) ? record.address : record.number
      SignUpOtpDeliveryGuard.call(
        flow: flow, channel: channel, contact_ref: record.public_id,
        counter: record.otp_counter.to_s, destination: destination, code: code,
      ) do
        now = record.class.database_now
        context = {
          "version" => 1,
          "surface" => surface,
          "purpose" => "sign_up",
          "flow_ref" => flow.public_id,
          "nonce_digest" => flow.nonce_digest,
          "owner_ref" => owner.public_id,
          "contact_ref" => record.public_id,
          "destination_digest" => (channel.to_sym == :email) ? record.address_digest : record.number_digest,
          "counter" => record.otp_counter.to_s,
          "issued_at" => now.utc.iso8601(6),
          "expires_at" => record.otp_expires_at.utc.iso8601(6),
          "verified_at" => nil,
          "result_expires_at" => nil,
        }
        context["code_digest"] = SignUpOtpCodeDigest.for(context: context, channel: channel, code: code)
        record.update!(sign_up_otp_context: context)
      end
    end
  end
end
