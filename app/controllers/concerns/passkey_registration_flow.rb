# typed: false
# frozen_string_literal: true

# Passkey registration ceremonies (sign-up checkpoint and settings).
#
# The challenge is bound to the registering actor, surface, RP ID, and origin
# at issue time and consumed exactly once; verification runs through
# Webauthn::RegistrationVerifier, so every stored credential was created with
# userVerification=required and a UV=true attestation.
#
# Two verification entry points share the options path:
# - verify_and_create_passkey_registration! persists directly (sign-up flow)
# - verify_passkey_registration commits through the passkey ceremony contract
#   and tops up recovery passcodes (settings flow)
module PasskeyRegistrationFlow
  extend ActiveSupport::Concern

  include PasskeyCeremonyContext

  private

  def render_passkey_registration_options
    challenge_id, creation_options = issue_passkey_registration_challenge(
      resource: passkey_registration_actor,
      exclude_credentials: passkey_registration_existing_credentials,
    )

    render json: {
      challenge_id: challenge_id,
      options: creation_options,
    }, status: :ok
  rescue WebAuthn::Error, ArgumentError, Webauthn::RelyingPartyConfigResolver::MissingConfigurationError => e
    Rails.logger.error(
      JitLogEvent.format(
        "#{passkey_registration_log_prefix}.options_failed",
        error_class: e.class.name,
        message: e.message,
      ),
    )
    render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
  end

  # Sign-up flow: verify and persist the credential directly.
  def verify_and_create_passkey_registration!
    challenge_id = params[:challenge_id]
    if challenge_id.blank?
      render_passkey_registration_missing_challenge_id
      return false
    end

    challenge = consume_passkey_challenge!(
      challenge_id, purpose: :registration, actor: passkey_registration_actor,
    )
    context = Webauthn::RegistrationVerifier.verify!(
      credential_params: passkey_registration_credential_params.to_h,
      challenge: challenge,
      config: webauthn_relying_party_config,
    )

    metadata = Webauthn::AuthenticatorMetadata.attributes_from(context)
    passkey = passkey_registration_passkeys.new(
      webauthn_id: context.webauthn_id,
      public_key: registration_public_key,
      sign_count: context.sign_count,
      description: passkey_description(provider_name: metadata[:provider_name]),
      **metadata,
    )
    save_passkey_registration!(passkey)
    passkey
  rescue Webauthn::ChallengeStore::ChallengeError => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.challenge_error", message: e.message))
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
    nil
  rescue Webauthn::RegistrationVerifier::VerificationError, WebAuthn::Error => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.failed", message: e.message))
    render json: { error: I18n.t("errors.webauthn.verification_failed") }, status: :unprocessable_content
    nil
  rescue ActiveRecord::RecordNotUnique
    render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
    nil
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.persist_failed", message: e.message))
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    nil
  end

  # Settings flow: verify, then commit through the ceremony contract.
  def verify_passkey_registration
    challenge_id = params[:challenge_id]
    return render_missing_challenge_id if challenge_id.blank?

    challenge = consume_passkey_challenge!(
      challenge_id, purpose: :registration, actor: passkey_registration_actor,
    )
    context = Webauthn::RegistrationVerifier.verify!(
      credential_params: credential_params.to_h,
      challenge: challenge,
      config: webauthn_relying_party_config,
    )

    passkey = commit_passkey_ceremony!(context, challenge_id)

    render_verification_success(passkey)
  rescue Webauthn::ChallengeStore::ChallengeError => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.challenge_error", message: e.message))
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
  rescue Webauthn::RegistrationVerifier::VerificationError, WebAuthn::Error => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.failed", message: e.message))
    render json: { error: I18n.t("errors.webauthn.verification_failed") },
           status: :unprocessable_content
  rescue IdentityPasskeyCeremonyContract::Error => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.commit_failed", message: e.message))
    render json: { error: I18n.t("errors.webauthn.verification_failed") },
           status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.persist_failed", message: e.message))
    render_passkey_persist_failed(e.record)
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
    keys = %i(id rawId type authenticatorAttachment response clientExtensionResults transports)
    credential = credential.slice(*keys)

    credential.permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      { transports: [] },
      { response: [:clientDataJSON, :attestationObject, { transports: [] }] },
      { clientExtensionResults: {} },
    )
  end
  alias_method :passkey_registration_credential_params, :credential_params

  # The COSE public key of the attested credential, in the storage encoding.
  def registration_public_key
    credential = WebAuthn::Credential.from_create(
      credential_params.to_h,
      relying_party: webauthn_relying_party_config.relying_party,
    )
    credential.public_key
  end

  def render_missing_challenge_id
    render json: {
      error: I18n.t("errors.webauthn.challenge_id_required"),
    }, status: :bad_request
  end
  alias_method :render_passkey_registration_missing_challenge_id, :render_missing_challenge_id

  def commit_passkey_ceremony!(context, challenge_id)
    metadata = Webauthn::AuthenticatorMetadata.attributes_from(context)
    candidate = IdentityPasskeyCeremonyResultIssuer::Candidate.new(
      webauthn_id: context.webauthn_id,
      public_key: registration_public_key,
      sign_count: context.sign_count,
      description: passkey_description(provider_name: metadata[:provider_name]),
      transports: context.transports,
      metadata: metadata,
    )
    commit = finish_passkey_ceremony!(
      surface: webauthn_surface.key.to_s,
      actor: passkey_registration_actor,
      session_ref: current_session_public_id,
      candidate: candidate,
      challenge_id: challenge_id,
    )
    reset_passkey_ceremony_session!
    commit.passkey
  end

  def render_verification_success(passkey)
    recovery_passcode_top_up = top_up_recovery_passcodes_after_passkey_registration
    redirect_url =
      if recovery_passcode_top_up.raw_values.any?
        recovery_passcode_reveal_url(recovery_passcode_top_up.raw_values)
      else
        bootstrap_return_path(passkey_registration_redirect_url)
      end

    render json: {
      status: "ok",
      passkey_id: passkey.id,
      redirect_url: redirect_url,
    }, status: :created
  end

  # Public contract for a rejected passkey record, in the JSON shape the registration panel reads.
  # The limit is actionable and gets its own message; any other validation reason is logged and
  # answered as a failed registration. The validator's own wording is never the response.
  def render_passkey_persist_failed(record)
    if record.errors.details.fetch(:base, []).any? { |detail| detail.fetch(:error) == :too_many }
      return render json: { error: I18n.t("errors.webauthn.passkey_limit_reached") }, status: :unprocessable_content
    end

    Rails.logger.warn(
      JitLogEvent.format(
        "#{passkey_registration_log_prefix}.persist_rejected",
        attributes: record.errors.attribute_names.map(&:to_s),
      ),
    )
    render json: { error: I18n.t("errors.webauthn.verification_failed") }, status: :unprocessable_content
  end

  # Initial-value policy: the user's own label wins; otherwise the resolved
  # provider friendly name seeds the description; the generic default is the
  # last resort. The user can rename freely afterwards and metadata never
  # overwrites their label.
  def passkey_description(provider_name: nil)
    params[:description].presence || provider_name.presence || I18n.t("sign.default_passkey_description")
  end
  alias_method :passkey_registration_description, :passkey_description

  def verification_required_action?
    step_up_bootstrap_active? && %w(new create options verification).include?(action_name)
  end

  def verification_scope
    "settings_passkey"
  end

  def passkey_registration_existing_credentials
    passkey_registration_passkeys.map { |passkey| { id: passkey.webauthn_id } }
  end

  def save_passkey_registration!(passkey)
    passkey.save!
  end

  def top_up_recovery_passcodes_after_passkey_registration
    RecoveryPasscodeTopUp.call(
      actor: recovery_passcode_top_up_actor,
      credential_class: recovery_passcode_top_up_credential_class,
      target_count: RecoveryPasscodeTopUp::TARGET_ACTIVE_RECOVERY_PASSCODES,
    )
  end

  def recovery_passcode_top_up_actor
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_top_up_actor"
  end

  def recovery_passcode_top_up_credential_class
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_top_up_credential_class"
  end

  def recovery_passcode_reveal_url(raw_values)
    return if raw_values.blank?

    reveal = IdentityOneTimeReveal.issue!(
      actor: recovery_passcode_top_up_actor,
      session_nonce: recovery_passcode_top_up_actor.public_id,
      value: raw_values,
      purpose: recovery_passcode_reveal_purpose,
      metadata: recovery_passcode_reveal_metadata,
    )
    recovery_passcode_reveal_redirect_url(reveal.token)
  end

  def recovery_passcode_reveal_purpose
    case webauthn_surface.key
    when :com
      "visitor.recovery_secret_credential"
    when :org
      "org.recovery_passcodes"
    else
      raise ArgumentError, "unsupported recovery passcode reveal surface: #{webauthn_surface.key}"
    end
  end

  def recovery_passcode_reveal_metadata
    {}
  end

  def recovery_passcode_reveal_redirect_url(token)
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_reveal_redirect_url"
  end

  def passkey_registration_log_prefix
    "webauthn.registration"
  end
end
