# typed: false
# frozen_string_literal: true

require "jwt"

# Backward-compatible facade for preference JWT access tokens.
#
# PreferenceToken encoding/decoding lives in `SecurityJwtPreferenceTokenCodec`;
# this class keeps the existing public API.
class PreferenceToken
  JWT_ALGORITHM = SecurityJwtPreferenceTokenCodec::JWT_ALGORITHM
  ACCESS_TOKEN_TTL = SecurityJwtPreferenceTokenCodec::ACCESS_TOKEN_TTL
  TOKEN_TYPE = SecurityJwtPreferenceTokenCodec::TOKEN_TYPE
  AudienceMismatchError = SecurityJwtPreferenceTokenCodec::AudienceMismatchError

  class << self
    def encode(preferences, host:, preference_type:, public_id:, jti:, jwt_issuer_id: nil)
      codec.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
        jwt_issuer_id: jwt_issuer_id,
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

    def extract_preference_type(payload) = codec.extract_preference_type(payload)

    def extract_jti(payload) = codec.extract_jti(payload)

    private

    def codec
      SecurityJwtPreferenceTokenCodec
    end
  end
end
