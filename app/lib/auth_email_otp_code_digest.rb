# frozen_string_literal: true

class AuthEmailOtpCodeDigest
  FIELDS = %w(surface purpose sid_digest parent_kind parent_ref mode contact_ref owner_ref
              destination_digest binding_fact generation).freeze

  class << self
    public

    def for(context:, code:)
      unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)
        raise ArgumentError, "email authentication OTP must contain six ASCII digits"
      end

      tuple = ["authentication.email_otp", *FIELDS.map { |field| context.fetch(field) }, code]
      key = Rails.application.key_generator.generate_key("auth_email_otp_code_digest", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, JSON.generate(tuple))
    end
  end
end
