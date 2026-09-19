# typed: false
# frozen_string_literal: true

class SecurityJwtPreferenceTokenCodec
  JWT_ALGORITHM = SecurityJwtRfc9068AccessTokenProfile::ALGORITHM
  ACCESS_TOKEN_TTL = SecurityTokenLifetimes::PREFERENCE_JWT_TTL
  TOKEN_TYPE = SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE
  PREFERENCE_SCOPE = "preference"
  AudienceMismatchError = Class.new(StandardError)

  class << self
    def encode(preferences, host:, preference_type:, public_id:, jti:, jwt_issuer_id: nil)
      return nil unless valid_encode_params?(preferences, host, preference_type, public_id, jti)

      payload = build_payload(preferences, host, preference_type, public_id, jti)
      issuer_id = jwt_issuer_id.presence || "preference"
      JWT.encode(
        payload,
        jwt_private_key_for_active(issuer_id),
        JWT_ALGORITHM,
        { kid: jwt_active_kid(issuer_id), typ: TOKEN_TYPE, alg: JWT_ALGORITHM },
      )
    rescue JWT::EncodeError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.error(JitLogEvent.format("preference.token.encoding_failed", error_class: e.class.name))
      nil
    end

    def decode(token, host:, jwt_issuer_id: nil, raise_on_audience_mismatch: false)
      return nil if token.blank? || host.blank?

      header = jwt_configuration.parse_header(token)
      decode_verified_payload(
        token, host: host, header: header, jwt_issuer_id: jwt_issuer_id,
               raise_on_audience_mismatch: raise_on_audience_mismatch,
      )
    end

    def extract_preferences(payload)
      return {} unless payload.is_a?(Hash)

      payload["preferences"] || {}
    end

    def extract_public_id(payload)
      payload&.dig("public_id")
    end

    def extract_preference_type(payload)
      payload&.dig("preference_type")
    end

    def extract_jti(payload)
      payload&.dig("jti")
    end

    private

    def decode_verified_payload(token, host:, header:, jwt_issuer_id:, raise_on_audience_mismatch:)
      unless valid_header?(header)
        report_invalid_header(host: host, header: header)
        return nil
      end

      issuer_id = jwt_issuer_id.presence || "preference"
      public_key = resolve_public_key(header, issuer_id)
      if public_key.nil?
        JitSecurityJwtAnomalyReporter.report_preference(host: host, header: header, reason: "UNKNOWN_KID")
        return nil
      end

      payload, = JWT.decode(token, public_key, true, decode_options(host))
      validated_payload = validate_payload(payload, host)
      unless validated_payload
        report_invalid_payload(host: host, header: header, payload: payload)
        return nil
      end

      validated_payload
    rescue JWT::ExpiredSignature
      JitSecurityJwtAnomalyReporter.report_preference(host: host, header: header, reason: "EXPIRED")
      Rails.logger.debug("PreferenceToken.decode failed: token expired")
      nil
    rescue JWT::InvalidAudError => e
      report_audience_mismatch(host: host, header: header, token: token, error: e)
      Rails.logger.debug { "PreferenceToken.decode invalid audience: #{e.class}: #{e.message}" }
      raise AudienceMismatchError, e.message if raise_on_audience_mismatch

      nil
    rescue JWT::InvalidIssuerError, JWT::InvalidIatError, JWT::ImmatureSignature => e
      report_claim_error(host: host, header: header, error: e)
      Rails.logger.debug { "PreferenceToken.decode invalid claims: #{e.class}: #{e.message}" }
      nil
    rescue JWT::DecodeError, JWT::VerificationError => e
      report_decode_error(host: host, header: header, error: e)
      Rails.logger.debug { "PreferenceToken.decode invalid token: #{e.message}" }
      nil
    rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.error(JitLogEvent.format("preference.token.decoding_failed", error_class: e.class.name))
      nil
    end

    def jwt_active_kid(issuer_id)
      return jwt_configuration.active_kid if issuer_id == "preference"

      jwt_configuration.active_kid(issuer_id)
    end

    def jwt_private_key_for_active(issuer_id)
      return jwt_configuration.private_key_for_active if issuer_id == "preference"

      jwt_configuration.private_key_for_active(issuer_id)
    end

    def resolve_public_key(header, issuer_id)
      if issuer_id == "preference"
        jwt_configuration.public_key_for(header["kid"])
      else
        jwt_configuration.public_key_for(header["kid"], issuer_id: issuer_id)
      end
    end

    def valid_encode_params?(preferences, host, preference_type, public_id, jti)
      [preferences, host, preference_type, public_id, jti].all?(&:present?)
    end

    def build_payload(preferences, host, preference_type, public_id, jti)
      now = Time.current.to_i
      {
        "iss" => jwt_configuration.issuer,
        "exp" => now + Integer(ACCESS_TOKEN_TTL.to_s, 10),
        "aud" => jwt_configuration.audience_for(host),
        "sub" => public_id.to_s,
        "client_id" => jwt_configuration.client_id,
        "iat" => now,
        "nbf" => now,
        "jti" => jti,
        "scope" => PREFERENCE_SCOPE,
        "preferences" => preferences,
        "host" => jwt_configuration.host_scope_for(host),
        "preference_type" => preference_type,
        "public_id" => public_id,
      }
    end

    def decode_options(host)
      {
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud exp iat nbf sub client_id jti public_id preference_type scope),
        leeway: jwt_configuration.leeway_seconds,
        verify_iss: true,
        iss: jwt_configuration.issuer,
        verify_aud: true,
        aud: jwt_configuration.audience_for(host),
        verify_iat: true,
        verify_exp: true,
      }
    end

    def validate_payload(payload, host)
      return nil unless SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
      return nil unless payload["scope"] == PREFERENCE_SCOPE
      return nil unless host_matches?(payload["host"], host)
      return nil unless audience_matches?(payload["aud"], payload["host"])
      return nil unless payload["public_id"].is_a?(String) && payload["public_id"].present?
      return nil unless payload["preference_type"].is_a?(String) && payload["preference_type"].present?
      return nil unless payload["sub"] == payload["public_id"]

      payload
    end

    def valid_header?(header)
      SecurityJwtRfc9068AccessTokenProfile.header_valid?(header)
    end

    def report_invalid_header(host:, header:)
      JitSecurityJwtAnomalyReporter.report_preference(
        host: host,
        header: header,
        reason: SecurityJwtRfc9068AccessTokenProfile.header_rejection_reason(header),
      )
    end

    def report_invalid_payload(host:, header:, payload:)
      reason =
        if !SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
          "CLAIM_INVALID"
        elsif payload["host"].blank? || !host_matches?(payload["host"], host)
          "HOST_MISMATCH"
        elsif !audience_matches?(payload["aud"], payload["host"])
          "AUD_MISMATCH"
        else
          "OTHER"
        end

      JitSecurityJwtAnomalyReporter.report_preference(
        host: host,
        header: header,
        payload: payload,
        reason: reason,
      )
    end

    def report_claim_error(host:, header:, error:)
      reason =
        case error
        when JWT::InvalidIssuerError then "ISS_MISMATCH"
        when JWT::InvalidIatError then "IAT_INVALID"
        when JWT::ImmatureSignature then "IMMATURE"
        else "OTHER"
        end

      JitSecurityJwtAnomalyReporter.report_preference(
        host: host,
        header: header,
        reason: reason,
        error: error,
      )
    end

    def report_audience_mismatch(host:, header:, token:, error:)
      JitSecurityJwtAnomalyReporter.report_preference(
        host: host,
        header: header,
        payload: unverified_diagnostic_claims(token),
        reason: "AUD_MISMATCH",
        error: error,
      )
    end

    def unverified_diagnostic_claims(token)
      payload, = JWT.decode(token, nil, false)
      return {} unless payload.is_a?(Hash)

      payload.slice("iss", "aud", "jti")
    rescue JWT::DecodeError
      {}
    end

    def report_decode_error(host:, header:, error:)
      reason =
        if error.message.to_s.include?("Missing required claim")
          JitSecurityJwtAnomalyReporter.reason_for_missing_claim(error.message)
        elsif error.message.to_s.include?("Signature verification failed")
          "SIGNATURE_INVALID"
        elsif error.message.to_s.match?(/Not enough or too many segments|Invalid segment encoding/)
          "MALFORMED_TOKEN"
        else
          "DECODE_ERROR"
        end

      JitSecurityJwtAnomalyReporter.report_preference(
        host: host,
        header: header,
        reason: reason,
        error: error,
      )
    end

    # The host claim must be exactly the scope this request host would be
    # issued, and must share the request host's registrable domain. Either
    # check alone is too loose: the scope mapping is per-TLD, and the domain
    # check alone would accept any sibling host's token.
    def host_matches?(host_claim, host)
      return false unless host_claim.is_a?(String) && host_claim.present?

      host_claim == jwt_configuration.host_scope_for(host) &&
        registrable_domain(host_claim) == registrable_domain(host)
    end

    # `aud` must name the host scope itself, not merely a host in the same family.
    def audience_matches?(aud_claim, host_claim)
      normalize_audiences(aud_claim).include?(host_claim)
    end

    def registrable_domain(host)
      parts = host.to_s.split(".")
      return host.to_s if parts.length < 3

      parts.last(2).join(".")
    end

    def normalize_audiences(aud_claim)
      case aud_claim
      when Array then aud_claim
      when String then [aud_claim]
      else []
      end
    end

    def jwt_configuration
      PreferenceJwtConfiguration
    end
  end
end
