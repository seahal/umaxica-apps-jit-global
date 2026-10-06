# typed: false
# frozen_string_literal: true

# Social sign-up birthdate requirement clearing for apple and google check controllers.
# Sign keeps the checkpoint UI and returns a signed completion result; Acme owns
# the durable social signup commit and session issuance.
module SignUpSocialBirthdateSupport
  private

  def clear_sign_up_birthdate_requirement
    return super unless pending_social_signup_confirmation?
    return if performed?
    return render_social_signup_completion!(social_signup_candidate!, sign_up_birthdate_param) if
      sign_up_requirement_cleared?(:birthdate)
    return unless validate_sign_up_checkpoint_version!
    return render_missing_social_signup_confirmation unless social_signup_confirmation_cleared?

    birthdate = sign_up_birthdate_param
    unless SignUpEligibilityPolicy.minimum_age_reached?(birthdate, surface: :app, today: Time.zone.today)
      sign_up_session_state.age_restricted = true
      result = SignUpTermination.call(cycle: @sign_up_ticket, event: :halt, actor_context: Actor.authn)
      return render_sign_up_result(result) unless result.success? || result.status == :failed

      render_sign_up_age_restricted
      return
    end

    candidate = social_signup_candidate!
    result = perform_sign_up_event(
      :clear_requirement,
      payload: { requirement: :birthdate, checkpoint_version: sign_up_checkpoint_version_param },
    )
    return render_sign_up_result(result) unless result.success?
    return render_sign_up_result(result) unless result.next_event == :finalize

    render_social_signup_completion!(candidate, birthdate)
  rescue SocialAuth::BaseError, IdentitySocialCeremonyContract::Error
    render plain: I18n.t("errors.social_auth.provider_error"), status: :unprocessable_content
  end

  def pending_social_signup_confirmation?
    @sign_up_ticket&.social_entry_method? &&
      @sign_up_ticket&.principal_id.blank? &&
      social_signup_evidence.present?
  end

  def social_signup_confirmation_cleared?
    @sign_up_ticket.requirement_cleared?(:confirmation)
  end

  def render_missing_social_signup_confirmation
    render plain: "social_signup_confirmation_required", status: :unprocessable_content
  end

  def social_signup_candidate!
    candidate_ref = social_signup_evidence.fetch("candidate_ref")
    validate_social_signup_candidate!(IdentitySocialCeremonyCandidateStore.fetch!(candidate_ref))
  end

  def validate_social_signup_candidate!(candidate)
    evidence = social_signup_evidence
    raise IdentitySocialCeremonyContract::Error, "candidate digest mismatch" unless
      candidate.digest.to_s == evidence.fetch("candidate_digest").to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate surface mismatch" unless candidate.surface.to_s == "app"
    raise IdentitySocialCeremonyContract::Error, "candidate actor mismatch" unless
      candidate.actor_ref.to_s == @sign_up_ticket.public_id.to_s
    raise IdentitySocialCeremonyContract::Error, "candidate session mismatch" unless
      candidate.session_ref.to_s == @sign_up_ticket.public_id.to_s

    expected_transaction_id = evidence["grant_transaction_id"].presence || @sign_up_ticket.public_id
    raise IdentitySocialCeremonyContract::Error, "candidate transaction mismatch" unless
      candidate.transaction_id.to_s == expected_transaction_id.to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate operation mismatch" unless candidate.operation.to_s == "signup"

    provider = SocialIdentifiable.normalize_provider(candidate.provider)
    uid = candidate.callback_result.principal.subject
    raise IdentitySocialCeremonyContract::Error,
          "candidate provider mismatch" unless provider == @sign_up_ticket.social_provider
    raise IdentitySocialCeremonyContract::Error,
          "candidate provider evidence mismatch" unless provider == evidence.fetch("provider")
    raise IdentitySocialCeremonyContract::Error, "candidate uid mismatch" unless
      pending_social_signup_uid_digest(provider: provider, uid: uid) == evidence.fetch("uid_digest")

    candidate
  end

  def render_social_signup_completion!(candidate, birthdate)
    grant = social_signup_ceremony_grant
    result_token = IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: social_signup_ceremony_grant_token(grant),
      callback_result: candidate.callback_result,
      surface: "app",
      actor_ref: grant["actor_ref"],
      session_ref: grant["session_ref"],
      operation: "signup",
      challenge_id: @sign_up_ticket.public_id,
      candidate: candidate,
      birthdate: birthdate,
    )
    result_reference = Valkey::AuthState::SocialCeremonyResultStore.new.issue!(
      token: result_token, expires_at: grant.expires_at,
    )
    sign_up_session_state.clear_all!
    redirect_to(
      base_app_social_authentication_completion_url(
        id: candidate.provider, result_ref: result_reference, ri: params[:ri],
        host: base_authority_host, protocol: "https",
      ), status: :see_other,
         allow_other_host: true,
    )
  end

  def social_signup_ceremony_grant
    evidence = social_signup_evidence
    transaction_id = evidence["grant_transaction_id"].presence
    raise IdentitySocialCeremonyContract::Error, "social signup grant is required" if transaction_id.blank?

    transaction = IdentitySocialCeremonyReplayStore.for("app").find_transaction!(transaction_id)
    IdentitySocialCeremonyGrant.decode(
      social_signup_ceremony_grant_token_from_transaction(transaction),
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )
  end

  def social_signup_ceremony_grant_token(grant)
    transaction = IdentitySocialCeremonyReplayStore.for("app").find_transaction!(grant["transaction_id"])
    social_signup_ceremony_grant_token_from_transaction(transaction)
  end

  def social_signup_ceremony_grant_token_from_transaction(transaction)
    IdentitySocialCeremonyGrant.issue(
      transaction.grant_claims,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )
  end

  def social_signup_evidence
    value = @sign_up_ticket&.completed_requirements&.fetch("social_signup", nil)
    value if value.is_a?(Hash)
  end

  def pending_social_signup_uid_digest(provider:, uid:)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      [provider, uid].map(&:to_s).join(":"),
    )
  end
end
