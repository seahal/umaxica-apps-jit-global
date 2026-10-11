# typed: false
# frozen_string_literal: true

class SecurityJwtOidcIdTokenCodec
  JWT_ALGORITHM = "ES384"
  TOKEN_TTL = SecurityTokenLifetimes::OIDC_ID_TOKEN_TTL
  TOKEN_TYPE = "id-token+jwt"

  class << self
    def encode(payload, issuer_id:)
      JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
    end

    def decode(id_token:, client_id:, resource_type:, jwt_issuer_id:, issuer:)
      header = JitSecurityJwtKeyring.parse_header(id_token)
      raise JWT::DecodeError, "invalid header" unless header["alg"] == JWT_ALGORITHM
      raise JWT::DecodeError, "invalid typ" unless header["typ"] == TOKEN_TYPE

      public_key = JitSecurityJwtKeyring.public_key_for(
        header["kid"],
        issuer_id: jwt_issuer_id,
      )
      raise JWT::DecodeError, "unknown kid" unless public_key

      payload, = JWT.decode(
        id_token,
        public_key,
        true,
        decode_options(client_id: client_id, resource_type: resource_type, issuer: issuer),
      )
      raise JWT::DecodeError, "invalid payload typ" unless payload["typ"] == TOKEN_TYPE
      raise JWT::DecodeError, "invalid act" unless payload["act"] == resource_type

      payload
    end

    def build_payload(resource:, client:, nonce:, issued_at:, expires_at:, acr:, amr:, issuer:, subject:, sid:,
                      auth_time:, step_up_until:)
      issued_at = normalize_time!(issued_at)
      expires_at = normalize_time!(expires_at)
      raise ArgumentError, "invalid id token time ordering" if issued_at > expires_at

      token_resource_type = resource_type_for_resource(resource)
      {
        "iss" => issuer.presence || OidcIssuer.for_client(client),
        "sub" => subject.presence || OidcSubject.for(resource, resource_type: token_resource_type),
        "aud" => [client.client_id],
        "exp" => expires_at.to_i,
        "iat" => issued_at.to_i,
        "nbf" => issued_at.to_i,
        "jti" => JitSecurityJwtJtiGenerator.generate,
        "typ" => TOKEN_TYPE,
        "act" => token_resource_type,
        "sid" => sid.presence || SecureRandom.urlsafe_base64(18),
        "nonce" => nonce,
        "acr" => acr.presence || "aal1",
      }.tap do |claims|
        claims["amr"] = Array(amr) if amr.present?
        claims["auth_time"] = Integer(auth_time.to_i) if auth_time.present?
        claims["step_up_until"] = Integer(step_up_until.to_i) if step_up_until.present?
      end
    end

    def resource_type_for_client(client)
      return "operator" if %w(operator staff).include?(client.resource_type)
      return "visitor" if %w(visitor customer).include?(client.resource_type)

      "client"
    end

    def resource_type_for_resource(resource)
      case resource
      when ::Operator then "operator"
      when ::Visitor then "visitor"
      else "client"
      end
    end

    def decode_options(client_id:, resource_type:, issuer:)
      {
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud exp iat nbf sub nonce jti typ act),
        leeway: AuthenticationJwtConfiguration.leeway_seconds,
        verify_iat: true,
        verify_exp: true,
        verify_nbf: true,
        verify_iss: true,
        iss: issuer.presence || OidcIssuer.for_resource_type(resource_type),
        verify_aud: true,
        aud: client_id,
      }
    end

    def normalize_time!(value)
      case value
      when Time, ActiveSupport::TimeWithZone
        value.utc
      else
        Time.at(value.to_i).utc
      end
    end
  end
end
