# frozen_string_literal: true

# The admitted Auth half of Base-owned passkey registration. GET only renders the admitted page;
# options binds one WebAuthn challenge to the registration transaction, and create records a
# candidate. No principal credential or freshness is written on this host.
module AuthPasskeyRegistrationCeremony
  extend ActiveSupport::Concern

  include ::AuthCeremonyAdmission
  include ::AuthStepUpCeremonyContext
  include ::PasskeyRegistrationFlow
  include ::CloudflareTurnstile

  public

  def new
    admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) do
      return unless load_registration_ceremony_context!
      return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:passkey)

      render_registration_passkey_page
    end
  end

  def options
    return unless load_registration_ceremony_context!
    return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:passkey)
    return unless verify_turnstile_stealth!

    config = webauthn_relying_party_config
    options = Webauthn::RegistrationVerifier.options_for(
      config: config,
      user_id: @step_up_ceremony_actor.webauthn_user_handle,
      user_name: passkey_resource_display_name(@step_up_ceremony_actor),
      exclude_ids: webauthn_credential_ids(registration_passkey_scope),
      surface: webauthn_surface.key,
    )
    reference = @step_up_ceremony_session.issue_bound_passkey_registration_challenge!(
      transaction: @step_up_ceremony_transaction, challenge: options.challenge,
      rp_id: config.rp_id, origin: config.origin,
    )
    render json: { challenge_id: reference, options: Webauthn::OptionsSerializer.as_json(options) }, status: :ok
  rescue StepUpSessionConsumable::ChallengeError, ArgumentError,
         Webauthn::RelyingPartyConfigResolver::MissingConfigurationError => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_passkey_registration_options")
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
  rescue WebAuthn::Error => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_passkey_registration_options")
    render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
  end

  def create
    if admission_reference_param.present? && params[:credential].blank?
      apply_admission_transport_headers!
      return redeem_admission_reference_and_redirect!(expected_intent: auth_ceremony_entry_intent)
    end

    return unless load_registration_ceremony_context!
    return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:passkey)

    IdentityPasskeyRegistrationVerificationCommitter.call!(
      actor: @step_up_ceremony_actor,
      token: ceremony_session_token(@step_up_ceremony_session),
      transaction: @step_up_ceremony_transaction,
      session_record: @step_up_ceremony_session,
      config: webauthn_relying_party_config,
      reference: params[:challenge_id],
      credential_params: credential_params.to_h,
      description: passkey_description,
    )
    log_step_up_ceremony(
      "evidence_recorded", transaction: @step_up_ceremony_transaction, outcome: "verified", method: "passkey",
                           state_after: @step_up_ceremony_transaction.status,
    )
    render json: { status: "ok", redirect_url: registration_handoff_path }, status: :created
  rescue StepUpSessionConsumable::ChallengeError => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_passkey_registration_challenge")
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
  rescue Webauthn::RegistrationVerifier::VerificationError, WebAuthn::Error,
         IdentityPasskeyCeremonyContract::Error, ActiveRecord::RecordNotFound, ArgumentError => e
    log_step_up_refusal(e, transaction: @step_up_ceremony_transaction, stage: "auth_passkey_registration")
    render json: { error: I18n.t("errors.webauthn.verification_failed") }, status: :unprocessable_content
  end

  private

  def auth_ceremony_admitted_action_url = registration_create_path

  def auth_ceremony_entry_intent
    transaction = auth_ceremony_registration_transaction
    return transaction.purpose if transaction

    reference = admission_reference_param
    return "bootstrap" if reference.blank?

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: auth_ceremony_surface, reference: reference,
    )
    BaseAuthAdmissionCoordinator::HANDOFF_PURPOSE.find { |_intent, purpose| purpose == binding.purpose }&.first ||
      "invalid"
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    "invalid"
  end

  def registration_passkey_scope
    @step_up_ceremony_actor.public_send(registration_passkey_association).active
  end

  def registration_passkey_association
    raise NotImplementedError, "#{self.class} must define #registration_passkey_association"
  end

  def registration_handoff_path
    raise NotImplementedError, "#{self.class} must define #registration_handoff_path"
  end

  def render_registration_passkey_page
    render inertia: registration_component, props: {
      title: t("sign.app.settings.passkeys.new.page_title"),
      description: t("sign.app.settings.passkeys.new.description"),
      panel: {
        options_url: registration_options_path,
        verification_url: registration_create_path,
        turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
        turnstile_error_message: t("turnstile_error"),
        description_label: t("sign.app.settings.passkeys.new.description_label"),
        description_placeholder: t("sign.app.settings.passkeys.new.description_placeholder"),
        submit_label: t("sign.app.settings.passkeys.new.submit"),
      },
      cancel: {
        label: t("actions.cancel"), action: registration_cancellation_path, method: "post",
      },
    }
  end

  def registration_component
    raise NotImplementedError, "#{self.class} must define #registration_component"
  end

  def registration_options_path
    raise NotImplementedError, "#{self.class} must define #registration_options_path"
  end

  def registration_create_path
    raise NotImplementedError, "#{self.class} must define #registration_create_path"
  end

  def registration_cancellation_path
    raise NotImplementedError, "#{self.class} must define #registration_cancellation_path"
  end
end
