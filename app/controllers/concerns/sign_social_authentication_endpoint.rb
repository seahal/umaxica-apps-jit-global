# typed: false
# frozen_string_literal: true

module SignSocialAuthenticationEndpoint
  extend ActiveSupport::Concern
  include ExternalAuthenticationEndpoint

  SUPPORTED_PROVIDERS = %w(google apple).freeze
  SOCIAL_LINK_SCOPE = SocialAuth::SOCIAL_LINK_SCOPE

  private

  def continue_social_authentication(provider:, intent: nil)
    intent = intent || params[:intent] || "login"

    unless SUPPORTED_PROVIDERS.include?(provider)
      return redirect_to(
        auth_app_sign_in_path,
        alert: I18n.t("sign.app.social.sessions.invalid_provider"),
      )
    end

    operation = (social_auth_entry == "auth_up") ? "signup" : intent.to_s
    unless external_authentication_allowed?(surface: "app", provider: provider, operation: operation) &&
        external_authentication_start_available?(provider: provider, operation: operation, context: {})
      return redirect_to(auth_app_sign_in_path, status: :see_other)
    end

    state = prepare_social_auth_intent!(
      intent,
      provider: provider,
      pt: nil,
      entry: social_auth_entry,
      ri: params[:ri].presence,
    )
    issue_sign_up_flow!(provider) if social_auth_entry == "auth_up"
    if params[:social_ceremony_grant].present?
      store_social_ceremony_grant!(params[:social_ceremony_grant])
    elsif intent.to_s == "login"
      issuance = IdentitySocialCeremonyGrantIssuer.issue!(
        surface: "app",
        actor_ref: social_login_actor_ref,
        session_ref: state,
        operation: "login",
        provider: provider,
        resource_ref: social_auth_entry,
        return_to: path_from_signed_pt(signed_pt_token(resolved_path_or_navigation_target)),
      )
      store_social_ceremony_grant!(issuance.grant)
    end

    # The settings link button is already a token-protected POST, so the
    # ceremony hands the same POST to the OmniAuth request phase with a 307
    # instead of asking for a second press on a cushion page.
    redirect_to(omniauth_authorize_path(provider), status: :temporary_redirect)
  rescue SocialAuth::BaseError => e
    handle_social_auth_error(e)
  end

  def disconnect_social_authentication(provider:)
    return redirect_social_unlink_turnstile_failure(provider) unless cloudflare_turnstile_stealth_validation["success"]

    ExternalAuthenticationUnlinkUseCase.call(provider: provider, user: current_client)
    redirect_to(
      social_unlink_success_path(provider),
      notice: I18n.t(
        "sign.app.social.sessions.unlink.success",
        provider: SocialIdentifiable.normalize_provider(provider).humanize,
      ),
      status: :see_other,
    )
  rescue SocialAuth::LastIdentityError => e
    redirect_to(
      social_unlink_failure_path(provider),
      # `ApplicationError` translates its i18n key when the error is built, so the
      # message is already the copy to show. Translating it again looks the message
      # itself up as a key and renders "Translation missing" to the client.
      alert: e.message,
      status: :see_other,
    )
  rescue SocialAuth::BaseError => e
    render plain: e.message, status: e.status_code
  end

  def require_social_link_step_up!
    return true unless params[:intent].to_s == "link"
    return true unless SUPPORTED_PROVIDERS.include?(params[:provider].to_s)
    return true unless logged_in? && current_resource.present?
    return true if step_up_satisfied?(scope: SOCIAL_LINK_SCOPE)

    flash[:alert] = I18n.t("auth.step_up.required")
    redirect_to(
      actor_verification_path(
        scope: SOCIAL_LINK_SCOPE,
        pt: encoded_relative_pt(social_link_settings_path(params[:provider])),
        ri: params[:ri],
      ),
      status: :see_other,
    )
    false
  end

  def authorize_social_unlink!
    identity = social_identity_for_provider(social_provider)
    if identity.present?
      authorize!(identity, to: :destroy?)
    else
      authorize!(current_client, to: :update?)
    end
  end

  def social_auth_entry
    return "auth_up" if request.parameters["entry"].to_s == "auth_up"

    referer_path = URI.parse(request.referer.to_s).path
    return "auth_up" if referer_path == auth_app_sign_up_path

    "sign_in"
  rescue URI::InvalidURIError
    "sign_in"
  end

  def issue_sign_up_flow!(provider)
    cycle =
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignUpFlow.create!(
          principal_id: nil,
          status_id: ClientSignUpFlowStatus::STARTED,
          step: "start",
          nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: Time.current,
          expires_at: ClientSignUpFlow.default_ttl.from_now,
          entry_method: social_entry_method(provider),
          social_provider: social_entry_method(provider),
          return_to: resolved_path_or_navigation_target,
        )
      end
    result =
      AppTicketRecord.connected_to(role: :writing) do
        SignUpStateMachine.call(
          ticket: cycle,
          event: :start_social_callback,
          actor_context: Actor.authn,
        )
      end
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced

    sign_up_flow_locator.issue!(cycle)
    session[:auth_app_up_sequence_id] = cycle.public_id
    cycle
  end

  def social_login_actor_ref
    "anonymous"
  end

  def social_entry_method(provider)
    SocialIdentifiable.normalize_provider(provider)
  end

  def social_auth_failure_redirect_path
    social_link_settings_path(social_provider)
  end

  def social_identity_for_provider(provider)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    ExternalAuthentication::IdentityRepositoryFactory.current.build(normalized_provider).find_for_user(current_client)
  end

  def redirect_social_unlink_turnstile_failure(provider)
    redirect_to(
      social_unlink_failure_path(provider),
      alert: t("turnstile_error"),
      status: :see_other,
    )
  end

  def social_unlink_success_path(provider)
    social_unlink_settings_path(provider)
  end

  def social_unlink_failure_path(provider)
    social_unlink_settings_path(provider)
  end

  def social_unlink_settings_path(provider)
    case SocialIdentifiable.normalize_provider(provider)
    when "apple"
      auth_app_settings_apple_path(ri: params[:ri])
    else
      auth_app_settings_google_path(ri: params[:ri])
    end
  end

  def social_link_settings_path(provider)
    social_unlink_settings_path(provider)
  end

  def sign_up_flow_locator
    SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
  end

  def verification_required_action?
    action_name == "destroy"
  end

  def verification_scope
    "social_unlink"
  end
end
