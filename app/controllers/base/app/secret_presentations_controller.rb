# frozen_string_literal: true

class Base::App::SecretPresentationsController < Base::App::ApplicationController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private
  before_action :authenticate_client!

  public

  def create
    authorize!(ClientSecretCredential, to: :create?)
    @issuance = ClientSecretIssuance.find_by!(
      public_id: params.expect(:secret_issuance_id), client_id: current_client.id,
      browser_session_ref: current_session_token.public_id, sign_up_flow_ref: nil,
    )
    require_step_up!(scope: (@issuance.origin == "manual") ? "settings_secret_credential" : "settings_passkey")
    return if performed?

    context = ActorValuesContext.empty.with(subject: current_client, actor_type: :client, tld: :app, surface: :base)
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: current_session_token, issuance: @issuance)
    @values = ClientSecretPresentationIssuer.call!(
      actor_context: ActorValuesContext.empty.with(subject: current_client, actor_type: :client, tld: :app, surface: :base),
      token: current_session_token, issuance: @issuance,
    )
    response.headers["Referrer-Policy"] = "no-referrer"
    render "base/app/secret_presentations/create", layout: false, locals: {
      confirmation_url: base_app_secret_issuance_path(@issuance.public_id),
      cancel_url: base_app_secret_issuance_path(@issuance.public_id),
      checkpoint_version: nil,
    }
  rescue ClientSecretPresentationIssuer::AlreadyPresented
    redirect_to(base_app_secret_issuance_path(@issuance.public_id), status: :see_other)
  rescue ClientSecretPresentationIssuer::PayloadUnavailable
    ClientSecretManualIssuanceInvalidator.call!(
      actor_context: ActorValuesContext.empty.with(subject: current_client, actor_type: :client, tld: :app, surface: :base),
      token: current_session_token, issuance: @issuance, purge_after: ClientSecretLifetimesValue.purge_delay,
    )
    session.delete(:client_secret_operation_id)
    render plain: t("base.app.secrets.payload_unavailable"), status: :gone
  rescue ClientSecretPresentationIssuer::Denied
    render plain: t("errors.messages.invalid_request"), status: :forbidden
  end
end
