# typed: false
# frozen_string_literal: true

# Thin facade over `AuthenticationTokenService` for the encode /
# decode / claim-extraction operations. Lives here (and not in
# `AuthenticationTokenService` itself) so callers can name the high-level operation
# without coupling to the service's internal structure.
#
# Previously a nested class inside `AuthenticationBase`. Extracted
# for the same reason as `AuthenticationJwtConfiguration`. Existing references via
# `AuthenticationToken` keep working through the alias defined
# in `AuthenticationBase`.
class AuthenticationToken
  JWT_ALGORITHM = "ES384"

  class << self
    def encode(resource, host:, session_public_id: nil, session_id: nil, oidc_sid: nil, oidc_jti: nil,
               resource_type: nil, dpop_jkt: nil, expires_at: nil, acr: nil, amr: nil, jwt_issuer_id: nil,
               authentication_context: nil)
      AuthenticationTokenService.encode(
        resource, host: host, session_public_id: session_public_id, session_id: session_id,
                  oidc_sid: oidc_sid, oidc_jti: oidc_jti, resource_type: resource_type, dpop_jkt: dpop_jkt,
                  expires_at: expires_at, acr: acr, amr: amr, jwt_issuer_id: jwt_issuer_id,
                  authentication_context: authentication_context,
      )
    end

    def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      AuthenticationTokenService.decode(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_subject(payload)
      AuthenticationTokenService.extract_subject(payload)
    end

    def extract_resource_type(payload)
      AuthenticationTokenService.extract_resource_type(payload)
    end

    def resource_type_scope_matches?(payload, expected_resource_type)
      AuthenticationTokenService.resource_type_scope_matches?(payload, expected_resource_type)
    end

    def extract_session_id(payload)
      AuthenticationTokenService.extract_session_id(payload)
    end

    def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil,
                                         jwt_issuer_id: nil)
      AuthenticationTokenService.extract_session_id_allow_expired(
        token,
        host: host,
        resource_type: resource_type,
        issuer: issuer,
        audiences: audiences,
        jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_jti(payload)
      AuthenticationTokenService.extract_jti(payload)
    end
  end
end
