# typed: false
# frozen_string_literal: true

# App-surface social ceremony entry
# (Auth::App::Social::SessionsController and RegistrationsController).
#
# Adds everything the app surface needs on top of the surface-neutral
# SocialCeremonyEntry: sign-up entry detection and its suspension gate,
# intent session state, ceremony replay grants, the ClientSignUpFlow issuance,
# and the link/step-up intents.
#
# The OmniAuth callbacks are handled by Auth::App::Omniauth::OmniauthCallbacksController.
module AppSocialCeremonyEntry
  extend ActiveSupport::Concern

  # Declared as a Concern dependency rather than included from the `included`
  # block: a block-level `include` would insert the neutral concern closer to
  # the controller than this one, so its NotImplementedError hooks would shadow
  # the implementations below.
  include SocialCeremonyEntry

  SUPPORTED_PROVIDERS = %w(google apple).freeze
  SOCIAL_LINK_SCOPE = SocialAuth::SOCIAL_LINK_SCOPE

  included do
    include SocialAuth
    include SignUpSuspensionGuard

    rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
  end

  private

  # --- SocialCeremonyEntry hooks --------------------------------------------

  def social_ceremony_surface = "app"

  def social_ceremony_providers = SUPPORTED_PROVIDERS

  def social_ceremony_abort_path = auth_app_sign_in_path

  def social_ceremony_operation(intent)
    (social_auth_entry == "sign_up") ? "signup" : intent.to_s
  end

  # Keeps the app surface on SocialAuth#omniauth_authorize_path, which also
  # handles the optional `state:` argument the app ceremony uses.
  def social_ceremony_request_path(provider)
    omniauth_authorize_path(provider)
  end

  # Params:
  #   - provider: "google" or "apple" (route default)
  #   - intent: "login", "link", or "step_up" (default: "login")
  #     "login" is the internal continue flow: existing identities sign in,
  #     missing identities create a new account.
  def prepare_surface_ceremony_state!(intent:, provider:)
    # Only the sign-up entry is gated: this concern also serves the sign-in
    # ceremony, which `sign_up_suspended_app` must leave open. The check runs
    # before any session state is prepared, so a suspended registration leaves
    # no intent, no ceremony grant, and no ClientSignUpFlow behind.
    return false if social_auth_entry == "sign_up" && reject_suspended_sign_up!

    # Prepare session with intent context (OmniAuth manages OAuth state)
    state = prepare_social_auth_intent!(
      intent,
      provider: provider,
      pt: nil,
      entry: social_auth_entry,
      ri: params[:ri].presence,
    )
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
    issue_sign_up_flow!(provider) if social_auth_entry == "sign_up"

    true
  end

  # --- App-surface ceremony state -------------------------------------------

  def social_auth_entry
    return "sign_up" if %w(sign_up auth_up).include?(request.parameters["entry"].to_s)

    referer_path = URI.parse(request.referer.to_s).path
    return "sign_up" if referer_path == auth_app_sign_up_path

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
  end

  # This concern is mounted only on app-surface controllers (see the file
  # header), so the gated surface is fixed rather than derived per request.
  def sign_up_surface = :app

  def social_login_actor_ref
    "anonymous"
  end

  def social_entry_method(provider)
    SocialIdentifiable.normalize_provider(provider)
  end

  def sign_up_flow_locator
    SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
  end

  # A link intent arriving from settings has to be recently step-up verified.
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

  def social_link_settings_path(provider)
    case SocialIdentifiable.normalize_provider(provider)
    when "apple"
      auth_app_settings_apple_path(ri: params[:ri])
    else
      auth_app_settings_google_path(ri: params[:ri])
    end
  end
end
