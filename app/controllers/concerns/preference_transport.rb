# typed: false
# frozen_string_literal: true

module PreferenceTransport
  extend ActiveSupport::Concern

  # adr/invalid-browser-credential-recovery.md. Refusal causes the database positively confirmed.
  # Each one leaves a clean, unpersisted preference context on an HTML read or declared entry.
  # `credential_rejection`: the presented credential itself is unusable. `lifecycle`: an ordinary end
  # of a valid credential's life. A refusal without one of these causes is a system failure and
  # raises; it is never turned into an anonymous success.
  PREFERENCE_CREDENTIAL_FAILURE_CATEGORIES = {
    malformed: "credential_rejection",
    record_not_found: "credential_rejection",
    digest_mismatch: "credential_rejection",
    binding_denied: "credential_rejection",
    replay_detected: "credential_rejection",
    ordinarily_deleted: "lifecycle",
    expired_or_revoked: "lifecycle",
    superseded_generation: "lifecycle",
  }.freeze

  # A consumed credential whose row was superseded by ordinary rotation this recently is treated as
  # a concurrent read that raced the rotating write (two tabs, reordered responses), not as reuse.
  # A read-only response for it detaches the credential for the request but emits no cookie
  # deletion, because the browser may already hold the newer generation under the same cookie name.
  PREFERENCE_STALE_GENERATION_WINDOW = 1.minute

  private

  def set_preferences_cookie
    if request.get? || request.head?
      access_cookie_present =
        access_token_cookie_names.any? { |name|
          BrowserCredentialCookie.read(cookies, name).present?
        }
      load_access_token_preference_record!(clear_invalid_cookie: false)
      access_unusable = access_cookie_present && @preferences.blank?
      load_read_only_preference_record_from_refresh_token! if @preferences.blank? && refresh_token_value.present?
      # A superseded generation's response must not delete the cookies the rotating response set.
      stale_generation = preference_refresh_failed? && @preference_credential_failure == :superseded_generation
      clear_unusable_preference_access_cookies! if access_unusable && !stale_generation
      return handle_unusable_preference_credential!(stage: :read_only_lookup) if preference_refresh_failed?

      return
    end

    clear_preference_refresh_failure!
    return if load_access_token_payload

    preference, created = load_preference_record_from_refresh_token!(create_if_missing: true)
    return handle_unusable_preference_credential!(stage: :refresh_lookup) if preference_refresh_failed?
    return if preference.blank?

    @preferences = preference
    restore_preference_from_resource!(preference) if created && respond_to?(:current_resource, true)

    refresh_refresh_token_lifetime(preference)
    return handle_unusable_preference_credential!(stage: :rotation) if preference_refresh_failed?

    issue_access_token_from(@preferences || preference)
    nil
  end

  # An unusable preference credential is refused with 401 unless the request is an HTML read or the
  # controller declares the action a public sign-in/sign-up entry. Those only render or start a
  # ceremony, never act on preference authority, so they detach the credential for the rest of the
  # request and continue with display defaults. Detaching never creates, rotates, or adopts a
  # preference, and the old row's settings are never copied. JSON callers keep the 401 contract. A
  # refusal without a confirmed cause raises. See adr/invalid-browser-credential-recovery.md.
  def handle_unusable_preference_credential!(stage:)
    failure = @preference_credential_failure
    unless PREFERENCE_CREDENTIAL_FAILURE_CATEGORIES.key?(failure)
      log_preference_credential_recovery(stage: stage, outcome: "system_failure")
      raise PreferenceBase::ResolutionError, "preference credential refusal has no confirmed cause"
    end

    read_only = request.get? || request.head?
    recoverable = !request.format.json? && (read_only || preference_entry_recovery_action?)
    stale_generation = failure == :superseded_generation
    outcome =
      if !recoverable then "rejected"
      elsif stale_generation then "detached_stale_generation"
      else "detached"
      end
    log_preference_credential_recovery(stage: stage, outcome: outcome)
    return render_preference_refresh_error! unless recoverable

    clear_preference_auth_cookies! unless stale_generation
    detach_preference_credential!
    nil
  end

  # Controllers opt in per action. The default keeps the fail-closed 401.
  def preference_entry_recovery_action?
    false
  end

  def detach_preference_credential!
    @preferences = nil
    @preference_payload = nil
    @preference_credential_detached = true
  end

  def preference_credential_detached?
    @preference_credential_detached == true
  end

  def clear_unusable_preference_access_cookies!
    access_token_cookie_names.each do |name|
      cookies.delete(name, **preference_cookie_deletion_options) if BrowserCredentialCookie.read(cookies, name).present?
    end
    Rails.logger.info(
      JitLogEvent.format(
        "preference.credential.recovery",
        surface: preference_cookie_surface,
        credential_kind: "access_cookie",
        failure: "invalid_or_expired_access_token",
        category: "credential_rejection",
        outcome: "detached",
        request_id: request.request_id,
      ),
    )
  end

  def log_preference_credential_recovery(stage:, outcome:)
    Rails.logger.warn(
      JitLogEvent.format(
        "preference.credential.recovery",
        failure: @preference_credential_failure || "unclassified",
        category: PREFERENCE_CREDENTIAL_FAILURE_CATEGORIES.fetch(@preference_credential_failure, "system_failure"),
        binding_reason: @preference_refresh_binding_reason,
        stage: stage,
        outcome: outcome,
        surface: preference_cookie_surface,
        host: request.host,
        controller: controller_path,
        action: action_name,
        request_method: request.request_method,
        request_id: request.request_id,
      ),
    )
  end

  def restore_preference_from_resource!(_preference)
    resource = preference_current_resource
    return if resource.blank?
    return unless respond_to?(:adopt_preference_for!, true)

    adopt_preference_for!(resource)
  rescue PreferenceBase::ResolutionError
    raise
  rescue StandardError => e
    Rails.logger.info(
      JitLogEvent.format(
        "preference.restore_from_resource.error", error: e.class.name,
                                                  message: e.message,
      ),
    )
    nil
  end
end
