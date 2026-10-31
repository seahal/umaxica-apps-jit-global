# typed: false
# frozen_string_literal: true

module PreferenceAccessTokenTransport
  extend ActiveSupport::Concern

  private

  def load_access_token_payload
    # Request-local memo: the decoded payload is the canonical per-request
    # cache. It is set here and by matching_access_token_value, and is reset to
    # nil when invalidated (keep_loaded_access_token_payload?, preference_core
    # reset). Once present, re-scanning cookies and re-verifying the JWT only
    # reproduces the same payload, so short-circuit. Cookies are request input
    # and do not change within a request.
    return true if @preference_payload.is_a?(Hash)
    # A detached credential stays detached for the whole request: re-scanning the cookies would
    # resurrect the payload that the refusal just dropped.
    return false if preference_credential_detached?

    token = matching_access_token_value
    return false if token.blank?

    # matching_access_token_value decodes the matched cookie and assigns
    # @preference_payload for the token it returns. Re-decoding the identical
    # token here would re-run JWT signature verification for no gain, so reuse
    # the payload it already produced.
    @preference_payload.is_a?(Hash)
  end

  def load_access_token_preference_record!
    return @preferences if @preferences.present?
    return unless @preference_payload.is_a?(Hash) || load_access_token_payload

    public_id = PreferenceToken.extract_public_id(@preference_payload)
    return if public_id.blank?

    operation =
      lambda do
        role = anonymous_preference_claim_shape?(preference_class) ? :reading : :writing
        with_preference_connection(role) do
          if anonymous_preference_claim_shape?(preference_class)
            relation = preference_class.includes(preference_associations_to_preload)
            preference = relation.find_by(public_id: public_id)
            if preference&.status_id == preference_class::ACTIVE_STATUS_ID &&
                preference.issuance_active_at?(now: preference_class.database_now)
              preference
            end
          else
            preference_class.unconsumed.includes(preference_associations_to_preload)
              .active.find_by(public_id: public_id)
          end
        end
      end
    @preferences = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    @preferences
  end

  def preference_access_token_current?(preference, payload)
    current_jti = preference&.jti
    return true if current_jti.blank?

    payload_jti = PreferenceToken.extract_jti(payload)
    return false if payload_jti.blank?

    secure_compare?(current_jti, payload_jti)
  end

  def matching_access_token_value
    return if preference_credential_detached?

    access_token_cookie_names.lazy.filter_map do |cookie_name|
      token = BrowserCredentialCookie.read(cookies, cookie_name).to_s.presence
      next if token.blank?

      payload = decode_matching_access_token(token)
      next if payload.blank?

      @preference_payload = payload
      token
    end.first
  rescue PreferenceBase::ResolutionError
    raise unless anonymous_preference_claim_shape?(preference_class) && (request.get? || request.head?)

    detach_preference_credential!
    nil
  end

  def decode_matching_access_token(token)
    if anonymous_preference_claim_shape?(preference_class) && token.to_s.bytesize >
        SecurityJwtPreferenceTokenCodec::ANONYMOUS_TOKEN_MAX_BYTES
      return nil
    end

    payload = PreferenceToken.decode(token, host: request.host, jwt_issuer_id: preference_jwt_issuer_id)
    return if payload.blank?

    # The anonymous shape omits preference_type, so check the receiving model explicitly.
    if payload["preference_type"].blank? &&
        SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALMS.include?(payload["aud"])
      return payload if anonymous_preference_claim_shape?(preference_class) &&
        payload["aud"] == preference_realm_name

      return nil
    end
    return nil if anonymous_preference_claim_shape?(preference_class)
    return if PreferenceToken.extract_preference_type(payload) != preference_class.name

    payload
  rescue JitSecurityJwtRegistry::ConfigurationError => e
    raise_preference_resolution_error!(:verification_configuration, e)
  end

  def ensure_preference_access_token_audience_for_write!
    access_token_cookie_names.each do |cookie_name|
      token = BrowserCredentialCookie.read(cookies, cookie_name).to_s.presence
      next if token.blank?

      PreferenceToken.decode(
        token,
        host: request.host,
        jwt_issuer_id: preference_jwt_issuer_id,
        raise_on_audience_mismatch: true,
      )
    end
  end

end
