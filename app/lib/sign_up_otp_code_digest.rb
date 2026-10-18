# frozen_string_literal: true

class SignUpOtpCodeDigest
  FIELDS = %w(surface purpose flow_ref nonce_digest owner_ref contact_ref destination_digest counter issued_at
              expires_at).freeze

  class << self
    public

    def for(context:, channel:, code:)
      unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)
        raise ArgumentError, "signup OTP must contain six ASCII digits"
      end

      tuple = ["sign_up.otp", channel.to_s, *FIELDS.map { |field| context.fetch(field) }, code]
      key = Rails.application.key_generator.generate_key("sign_up_otp_code_digest", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, JSON.generate(tuple))
    end
  end
end
