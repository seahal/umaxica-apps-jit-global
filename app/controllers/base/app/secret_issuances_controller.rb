# frozen_string_literal: true

class Base::App::SecretIssuancesController < Base::App::ApplicationController
  include SurfaceInertiaPage

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private
  before_action :load_issuance
  before_action :require_issuance_step_up
  rescue_from ClientSecretStorageConfirmationCommitter::Denied,
              ClientSecretManualIssuanceInvalidator::Denied,
              ClientSecretManualReattemptIssuer::Denied, with: :deny_secret_operation
  rescue_from ClientSecretManualReservationIssuer::CapacityFull,
              ClientSecretIssuanceCountValue::ReservationConflict, with: :conflicting_secret_operation

  public

  def show
    authorize!(ClientSecretCredential, to: :create?)
    render inertia: "base/app/secret_issuances/show", props: {
      title: t("base.app.secrets.title"),
      state: @issuance.state(at: Client.database_now).to_s,
      presentation: base_app_secret_issuance_presentation_path(@issuance.public_id),
      confirmation: base_app_secret_issuance_path(@issuance.public_id),
      authenticity_token: form_authenticity_token,
      present_label: t("base.app.secrets.present"),
      confirm_label: t("base.app.secrets.confirm"),
      cancel_label: t("actions.cancel"),
      notice: distribution_notice,
      continue_href: base_app_identity_passkeys_path(ri: current_region_identifier),
      continue_label: t("actions.continue"),
      reattempt_action: payload_failed? ? reattempt_base_app_secret_issuance_path(@issuance.public_id) : nil,
      reattempt_of: payload_failed? ? @issuance.public_id : nil,
      reattempt_label: t("base.app.secrets.reattempt"),
    }
  end

  def update
    authorize!(ClientSecretCredential, to: :create?)
    return deny_secret_operation unless params[:stored] == "1"

    ClientSecretStorageConfirmationCommitter.call!(
      actor_context: secret_actor_context, token: current_session_token, issuance: @issuance,
    )
    redirect_to(
      (@issuance.origin == "manual") ? base_app_secrets_path : base_app_secret_issuance_path(@issuance.public_id), status: :see_other,
    )
  end

  def destroy
    authorize!(ClientSecretCredential, to: :create?)
    ClientSecretManualIssuanceInvalidator.call!(
      actor_context: secret_actor_context, token: current_session_token, issuance: @issuance,
      purge_after: ClientSecretLifetimesValue.purge_delay,
    )
    redirect_to(base_app_secrets_path, status: :see_other)
  end

  def reattempt
    authorize!(ClientSecretCredential, to: :create?)
    return deny_secret_operation unless params[:reattempt_of].is_a?(String) &&
      params[:reattempt_of] == @issuance.public_id

    successor = ClientSecretManualReattemptIssuer.call!(
      actor_context: secret_actor_context, token: current_session_token, predecessor: @issuance,
      purge_after: ClientSecretLifetimesValue.purge_delay,
    )
    redirect_to(base_app_secret_issuance_path(successor.public_id), status: :see_other)
  end

  private

  def load_issuance
    @issuance = ClientSecretIssuance.find_by!(
      public_id: params.expect(:id), client_id: current_client.id,
      browser_session_ref: current_session_token.public_id, sign_up_flow_ref: nil,
    )
  end

  def require_issuance_step_up
    require_step_up!(scope: (@issuance.origin == "manual") ? "settings_secret_credential" : "settings_passkey")
  end

  def distribution_notice
    return unless @issuance.origin == "passkey_registration"
    return t("base.app.secrets.distribution_omitted") if @issuance.planned_count.zero?
    return unless @issuance.planned_count == 1

    t(@issuance.confirmed_at ? "base.app.secrets.distribution_one_confirmed" : "base.app.secrets.distribution_one_present")
  end

  def secret_actor_context
    ActorValuesContext.empty.with(subject: current_client, actor_type: :client, tld: :app, surface: :base)
  end

  def payload_failed?
    @issuance.origin == "manual" && @issuance.canceled_at.present? && ClientSecretAuditOutbox.exists?(
      client_ref: current_client.public_id, operation_ref: @issuance.origin_operation_id,
      event_name: "secret.issuance_canceled", reason: "payload_unavailable",
      occurred_at: @issuance.canceled_at, item_count: @issuance.planned_count,
    )
  end

  def deny_secret_operation
    render plain: t("errors.messages.invalid_request"), status: :forbidden
  end

  def conflicting_secret_operation
    render plain: t("base.app.secrets.capacity_conflict"), status: :conflict
  end
end
