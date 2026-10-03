# frozen_string_literal: true

# Concrete controllers supply credential scope, panel routes, handoff route and presentation.
# Every action resolves the admitted transaction; GET renders without creating a challenge.
module AuthStepUpPasskeyCeremony
  public

  def new
    return unless load_step_up_ceremony_context!
    return head :forbidden unless admitted_step_up_methods.include?(:passkey)

    render_step_up_passkey_page
  end

  def options
    return unless load_step_up_ceremony_context!
    return head :forbidden unless admitted_step_up_methods.include?(:passkey)
    return unless verify_turnstile_stealth!

    credentials = ceremony_passkey_scope.where("discard_at > clock_timestamp()")
    return head :forbidden if credentials.empty?

    config = webauthn_relying_party_config
    options = Webauthn::AssertionVerifier.options_for(
      config: config, allow_ids: credentials.pluck(:webauthn_id), purpose: :ordinary_step_up,
    )
    reference = @step_up_ceremony_session.issue_bound_passkey_challenge!(
      transaction: @step_up_ceremony_transaction, challenge: options.challenge,
      rp_id: config.rp_id, origin: config.origin,
    )
    render json: { options: Webauthn::OptionsSerializer.as_json(options), challenge_id: reference }
  rescue StepUpSessionConsumable::ChallengeError
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :unprocessable_content
  end

  def create
    return unless load_step_up_ceremony_context!
    return head :forbidden unless admitted_step_up_methods.include?(:passkey)

    credential = params.expect(
      credential: [
        :id, :rawId, :type, :authenticatorAttachment, :clientExtensionResults,
        response: %i(authenticatorData clientDataJSON signature userHandle), clientExtensionResults: {},
      ],
    ).to_h
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @step_up_ceremony_actor, transaction: @step_up_ceremony_transaction,
      session_record: @step_up_ceremony_session, config: webauthn_relying_party_config,
      reference: params[:challenge_id], credential_params: credential,
    )
    render json: { status: "ok", redirect_url: ceremony_passkey_handoff_path }
  rescue StepUpSessionConsumable::ChallengeError, Webauthn::AssertionVerifier::VerificationError,
         WebAuthn::Error, ActiveRecord::RecordNotFound, IdentityStepUpCeremonyContract::Error
    render json: { error: I18n.t("errors.webauthn.verification_failed") }, status: :unprocessable_content
  end
end
