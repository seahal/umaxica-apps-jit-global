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

  def load_access_token_preference_record!(clear_invalid_cookie: true)
    return @preferences if @preferences.present?
    return unless @preference_payload.is_a?(Hash) || load_access_token_payload

    public_id = PreferenceToken.extract_public_id(@preference_payload)
    return if public_id.blank?

    operation =
      lambda do
        with_preference_connection(:writing) do
          # Scoped to `active.unconsumed` (both already defined by
          # SingleUseToken, included on AppPreference/ComPreference/
          # OrgPreference): a discarded/expired row or a `used_at`-consumed
          # row (retired by PreferenceSignOutRotation, or superseded by
          # ordinary refresh rotation) must not be resurrected merely
          # because a still-signature-valid, still-unexpired access JWT
          # naming its public_id is presented. Without this, a 7-day
          # PREFERENCE_JWT_TTL access token issued before sign-out would
          # keep resolving to the retired row for up to 7 days after
          # retirement -- the DB-side retirement would exist but not
          # actually be enforced at the access-token verification layer.
          preference_class.active.unconsumed.includes(preference_associations_to_preload)
            .find_by(public_id: public_id)
        end
      end
    @preferences = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return unless keep_loaded_access_token_payload?(
      @preference_payload,
      clear_invalid_cookie: clear_invalid_cookie,
    )

    @preferences
  end

  def keep_loaded_access_token_payload?(payload, clear_invalid_cookie: true)
    if @preferences.blank?
      unless clear_invalid_cookie
        @preference_payload = nil
        return false
      end

      cookies.delete(access_token_cookie_name, **preference_cookie_deletion_options)
      @preference_payload = nil
      return false
    end

    return true if preference_access_token_current?(@preferences, payload)

    unless clear_invalid_cookie
      @preferences = nil
      @preference_payload = nil
      return false
    end

    cookies.delete(access_token_cookie_name, **preference_cookie_deletion_options)
    @preferences = nil
    @preference_payload = nil
    false
  end

  def preference_access_token_current?(preference, payload)
    current_jti = preference&.jti
    return true if current_jti.blank?

    payload_jti = PreferenceToken.extract_jti(payload)
    return false if payload_jti.blank?

    secure_compare?(current_jti, payload_jti)
  end

  def matching_access_token_value
    access_token_cookie_names.lazy.filter_map do |cookie_name|
      token = BrowserCredentialCookie.read(cookies, cookie_name).to_s.presence
      next if token.blank?

      payload = decode_matching_access_token(token)
      next if payload.blank?

      @preference_payload = payload
      token
    end.first
  end

  def decode_matching_access_token(token)
    payload = PreferenceToken.decode(token, host: request.host, jwt_issuer_id: preference_jwt_issuer_id)
    return if payload.blank?
    return if PreferenceToken.extract_preference_type(payload) != preference_class.name

    payload
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
