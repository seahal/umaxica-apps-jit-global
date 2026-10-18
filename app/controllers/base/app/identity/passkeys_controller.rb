# frozen_string_literal: true

class Base::App::Identity::PasskeysController < Base::App::Identity::BaseController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def update
    @passkey = current_client.client_passkeys.active.find_by!(public_id: params.expect(:id))
    authorize!(@passkey, to: :update?, with: ClientPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    description = params.expect(passkey: [:description]).fetch(:description)
    IdentityPasskeyNameCommitter.call!(
      actor: current_client, token: current_session_token, passkey: @passkey, description: description.to_s.strip,
    )
    redirect_to(passkey_path(passkey_reference(@passkey)), status: :see_other)
  rescue IdentityPasskeyNameCommitter::Denied
    render plain: VerificationBase::STEP_UP_REQUIRED_MESSAGE, status: :unauthorized
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    render inertia: passkey_show_component, props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
           status: :unprocessable_content
  end

  def destroy
    @passkey = current_client.client_passkeys.active.find_by!(public_id: params.expect(:id))
    authorize!(@passkey, to: :destroy?, with: ClientPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    removed = IdentityCredentialRemovalCommitter.call!(
      actor: current_client, credential: @passkey, current_session: current_session_token, request: request,
    )
    unless removed
      return render inertia: passkey_show_component,
                    props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
                    status: :unprocessable_content
    end
    redirect_to(passkeys_path, status: :see_other)
  rescue ArgumentError, ActiveRecord::RecordInvalid
    render inertia: passkey_show_component,
           props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
           status: :unprocessable_content
  end

  private

  def step_up_requirement(scope:, **options)
    unless scope == "settings_passkey" && options.empty?
      raise ArgumentError, "Passkey management requires its current policy"
    end

    ClientPasskeyPolicy.new(ClientPasskey, user: current_client).management_requirement(token: current_session_token)
  end

  def registration_surface = "app"

  def identity_actor = current_client

  def passkey_class = ClientPasskey

  def passkey_association = :client_passkeys
end
