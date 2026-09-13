# typed: false
# frozen_string_literal: true

# Backward-compatible facade for Auth access JWTs.
#
# JWT encode/decode behavior lives in `SecurityJwtAuthAccessTokenCodec`;
# this service keeps the existing public API used by controllers and OIDC services.
class AuthenticationTokenService
  JWT_ALGORITHM = SecurityJwtAuthAccessTokenCodec::JWT_ALGORITHM
  VALID_RESOURCE_TYPES = SecurityJwtAuthAccessTokenCodec::VALID_RESOURCE_TYPES

  class << self
    def encode(...)
      codec.encode(...)
    end

    def decode(...)
      codec.decode(...)
    end

    def decode_allow_expired(...)
      codec.decode_allow_expired(...)
    end

    def extract_session_id_allow_expired(...)
      codec.extract_session_id_allow_expired(...)
    end

    def extract_subject(payload)
      AuthorizationTokenClaims.subject(payload)
    end

    def extract_resource_type(payload)
      AuthorizationTokenClaims.resource_type(payload)
    end

    def extract_session_id(payload)
      AuthorizationTokenClaims.session_id(payload)
    end

    def extract_jti(payload)
      AuthorizationTokenClaims.jti(payload)
    end

    def resource_type_scope_matches?(payload, expected_resource_type)
      codec.resource_type_scope_matches?(payload, expected_resource_type)
    end

    def extract_scopes(payload)
      AuthorizationTokenClaims.scopes(payload)
    end

    def has_scope?(payload, scope)
      scopes = extract_scopes(payload)
      scopes.include?(scope.to_s)
    end

    private

    def codec
      SecurityJwtAuthAccessTokenCodec
    end
  end
end
