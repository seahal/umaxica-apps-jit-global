# typed: false
# frozen_string_literal: true

require "jwt"

# Preference JWT encoding and decoding entry point.
class PreferenceToken
  JWT_ALGORITHM = SecurityJwtPreferenceTokenCodec::JWT_ALGORITHM
  TOKEN_TYPE = SecurityJwtPreferenceTokenCodec::TOKEN_TYPE
  AudienceMismatchError = SecurityJwtPreferenceTokenCodec::AudienceMismatchError

  class << self
    def encode(preferences, host:, preference_type:, public_id:, jti:, jwt_issuer_id: nil, issued_at: nil)
      codec.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
        jwt_issuer_id: jwt_issuer_id,
        issued_at: issued_at,
      )
    end

    def decode(token, host:, jwt_issuer_id: nil, raise_on_audience_mismatch: false)
      codec.decode(
        token,
        host: host,
        jwt_issuer_id: jwt_issuer_id,
        raise_on_audience_mismatch: raise_on_audience_mismatch,
      )
    end

    def extract_preferences(payload) = codec.extract_preferences(payload)

    def extract_public_id(payload) = codec.extract_public_id(payload)

    def extract_jti(payload) = codec.extract_jti(payload)

    private

    def codec
      SecurityJwtPreferenceTokenCodec
    end
  end
end
