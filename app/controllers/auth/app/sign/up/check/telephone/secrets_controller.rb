# frozen_string_literal: true

class Auth::App::Sign::Up::Check::Telephone::SecretsController < Auth::App::ApplicationController
  include SignUpSequenceControllerSupport
  include SignUpExplicitStepControllerSupport
  include SurfaceInertiaPage

  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest
  before_action :load_sign_up_ticket
  before_action :validate_sign_up_checkpoint_contact!
  before_action -> { authorize_sign_up_requirement!(:register_passkey?) }
  before_action :load_secret_issuance

  public

  def show
    return unless load_gate_context!(gate_for_show)

    state = @issuance.state(at: Client.database_now)
    path = auth_app_sign_up_check_telephone_secret_path(ri: current_region_identifier, pt: signed_pt_param)
    render inertia: "base/app/secret_issuances/show", props: {
      title: t("base.app.secrets.title"),
      state: state.to_s,
      presentation: path,
      confirmation: path,
      authenticity_token: form_authenticity_token,
      present_label: t("base.app.secrets.present"),
      confirm_label: t("base.app.secrets.confirm"),
      cancel_label: t("actions.cancel"),
      continue_label: t("actions.continue"),
      continue_href: nil,
      completion_action: path,
      notice: distribution_notice,
      checkpoint_version: @sign_up_ticket.checkpoint_version,
    }
  end

  def create
    return unless load_gate_context!(gate_for_create)

    ClientSecretPresentationIssuer.prepare_for_sign_up!(
      flow: @sign_up_ticket, nonce: browser_nonce,
      issuance: @issuance,
    )
    @values = ClientSecretPresentationIssuer.present_for_sign_up!(
      flow: @sign_up_ticket, nonce: browser_nonce,
      issuance: @issuance,
    )
    path = auth_app_sign_up_check_telephone_secret_path(ri: current_region_identifier, pt: signed_pt_param)
    response.headers["Referrer-Policy"] = "no-referrer"
    render "base/app/secret_presentations/create", layout: false, locals: {
      confirmation_url: path, cancel_url: path, checkpoint_version: @sign_up_ticket.checkpoint_version,
    }
  rescue ClientSecretPresentationIssuer::AlreadyPresented
    redirect_to(auth_app_sign_up_check_telephone_secret_path(ri: current_region_identifier), status: :see_other)
  end

  def update
    return unless load_gate_context!(gate_for_update)
    return unless validate_sign_up_checkpoint_version!(json: false)

    if @issuance.planned_count.positive?
      return head :unprocessable_content unless params[:stored] == "1"

      ClientSecretStorageConfirmationCommitter.confirm_for_sign_up!(
        flow: @sign_up_ticket, nonce: browser_nonce, issuance: @issuance,
      )
    end
    result = perform_sign_up_event(
      :clear_requirement, payload: { requirement: :passkey, checkpoint_version: sign_up_checkpoint_version_param },
    )
    return render_sign_up_result(result) unless result.success?

    redirect_to(next_explicit_step_path, status: :see_other)
  end

  def destroy
    cancel_from_explicit_step
  end

  rescue_from ClientSecretPasskeyReservationIssuer::Denied, ClientSecretPresentationIssuer::Denied,
              ClientSecretStorageConfirmationCommitter::Denied, with: :deny_delivery

  private

  def load_secret_issuance
    @issuance = ClientSecretIssuance.find_by!(
      client_id: @sign_up_ticket.principal_id, sign_up_flow_ref: @sign_up_ticket.public_id,
      origin: "passkey_registration", browser_session_ref: nil,
    )
  end

  def browser_nonce
    sign_up_session_state.cycle_payload.stringify_keys.fetch("nonce")
  end

  def distribution_notice
    return t("base.app.secrets.distribution_omitted") if @issuance.planned_count.zero?
    return unless @issuance.planned_count == 1

    @issuance.confirmed_at ? t("base.app.secrets.distribution_one_confirmed") : t("base.app.secrets.distribution_one_present")
  end

  def deny_delivery
    render plain: t("errors.messages.invalid_request"), status: :forbidden
  end

  def sign_up_requirement_context
    SignUpRequirementContext.build(
      surface: :app, actor_authentication: sign_up_actor_authentication,
      ticket: @sign_up_ticket, requirement: :passkey, pending_actor: sign_up_pending_actor,
    )
  end

  def sign_up_family = "telephone"

  def sign_up_step = :passkey

  def sign_up_surface = :app

  def sign_up_ticket_class = ClientSignUpFlow

  def sign_up_sequence_session_key = :auth_app_up_sequence_id
end
