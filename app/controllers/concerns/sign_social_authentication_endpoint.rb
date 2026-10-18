# typed: false
# frozen_string_literal: true

module SignSocialAuthenticationEndpoint
  extend ActiveSupport::Concern
  include ExternalAuthenticationEndpoint

  SUPPORTED_PROVIDERS = %w(google apple).freeze
  SOCIAL_LINK_SCOPE = SocialAuth::SOCIAL_LINK_SCOPE

  private

  def continue_social_authentication(provider:, intent: nil)
    intent ||= "link"
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent") unless intent.to_s == "link"

    unless SUPPORTED_PROVIDERS.include?(provider)
      return redirect_to(
        auth_app_sign_in_path,
      )
    end

    operation = "link"
    unless external_authentication_allowed?(surface: "app", provider: provider, operation: operation) &&
        external_authentication_start_available?(provider: provider, operation: operation, context: {})
      return redirect_to(auth_app_sign_in_path, status: :see_other)
    end

    prepare_social_auth_intent!(
      intent,
      provider: provider,
      pt: nil,
      entry: "sign_in",
      ri: params[:ri].presence,
    )
    store_social_ceremony_grant!(params[:social_ceremony_grant]) if params[:social_ceremony_grant].present?

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
      status: :see_other,
    )
  rescue SocialAuth::LastIdentityError
    redirect_to(
      social_unlink_failure_path(provider),
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
