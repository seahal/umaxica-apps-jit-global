# frozen_string_literal: true

class Base::App::SecretsController < Base::App::ApplicationController
  include SurfaceInertiaPage

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  step_up only: %i(new create edit update destroy), scope: "settings_secret_credential"
  before_action :load_secret, only: %i(show edit update destroy)
  rate_limit to: 5, within: 1.minute, by: -> { current_client.id },
             scope: "base_app_secret", name: "issuance", store: rate_limit_store,
             only: :create, with: -> { render_rate_limited(retry_after: 60) }

  rescue_from ClientSecretManualReservationIssuer::Denied, ClientSecretNameCommitter::Denied,
              ClientSecretRevocationCommitter::Denied, ClientSecretPresentationIssuer::Denied,
              with: :deny_secret_operation
  rescue_from ClientSecretManualReservationIssuer::CapacityFull,
              ClientSecretIssuanceCountValue::ReservationConflict, with: :conflicting_secret_operation
  rescue_from ClientSecretNameCommitter::InvalidName, with: :invalid_secret_name

  public

  def index
    authorize!(ClientSecretCredential, to: :index?)
    render inertia: "base/app/secrets/index", props: {
      title: t("base.app.secrets.title"),
      count: ClientSecretCapacityQuery.call(client: current_client, at: Client.database_now).active_count,
      secrets: current_client.client_secret_credentials.order(:created_at, :id).map { |secret|
        { id: secret.public_id, name: secret.name, href: base_app_secret_path(secret.public_id) }
      },
      add: { label: t("base.app.secrets.add"), href: new_base_app_secret_path },
    }
  end

  def show
    authorize!(@secret, to: :show?)
    render_secret_detail
  end

  def new
    authorize!(ClientSecretCredential, to: :create?)
    render inertia: "base/app/secrets/new", props: {
      title: t("base.app.secrets.add"),
      action: base_app_secrets_path,
      authenticity_token: form_authenticity_token,
      submit: t("actions.continue"),
    }
  end

  def edit
    authorize!(@secret, to: :update?)
    render_secret_detail
  end

  def create
    authorize!(ClientSecretCredential, to: :create?)
    # The browser retains only a nonsecret operation locator. Retrying this POST cannot
    # produce a second allocation; a completed allocation is cleared by confirmation.
    operation_id = session[:client_secret_operation_id] ||= SecureRandom.uuid
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: secret_actor_context, token: current_session_token, operation_id: operation_id,
      expires_after: ClientSecretLifetimesValue.issuance_ttl,
    )
    ClientSecretPresentationIssuer.prepare!(
      actor_context: secret_actor_context, token: current_session_token,
      issuance: issuance,
    )
    redirect_to(base_app_secret_issuance_path(issuance.public_id), status: :see_other)
  end

  def update
    authorize!(@secret, to: :update?)
    ClientSecretNameCommitter.call!(
      actor_context: secret_actor_context, token: current_session_token, credential: @secret,
      name: params.slice(:name).permit(:name)[:name],
    )
    redirect_to(base_app_secret_path(@secret.public_id), status: :see_other)
  end

  def destroy
    authorize!(@secret, to: :destroy?)
    ClientSecretRevocationCommitter.call!(
      actor_context: secret_actor_context, token: current_session_token, credential: @secret,
      purge_after: ClientSecretLifetimesValue.purge_delay,
    )
    redirect_to(base_app_secrets_path, status: :see_other)
  end

  private

  def load_secret
    @secret = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
  end

  def secret_actor_context
    ActorValuesContext.empty.with(subject: current_client, actor_type: :client, tld: :app, surface: :base)
  end

  def render_secret_detail
    render inertia: "base/app/secrets/show", props: {
      title: t("base.app.secrets.title"),
      name: @secret.name,
      id: @secret.public_id,
      action: base_app_secret_path(@secret.public_id),
      authenticity_token: form_authenticity_token,
      rename: t("base.app.secrets.rename"),
      revoke: t("base.app.secrets.revoke"),
    }
  end

  def deny_secret_operation
    render plain: t("errors.messages.invalid_request"), status: :forbidden
  end

  def conflicting_secret_operation
    render plain: t("base.app.secrets.capacity_conflict"), status: :conflict
  end

  def invalid_secret_name
    render plain: t("errors.messages.invalid_request"), status: :unprocessable_content
  end
end
