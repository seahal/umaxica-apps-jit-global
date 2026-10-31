# typed: false
# frozen_string_literal: true

require "base64"
require "json"

class SecurityJwtPreferenceTokenCodec
  JWT_ALGORITHM = SecurityJwtRfc9068AccessTokenProfile::ALGORITHM
  ACCESS_TOKEN_TTL = SecurityTokenLifetimes::PREFERENCE_JWT_TTL
  ANONYMOUS_COM_ACCESS_TOKEN_TTL = 400.days
  ANONYMOUS_COM_TOKEN_MAX_BYTES = 3 * 1024
  ANONYMOUS_ACCESS_TOKEN_TTL = ANONYMOUS_COM_ACCESS_TOKEN_TTL
  ANONYMOUS_TOKEN_MAX_BYTES = ANONYMOUS_COM_TOKEN_MAX_BYTES
  TOKEN_TYPE = SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE
  PREFERENCE_SCOPE = "preference"
  AudienceMismatchError = Class.new(StandardError)

  class << self
    def encode(preferences, host:, preference_type:, public_id:, jti:, jwt_issuer_id: nil, issued_at: nil)
      return nil unless valid_encode_params?(preferences, host, preference_type, public_id, jti)

      realm = anonymous_realm_for_preference_type(preference_type)
      if realm
        return nil unless anonymous_realm_host?(host, realm)
        return nil if jwt_issuer_id.present? && jwt_issuer_id != "preference_#{realm}"

        return encode_anonymous_realm(
          preferences, realm:, host:, public_id:, jti:, issued_at:,
        )
      end

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
      return nil unless token.is_a?(String) && token.present? && host.present?
      return nil if token.bytesize > ANONYMOUS_TOKEN_MAX_BYTES
      return nil unless unambiguous_json_segments?(token)

      if anonymous_realm_token_shape?(token)
        realm = anonymous_realm_for_host(host)
        return nil unless realm
        return nil if jwt_issuer_id.present? && jwt_issuer_id != "preference_#{realm}"

        return decode_anonymous_realm(
          token, realm:, raise_on_audience_mismatch:,
        )
      end

      # The former host/client/scope claim shape has no reader after the realm-cookie cutover.
      return nil if legacy_preference_claim_shape?(token)

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
      return unless payload.is_a?(Hash)
      return payload["public_id"].presence if payload["public_id"].present?

      # The realm-local anonymous shape carries the row id only in `sub`.
      return payload["sub"] if ANONYMOUS_REALMS.include?(payload["aud"]) && payload.key?("preferences")

      nil
    end

    def extract_preference_type(payload)
      payload&.dig("preference_type")
    end

    def extract_jti(payload)
      payload&.dig("jti")
    end

    public

    def valid_anonymous_display_snapshot?(preferences)
      anonymous_preference_keys_closed?(preferences) && preferences.keys.sort == ANONYMOUS_PREFERENCE_VALUES.keys.sort
    end

    private

    def unambiguous_json_segments?(token)
      segments = token.split(".", -1)
      return false unless segments.length == 3

      segments.first(2).all? do |segment|
        JSON.parse(Base64.urlsafe_decode64(segment), allow_duplicate_key: false).is_a?(Hash)
      end
    rescue JSON::ParserError, ArgumentError
      Rails.logger.info(JitLogEvent.format("preference.token.invalid_json"))
      false
    end

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

    # --- WU-7 section 4.2: the anonymous com writer claims shape -------------------
    # Wire values match the named com option records. Readers must validate without querying a DB.
    ANONYMOUS_PREFERENCE_VALUES = {
      "theme" => %w(light dark system),
      "language" => %w(ja en),
      "timezone" => %w(Etc/UTC Asia/Tokyo America/New_York America/Chicago America/Denver
                       America/Los_Angeles America/Anchorage Pacific/Honolulu),
      "currency" => %w(usd jpy),
      "date_format" => %w(iso uk us),
      "time_format" => %w(24 12),
      "motion" => %w(standard reduced),
      "density" => %w(standard compact),
      "page_size" => %w(10 20 50 100 infinity),
    }.freeze

    ANONYMOUS_REALMS = %w(app com org).freeze
    ANONYMOUS_CLAIMS = %w(iss sub aud iat exp jti preferences).freeze

    def anonymous_realm_for_preference_type(preference_type)
      case preference_type
      when "AppPreference" then "app"
      when "ComPreference" then "com"
      when "OrgPreference" then "org"
      else
        raise ArgumentError, "unsupported anonymous preference model: #{preference_type.inspect}"
      end
    end

    def anonymous_realm_for_host(host)
      return unless host.is_a?(String) && host.present?

      local_realm = local_anonymous_realm_for_host(host)
      return local_realm if local_realm.present?

      configured_anonymous_realm_for_host(host)
    end

    def local_anonymous_realm_for_host(host)
      return unless Rails.env.local?

      %w(app com org).find do |realm|
        host == "#{realm}.localhost" || host.end_with?(".#{realm}.localhost")
      end
    end

    def configured_anonymous_realm_for_host(host)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      realm_hosts = {
        "app" => hosts.base_service&.host,
        "com" => hosts.base_corporate&.host,
        "org" => hosts.base_staff&.host,
      }
      matched =
        realm_hosts.filter_map do |realm, configured_host|
          next if configured_host.blank?

          realm if registrable_domain(host) == registrable_domain(configured_host)
        end
      return if matched.length > 1

      matched.first
    end

    def anonymous_realm_host?(host, realm)
      anonymous_realm_for_host(host) == realm
    end

    def anonymous_realm_token_shape?(token)
      payload, = JWT.decode(token, nil, false)
      payload.is_a?(Hash) && payload.key?("preferences") &&
        payload.exclude?("client_id") && payload.exclude?("preference_type")
    rescue JWT::DecodeError, NameError
      false
    end

    def legacy_preference_claim_shape?(token)
      payload, = JWT.decode(token, nil, false)
      payload.is_a?(Hash) && payload.key?("preferences") &&
        (payload.key?("preference_type") || payload.key?("client_id") || payload.key?("scope"))
    rescue JWT::DecodeError, NameError
      false
    end

    def encode_anonymous_realm(preferences, realm:, host:, public_id:, jti:, issued_at:)
      validate_anonymous_preference_keys!(preferences)
      raise ArgumentError, "anonymous preference issuance time is required" unless issued_at.acts_like?(:time)
      raise ArgumentError, "unsupported anonymous preference realm" unless ANONYMOUS_REALMS.include?(realm)
      unless anonymous_realm_host?(host, realm)
        raise ArgumentError, "preference token host does not belong to its realm"
      end

      now = issued_at.to_i
      issuer_id = "preference_#{realm}"
      token_payload = {
        "iss" => jwt_configuration.issuer_for(issuer_id),
        "sub" => public_id.to_s,
        "aud" => realm,
        "iat" => now,
        "exp" => now + ANONYMOUS_COM_ACCESS_TOKEN_TTL.to_i,
        "jti" => jti,
        "preferences" => preferences,
      }
      token = JWT.encode(
        token_payload, jwt_configuration.private_key_for_active(issuer_id), JWT_ALGORITHM,
        { kid: jwt_configuration.active_kid(issuer_id), typ: TOKEN_TYPE, alg: JWT_ALGORITHM },
      )
      if token.bytesize > ANONYMOUS_TOKEN_MAX_BYTES
        raise ArgumentError, "anonymous preference token exceeds size limit"
      end

      token
    rescue JWT::EncodeError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.error(JitLogEvent.format("preference.token.encoding_failed", error_class: e.class.name))
      nil
    end

    def validate_anonymous_preference_keys!(preferences)
      closed = valid_anonymous_display_snapshot?(preferences)
      return if closed

      raise ArgumentError, "anonymous preference payload keys or values are outside the closed contract"
    end

    def decode_anonymous_realm(token, realm:, raise_on_audience_mismatch:)
      issuer_id = "preference_#{realm}"
      host = realm
      header = jwt_configuration.parse_header(token)
      unless valid_header?(header)
        report_invalid_header(host:, header:)
        return nil
      end

      public_key = resolve_public_key(header, issuer_id)
      if public_key.nil?
        JitSecurityJwtAnomalyReporter.report_preference(host:, header:, reason: "UNKNOWN_KID")
        return nil
      end

      payload, = JWT.decode(token, public_key, true, anonymous_decode_options(issuer_id, realm))
      return nil unless anonymous_realm_claims_valid?(payload, realm:)

      payload
    rescue JWT::ExpiredSignature
      JitSecurityJwtAnomalyReporter.report_preference(host:, header: {}, reason: "EXPIRED")
      nil
    rescue JWT::InvalidAudError => e
      report_audience_mismatch(host:, header: {}, token: token, error: e)
      raise AudienceMismatchError, e.message if raise_on_audience_mismatch

      nil
    rescue JWT::InvalidIssuerError, JWT::InvalidIatError, JWT::ImmatureSignature, JWT::MissingRequiredClaim => e
      report_claim_error(host:, header: {}, error: e)
      nil
    rescue JWT::DecodeError, JWT::VerificationError => e
      report_decode_error(host:, header: {}, error: e)
      nil
    rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.error(JitLogEvent.format("preference.token.decoding_failed", error_class: e.class.name))
      nil
    end

    def anonymous_decode_options(issuer_id, realm)
      {
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud exp iat jti sub preferences),
        leeway: 0,
        verify_iss: true,
        iss: jwt_configuration.issuer_for(issuer_id),
        aud: realm,
        verify_aud: true,
        verify_iat: { leeway: jwt_configuration.leeway_seconds },
        verify_expiration: true,
      }
    end

    def anonymous_preference_keys_closed?(preferences)
      preferences.is_a?(Hash) &&
        preferences.all? { |key, value| ANONYMOUS_PREFERENCE_VALUES.fetch(key, []).include?(value) }
    end

    def anonymous_realm_claims_valid?(payload, realm:)
      return false unless payload.is_a?(Hash) && payload.keys.sort == ANONYMOUS_CLAIMS.sort
      return false unless %w(iss sub jti).all? { |key| payload[key].is_a?(String) && payload[key].present? }
      return false unless payload["aud"] == realm
      return false unless payload["iat"].is_a?(Integer) && payload["exp"].is_a?(Integer)
      return false unless payload["exp"] > payload["iat"]
      return false if payload["exp"] - payload["iat"] > ANONYMOUS_ACCESS_TOKEN_TTL.to_i

      valid_anonymous_display_snapshot?(payload["preferences"])
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
        verify_iat: { leeway: jwt_configuration.leeway_seconds },
        verify_expiration: true,
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
