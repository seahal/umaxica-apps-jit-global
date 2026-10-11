# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require "jwt"

class SecurityJwtAuthAccessTokenCodec
  JWT_ALGORITHM = SecurityJwtRfc9068AccessTokenProfile::ALGORITHM
  TOKEN_TYPE = SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE
  VALID_RESOURCE_TYPES = %w(client operator visitor).freeze
  # Keyring used when a caller does not name one. Callers that sign or verify
  # with a surface keyring must pass `jwt_issuer_id:` explicitly; the keyring is
  # never inferred from the request host.
  DEFAULT_JWT_ISSUER_ID = "auth"

  class << self
    def encode(resource, host:, resource_type: nil, dpop_jkt: nil, expires_at: nil,
               session_public_id: nil, session_id: nil, oidc_sid: nil, oidc_jti: nil, scopes: nil, acr: nil,
               amr: nil, access_token_ttl: SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL,
               jwt_issuer_id: nil, issuer: nil, audiences: nil,
               subject: nil, auth_time: nil, step_up_until: nil, client_id: nil,
               authentication_context: nil)
      resource_type ||=
        case resource
        when ::Client then "client"
        when ::Operator then "operator"
        when ::Visitor then "visitor"
        end

      return nil unless valid_encode_params?(resource, host)

      oidc_jti ||= oidc_jti_for_session(resource_type, session_public_id)

      issued_at = Time.current
      payload = AuthorizationTokenClaims.build(
        resource: resource,
        session_id: session_id,
        session_public_id: session_public_id,
        oidc_sid: oidc_sid,
        oidc_jti: oidc_jti,
        resource_type: resource_type,
        issued_at: issued_at,
        access_token_ttl: access_token_ttl,
        expires_at: expires_at,
        scopes: scopes,
        acr: acr,
        amr: amr,
        dpop_jkt: dpop_jkt,
        issuer: issuer,
        audiences: audiences,
        subject: subject,
        auth_time: auth_time,
        step_up_until: step_up_until,
        client_id: client_id,
        authentication_context: authentication_context,
      )

      JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: resolve_jwt_issuer_id(jwt_issuer_id))
    rescue JWT::EncodeError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.error(
        JitLogEvent.format(
          "authentication.token.encoding.error",
          error_class: e.class.name,
          message: e.message,
          resource_type: resource_type,
          resource_id: resource&.id,
        ),
      )
      nil
    end

    def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      decode_with_expiration(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, verify_exp: true, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def decode_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      decode_with_expiration(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, verify_exp: false, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil,
                                         jwt_issuer_id: nil)
      payload = decode_allow_expired(
        token, host: host, resource_type: resource_type,
               issuer: issuer, audiences: audiences, jwt_issuer_id: jwt_issuer_id,
      )
      AuthorizationTokenClaims.session_id(payload) if payload.present?
    end

    def decode_with_expiration(token, host:, resource_type: nil, issuer: nil, audiences: nil, verify_exp:,
                               jwt_issuer_id: nil)
      return nil if token.blank? || host.blank?

      header = JitSecurityJwtKeyring.parse_header(token)
      unless valid_header?(header)
        report_invalid_header(resource_type: resource_type, host: host, header: header)
        return nil
      end

      public_key = JitSecurityJwtKeyring.public_key_for(header["kid"], issuer_id: resolve_jwt_issuer_id(jwt_issuer_id))
      if public_key.nil?
        JitSecurityJwtAnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "UNKNOWN_KID",
        )
        return nil
      end

      payload, = JWT.decode(
        token, public_key, true,
        decode_options(resource_type, issuer, audiences, verify_exp: verify_exp),
      )
      unless SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
        JitSecurityJwtAnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          payload: payload,
          reason: "CLAIM_INVALID",
        )
        return nil
      end

      payload
    rescue JWT::ExpiredSignature
      return nil unless verify_exp

      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "EXPIRED",
      )
      Rails.logger.info(JitLogEvent.format("authentication.token.verification.expired", host: host))
      nil
    rescue JWT::InvalidIssuerError, JWT::InvalidAudError, JWT::InvalidIatError, JWT::ImmatureSignature => e
      report_claim_error(resource_type: resource_type, host: host, header: header, error: e)
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.claim_invalid",
          error_class: e.class.name,
          host: host,
        ),
      )
      nil
    rescue JWT::DecodeError, JWT::VerificationError => e
      report_decode_error(resource_type: resource_type, host: host, header: header, error: e)
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.failed",
          error_class: e.class.name,
          host: host,
        ),
      )
      nil
    rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.error",
          error_class: e.class.name,
          error_message: e.message,
          host: host,
        ),
      )
      nil
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

    # The resource type is carried by exactly one `domain:<type>` scope value,
    # not by the RFC 8693 `act` claim.
    def resource_type_scope_matches?(payload, expected_resource_type)
      return false if payload.blank?

      resource_type = extract_resource_type(payload)
      return false unless VALID_RESOURCE_TYPES.include?(resource_type)

      resource_type == expected_resource_type.to_s
    end

    def extract_scopes(payload)
      AuthorizationTokenClaims.scopes(payload)
    end

    def has_scope?(payload, scope)
      scopes = extract_scopes(payload)
      scopes.include?(scope.to_s)
    end

    private

    def valid_encode_params?(resource, host)
      return false if resource.nil? || host.blank?

      # Ensure resource is Client, Operator or Visitor
      resource.is_a?(::Client) || resource.is_a?(::Operator) || resource.is_a?(::Visitor)
    end

    def oidc_jti_for_session(resource_type, session_public_id)
      return nil if resource_type.blank? || session_public_id.blank?

      token_class = token_class_for_resource_type(resource_type)
      return nil unless token_class&.column_names&.include?("oidc_jti")

      lookup = lambda { token_class.where(public_id: session_public_id).pick(:oidc_jti) }
      token_connection_owner(token_class).connected_to(role: :writing, &lookup)
    end

    def token_class_for_resource_type(resource_type)
      case resource_type.to_s
      when "client" then ::ClientToken
      when "operator" then ::OperatorToken
      when "visitor" then ::VisitorToken
      end
    end

    def resolve_jwt_issuer_id(jwt_issuer_id)
      jwt_issuer_id.presence || DEFAULT_JWT_ISSUER_ID
    end

    def token_connection_owner(token_class)
      klass = token_class
      klass = klass.superclass until klass.connection_class?
      klass
    end

    def decode_options(resource_type, issuer, audiences, verify_exp:)
      {
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud exp nbf iat sub sid client_id jti acr scope),
        leeway: AuthenticationJwtConfiguration.leeway_seconds,
        verify_iat: true,
        verify_exp: verify_exp,
        verify_nbf: true,
        verify_iss: true,
        iss: issuer || AuthenticationJwtConfiguration.issuer,
        verify_aud: true,
        aud: audiences || AuthenticationJwtConfiguration.audiences(resource_type),
      }
    end

    def valid_header?(header)
      SecurityJwtRfc9068AccessTokenProfile.header_valid?(header)
    end

    def report_invalid_header(resource_type:, host:, header:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: SecurityJwtRfc9068AccessTokenProfile.header_rejection_reason(header),
      )
    end

    def report_claim_error(resource_type:, host:, header:, error:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "CLAIM_INVALID",
        error: error,
      )
    end

    def report_decode_error(resource_type:, host:, header:, error:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "DECODE_FAILED",
        error: error,
      )
    end
  end
end

# rubocop:enable Metrics/MethodLength
