# typed: false
# frozen_string_literal: true

# Identifier-first passkey sign-in: the #options action issues a bound
# one-time challenge for an account's active passkeys, and the #verification
# action consumes it, verifies the assertion through
# Webauthn::AssertionVerifier (signature, RP ID, origin, UV=required), and
# commits the login. Surface specifics come from the declared webauthn_surface
# and a small set of controller hooks.
module PasskeySignInFlow
  extend ActiveSupport::Concern

  ANONYMIZED_ALLOW_CREDENTIALS_COUNT = 4

  include PasskeyCeremonyContext
  include MinimumResponseBudget
  include CloudflareTurnstile

  def options
    return unless before_passkey_options_request!

    identifier = normalized_passkey_identifier
    return render_error(passkey_identifier_required_error_key, :unprocessable_content) if identifier.blank?

    return render_error(
      passkey_identifier_invalid_error_key,
      :unprocessable_content,
    ) unless valid_passkey_identifier?(identifier)

    actor = find_active_passkey_actor(identifier)
    passkeys = actor ? active_passkeys_for_actor(actor).to_a : []

    challenge_id, request_options = issue_passkey_authentication_challenge(
      allow_credentials: anonymized_passkey_allow_credentials(passkeys), actor: actor,
      purpose: passkey_ceremony_purpose,
    )

    render json: {
      challenge_id: challenge_id,
      options: request_options,
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "webauthn.authentication_options_failed", error_class: e.class.name,
                                                  message: e.message,
      ),
    )
    render_error("errors.webauthn.options_failed", :unprocessable_content)
  end

  def verification
    challenge_id = params[:challenge_id]
    return render_error("errors.webauthn.challenge_id_required", :bad_request) if challenge_id.blank?

    begin
      consumed = consume_passkey_challenge_with_actor!(challenge_id, purpose: passkey_ceremony_purpose)
      actor_id = passkey_actor_id_from(consumed.actor_global_key)
      @_risk_actor_id = actor_id
      verify_and_login(consumed.challenge, actor_id)
    ensure
      # Defense in depth: no code path may leave a replayable challenge behind.
      discard_passkey_challenge(challenge_id)
    end
  rescue Webauthn::ChallengeStore::ChallengeNotFoundError, Webauthn::ChallengeStore::ChallengeExpiredError => e
    Rails.logger.warn("WebAuthn challenge error: #{e.message}")
    emit_passkey_auth_failed(reason: "challenge_invalid")
    render_error("errors.webauthn.challenge_invalid", :bad_request)
  rescue Webauthn::ChallengeStore::ChallengePurposeMismatchError,
         Webauthn::ChallengeStore::ChallengeBindingMismatchError => e
    Rails.logger.warn("WebAuthn challenge binding error: #{e.message}")
    emit_passkey_auth_failed(reason: "challenge_binding_mismatch")
    render_error("errors.webauthn.challenge_invalid", :bad_request)
  rescue WebAuthn::SignCountVerificationError => e
    Rails.logger.warn("WebAuthn sign count verification failed: #{e.message}")
    emit_passkey_auth_failed(reason: "sign_count_mismatch")
    render_error("errors.webauthn.sign_count_mismatch", :unauthorized)
  rescue Webauthn::AssertionVerifier::VerificationError => e
    Rails.logger.warn("WebAuthn user verification rejected: #{e.message}")
    emit_passkey_auth_failed(reason: "uv_rejected")
    render_error("errors.webauthn.verification_failed", :unauthorized)
  rescue WebAuthn::Error => e
    Rails.logger.warn("WebAuthn authentication failed: #{e.message}")
    emit_passkey_auth_failed(reason: "verification_failed")
    render_error("errors.webauthn.verification_failed", :unauthorized)
  end

  private

  # -- ceremony ------------------------------------------------------------

  def verify_and_login(challenge, actor_id)
    passkey = passkey_sign_in_model.find_by(webauthn_id: credential_params[:id])

    unless passkey && passkey_belongs_to_challenge_actor?(passkey, actor_id)
      Rails.logger.warn(passkey_owner_mismatch_log_message)
      emit_passkey_auth_failed(reason: "credential_not_found")
      return render_error("errors.webauthn.credential_not_found", :unauthorized)
    end

    return unless allow_passkey_sign_in?(passkey)

    context = Webauthn::AssertionVerifier.verify!(
      credential_params: credential_params.to_h,
      challenge: challenge,
      config: webauthn_relying_party_config,
      public_key: passkey.public_key,
      sign_count: passkey.sign_count,
      purpose: passkey_assertion_uv_purpose,
    )

    attrs = { sign_count: context.sign_count }
    attrs[:last_used_at] = context.verified_at if passkey.has_attribute?(:last_used_at)
    attrs[:uv_verified_at] = context.verified_at if passkey.has_attribute?(:uv_verified_at)
    passkey.update!(attrs)

    handle_login_result(perform_passkey_sign_in(passkey))
  end

  def credential_params
    credential = params.fetch(:credential, {})
    # `clientExtensionResults` is optional in WebAuthn, and a client that ran no extension
    # may send it as null. `permit` declares it as a hash, and a null under a hash
    # declaration counts as an unpermitted key - so an authenticator that reports "no
    # extensions" would otherwise fail the ceremony. Drop the key when it carries no hash.
    unless credential[:clientExtensionResults].respond_to?(:each_pair)
      credential = credential.except(:clientExtensionResults)
    end

    # `slice` first: a malformed or padded credential payload should fail verification on
    # its merits, not raise here for carrying a key this method never reads.
    keys = %i(id rawId type authenticatorAttachment response clientExtensionResults)
    credential = credential.slice(*keys)

    credential.permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      { response: %i(clientDataJSON authenticatorData signature userHandle) },
      { clientExtensionResults: {} },
    )
  end

  def retrieve_pt_for_checkpoint
    signed_pt_param
  end

  alias_method :retrieve_pt_for_bulletin, :retrieve_pt_for_checkpoint

  def render_error(message_key, status)
    render json: { error: I18n.t(message_key) }, status: status
  end

  def emit_passkey_auth_failed(reason: nil)
    actor_id = defined?(@_risk_actor_id) ? @_risk_actor_id : nil
    return unless actor_id

    SignRiskEmitter.emit(
      "auth_failed",
      webauthn_surface.actor_foreign_key.to_sym => actor_id,
      :ip => request&.remote_ip,
      :reason => reason,
      :ri => current_region_identifier,
    )
  rescue StandardError
    # Best-effort: do not let risk emission failures disrupt the auth flow
  end

  # -- ceremony purpose ----------------------------------------------------

  # The challenge-store purpose this flow issues and consumes under. Purposes
  # are separate namespaces (Webauthn::ChallengeStore::PURPOSES), so a
  # controller that overrides this cannot consume another ceremony's challenge
  # and its own challenge cannot be replayed into one.
  def passkey_ceremony_purpose
    :authentication
  end

  # The UV policy purpose the assertion is verified under. Kept as its own hook
  # because the challenge purpose and the UV purpose are separate registries
  # and a future decision may relax one without the other.
  def passkey_assertion_uv_purpose
    PasskeyCeremonyContext::DEFAULT_UV_PURPOSES.fetch(passkey_ceremony_purpose)
  end

  # -- options hooks -------------------------------------------------------

  def before_passkey_options_request!
    verify_turnstile_stealth!
  end

  def normalized_passkey_identifier
    params[:identifier].to_s.strip
  end

  def passkey_identifier_required_error_key
    "errors.webauthn.pii_required"
  end

  def valid_passkey_identifier?(_identifier)
    true
  end

  def passkey_identifier_invalid_error_key
    passkey_identifier_required_error_key
  end

  def find_active_passkey_actor(_identifier)
    raise NotImplementedError, "#{self.class} must define #find_active_passkey_actor"
  end

  def active_passkeys_for_actor(actor)
    webauthn_surface.passkey_class
      .where(webauthn_surface.actor_foreign_key => actor.id)
      .where(status_id: webauthn_surface.passkey_status_class::ACTIVE)
  end

  # Username-first WebAuthn must not reveal whether an account exists, has a
  # passkey, or is currently session-saturated. Every syntactically valid
  # identifier receives the same number of opaque credential descriptors.
  # Persisted model limits cap real credentials at this count.
  def anonymized_passkey_allow_credentials(passkeys)
    padding_count = [ANONYMIZED_ALLOW_CREDENTIALS_COUNT - passkeys.size, 0].max
    dummy_credentials = Array.new(padding_count) { { id: SecureRandom.urlsafe_base64(32) } }

    (passkeys + dummy_credentials).shuffle
  end

  def minimum_response_budget_enabled?
    action_name == "options"
  end

  # -- sign-in hooks -------------------------------------------------------

  def passkey_sign_in_model
    webauthn_surface.passkey_class
  end

  def passkey_belongs_to_challenge_actor?(passkey, actor_id)
    actor_id.present? && passkey.public_send(webauthn_surface.actor_foreign_key) == actor_id
  end

  def passkey_owner_mismatch_log_message
    "WebAuthn: Credential not found or actor mismatch"
  end

  def allow_passkey_sign_in?(_passkey)
    true
  end

  def perform_passkey_sign_in(_passkey)
    raise NotImplementedError, "#{self.class} must define #perform_passkey_sign_in"
  end

  # -- login result --------------------------------------------------------

  def handle_login_result(result)
    sign_in_result = sign_in_result_from_session_result(result)
    return if handle_domain_specific_login_status(result)
    return render_passkey_restricted_success(result) if sign_in_result.session_limit_pending?
    return render_passkey_success(result) if sign_in_result.success?

    render_error("errors.login_failed", :unprocessable_content)
  end

  def render_passkey_success(result)
    pt = retrieve_pt_for_checkpoint if respond_to?(:retrieve_pt_for_checkpoint, true)
    render json: {
      status: "ok",
      access_token: result[:access_token],
      token_type: result[:token_type],
      # API contract: this is the actual remaining JWT lifetime in seconds.
      # It may be shorter than the default access TTL when the backing token
      # has an earlier revocation boundary.
      expires_in: result[:expires_in],
      redirect_url: sign_in_sequence_redirect_path(pt: pt, default_path: passkey_default_redirect_url),
      dbsc: result[:dbsc],
    }, status: :ok
  end

  def handle_domain_specific_login_status(_result)
    false
  end

  def passkey_success_restricted?(result)
    result[:restricted]
  end

  def render_passkey_restricted_success(_result)
    raise NotImplementedError, "#{self.class} must define #render_passkey_restricted_success"
  end

  def passkey_checkpoint_redirect_url
    raise NotImplementedError, "#{self.class} must define #passkey_checkpoint_redirect_url"
  end

  alias_method :passkey_bulletin_redirect_url, :passkey_checkpoint_redirect_url

  def passkey_default_redirect_url
    raise NotImplementedError, "#{self.class} must define #passkey_default_redirect_url"
  end
end
