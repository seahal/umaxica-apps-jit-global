# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

module PreferenceRefreshTokenTransport
  extend ActiveSupport::Concern

  private

  def load_preference_record_from_refresh_token!(create_if_missing: false)
    return [@preferences, false] if @preferences.present?

    token_value = refresh_token_value
    @refresh_token_value = token_value
    @refresh_presented_digest = nil
    @refresh_public_id = nil

    refresh_public_id, refresh_digest = refresh_token_data(token_value)
    preference = find_refresh_preference(refresh_public_id, refresh_digest)

    if valid_refresh_preference?(preference)
      @preferences = preference
      return [preference, false]
    end

    if preference.present?
      if preference.replay?
        handle_preference_refresh_replay!(preference)
      else
        handle_preference_refresh_failed(preference, refresh_public_id)
      end
      return [nil, false]
    end

    if token_value.present?
      handle_preference_refresh_failed(preference, refresh_public_id)
      return [nil, false]
    end

    return [nil, false] unless create_if_missing

    @refresh_presented_digest = nil
    @refresh_public_id = nil
    preference = create_new_preference_record!
    [preference, true]
  end

  def load_read_only_preference_record_from_refresh_token!
    token_value = refresh_token_value
    return if token_value.blank?

    @refresh_token_value = token_value
    @refresh_presented_digest = nil
    @refresh_public_id = nil

    refresh_public_id, refresh_digest = refresh_token_data(token_value)
    @refresh_presented_digest = refresh_digest
    @refresh_public_id = refresh_public_id

    preference =
      if refresh_digest.present?
        with_preference_connection(:writing) do
          relation = preference_class.includes(preference_associations_to_preload)
          if refresh_public_id.present?
            relation.find_by(public_id: refresh_public_id)
          else
            relation.find_by(token_digest: refresh_digest)
          end
        end
      end

    binding_allowed = preference.present? && preference_refresh_binding_allowed?(preference)
    valid = preference.present? && !refresh_digest_mismatch?(preference, refresh_digest) &&
      valid_refresh_preference?(preference) && binding_allowed

    if valid
      @preferences = preference
      return preference
    end

    @preference_refresh_failed = true
    @preference_credential_failure =
      classify_refresh_credential_failure(preference, refresh_public_id, refresh_digest)
    if @preference_credential_failure == :replay_detected && superseded_preference_generation?(preference)
      @preference_credential_failure = :superseded_generation
    end
    event =
      @preference_refresh_binding_reason.present? ? "preference.token.refresh.binding_denied" :
           "preference.token.refresh.failed"
    Rails.logger.warn(
      JitLogEvent.format(
        event,
        reason: @preference_refresh_binding_reason || "invalid_or_inactive_refresh_token",
        **preference_refresh_log_context(preference, refresh_public_id),
      ),
    )
    nil
  end

  # Names why a presented refresh credential cannot be used. Only states the database positively
  # confirmed are named; a lookup that raised never reaches here. A token that does not parse into
  # the current `public_id.verifier` shape and matches no legacy digest is :malformed.
  def classify_refresh_credential_failure(preference, refresh_public_id, refresh_digest)
    return :malformed if refresh_digest.blank?
    return (refresh_public_id.present? ? :record_not_found : :malformed) if preference.nil?
    return :digest_mismatch if refresh_digest_mismatch?(preference, refresh_digest)
    return :binding_denied if @preference_refresh_binding_reason.present?
    return :replay_detected if preference.replay?
    return :ordinarily_deleted if preference.status_id == preference_status_class::DELETED
    # expires_at is an alias of discard_at, which replay handling and revocation also set, so the
    # schema cannot tell an ordinary expiry from a revocation. The name says exactly that.
    return :expired_or_revoked if preference.revoked?

    :unclassified
  end

  # Consumed by ordinary rotation (not retired by replay handling or sign-out, which also end its
  # life), and recently enough to be a request that raced the rotating write.
  def superseded_preference_generation?(preference)
    preference.used_at.present? && preference.replaced_by_id.present? && !preference.revoked? &&
      preference.used_at > PreferenceTransport::PREFERENCE_STALE_GENERATION_WINDOW.ago
  end

  def refresh_token_data(token_value)
    return [nil, nil] if token_value.blank?

    refresh_public_id, refresh_verifier = parse_refresh_token(token_value)
    refresh_digest =
      if refresh_verifier.present?
        digest_refresh_token(refresh_verifier)
      else
        refresh_token_lookup_digest(token_value)
      end
    [refresh_public_id, refresh_digest]
  end

  def find_refresh_preference(refresh_public_id, refresh_digest)
    return nil if refresh_digest.blank?

    @refresh_presented_digest = refresh_digest
    @refresh_public_id = refresh_public_id

    lookup =
      lambda do
        with_preference_connection(:writing) do
          relation = preference_class.includes(preference_associations_to_preload)
          pref =
            if refresh_public_id.present?
              relation.find_by(public_id: refresh_public_id)
            else
              relation.find_by(token_digest: refresh_digest)
            end

          digest_mismatch = refresh_digest_mismatch?(pref, refresh_digest)
          binding_denied = pref.present? && !preference_refresh_binding_allowed?(pref)

          return handle_invalid_refresh_digest(pref, refresh_public_id) if digest_mismatch
          return handle_denied_refresh_binding(pref, refresh_public_id) if binding_denied

          pref
        end
      end

    if defined?(Prosopite)
      Prosopite.pause(&lookup)
    else
      lookup.call
    end
  end

  def refresh_digest_mismatch?(pref, refresh_digest)
    pref.present? && pref.token_digest.present? && !secure_compare?(pref.token_digest, refresh_digest)
  end

  def handle_invalid_refresh_digest(pref, refresh_public_id)
    @preference_credential_failure = :digest_mismatch
    handle_preference_refresh_failed(pref, refresh_public_id)
    nil
  end

  def handle_denied_refresh_binding(pref, refresh_public_id)
    handle_preference_refresh_binding_denied(pref, refresh_public_id)
    nil
  end

  def create_new_preference_record!(params_hash: nil)
    preference = persist_new_preference_record!(params_hash: params_hash)
    issue_new_preference_transport!(preference)
    preference
  end

  def persist_new_preference_record!(params_hash: nil)
    expires_at = refresh_token_expiry
    generated_token = nil

    preference_creation =
      lambda do
        with_preference_connection(:writing) do
          preference_connection_owner.transaction do
            ensure_preference_reference_defaults!
            @preferences = preference_class.create!(
              expires_at: expires_at,
              jti: JitSecurityJwtJtiGenerator.generate,
              binding_method_id: preference_binding_method_class::LEGACY,
              dbsc_status_id: preference_dbsc_status_class::NOTHING,
            )

            generated_token, verifier = generate_refresh_token(public_id: @preferences.public_id)
            @preferences.update!(token_digest: digest_refresh_token(verifier))

            create_preference_options(@preferences, preference_creation_context_params(params_hash))

            create_audit_log(
              event_id: "CREATE_NEW_PREFERENCE_TOKEN",
              context: { token_created: true },
              expires_at: expires_at,
            )
            create_audit_log(
              event_id: "REFRESH_TOKEN_ROTATED",
              context: { refresh_token_rotated: true, expires_at: expires_at },
              expires_at: expires_at,
            )
          rescue ActiveRecord::RecordInvalid => e
            @preferences&.destroy
            raise e
          end
        end
      end

    defined?(Prosopite) ? Prosopite.pause(&preference_creation) : preference_creation.call

    @preferences.issued_refresh_token = generated_token
    @preferences
  end

  def issue_new_preference_transport!(preference)
    generated_token = preference.issued_refresh_token
    raise PreferenceBase::ResolutionError, "new preference refresh token is missing" if generated_token.blank?

    @refresh_token_value = generated_token
    set_refresh_token_cookie(generated_token, preference.expires_at)
    set_preference_dbsc_cookie!(
      preference.dbsc_session_id,
      expires_at: preference_dbsc_cookie_expires_at(preference),
    ) if preference.binding_method_dbsc?
    issue_preference_dbsc_registration_header_for(preference)
  end

  def preference_creation_context_params(params_hash)
    source = params_hash || params
    context = source.slice(
      PreferenceIoKeys::Params::RI,
      PreferenceIoKeys::Params::LX,
      PreferenceIoKeys::Params::TZ,
      PreferenceIoKeys::Params::CT,
    )
    context[PreferenceIoKeys::Params::LX] ||= locale_from_region(context[PreferenceIoKeys::Params::RI].to_s.downcase)
    context
  end

  def refresh_refresh_token_lifetime(preference)
    return if @refresh_token_value.blank? || preference.blank? || @refresh_presented_digest.blank?

    rotated_preference =
      with_preference_connection(:writing) do
        preference.class.rotate!(
          presented_digest: @refresh_presented_digest,
          now: Time.current,
        )
      end

    unless rotated_preference
      current = with_preference_connection(:writing) { find_preference_by_presented_token }
      if current&.replay?
        handle_preference_refresh_replay!(current)
        return
      end

      # The row passed validation but was not consumable under the row lock. Name the state the
      # database now confirms (a concurrent expiry, revocation, or deletion). A row that is still
      # valid means rotation itself failed; that is a system failure, not a credential refusal.
      log_preference_refresh_rotation_failed(preference, @refresh_public_id)
      failure = classify_refresh_credential_failure(current, @refresh_public_id, @refresh_presented_digest)
      raise PreferenceBase::ResolutionError, "preference refresh rotation failed for a valid credential" if
        failure == :unclassified

      clear_preference_auth_cookies!
      @preference_refresh_failed = true
      @preference_credential_failure = failure
      return
    end

    new_token = rotated_preference.issued_refresh_token
    new_expiry = rotated_preference.expires_at

    @preferences = rotated_preference
    create_audit_log(
      event_id: "REFRESH_TOKEN_ROTATED",
      context: { refresh_token_rotated: true, expires_at: new_expiry },
      expires_at: new_expiry,
    )

    set_refresh_token_cookie(new_token, new_expiry)
    set_preference_dbsc_cookie!(
      rotated_preference.dbsc_session_id,
      expires_at: preference_dbsc_cookie_expires_at(rotated_preference),
    ) if rotated_preference.binding_method_dbsc?
    @refresh_token_value = new_token
    issue_preference_dbsc_registration_header_for(rotated_preference)

    return unless respond_to?(:adopt_rotated_preference!, true) && respond_to?(:current_resource, true)

    resource = preference_current_resource
    adopt_rotated_preference!(resource, rotated_preference) if resource
  end

  # Refresh tokens MUST come from the HttpOnly cookie only.
  # Accepting them via URL/body params leaks them to logs, history, and Referer
  # headers, defeating the HttpOnly/Secure cookie protections.
  def refresh_token_value
    refresh_token_cookie_names.lazy.filter_map { |cookie_name|
      BrowserCredentialCookie.read(cookies, cookie_name).to_s.presence
    }.first
  end

  def refresh_token_expiry
    PreferenceBase::REFRESH_TOKEN_TTL.from_now
  end

  def refresh_token_lookup_digest(token)
    legacy_refresh_token_digest(token)
  end
end

# rubocop:enable Metrics/MethodLength
