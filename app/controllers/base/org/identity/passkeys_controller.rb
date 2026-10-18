# frozen_string_literal: true

class Base::Org::Identity::PasskeysController < Base::Org::ApplicationController
  include ::SurfaceInertiaPage
  include ::BaseIdentityPasskeyManagement

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def update
    @passkey = current_operator.staff_passkeys.active.find_by!(external_id: params.expect(:id))
    authorize!(@passkey, to: :update?, with: OperatorPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    description = params.expect(passkey: [:description]).fetch(:description)
    IdentityPasskeyNameCommitter.call!(
      actor: current_operator, token: current_session_token, passkey: @passkey, description: description.to_s.strip,
    )
    redirect_to(passkey_path(passkey_reference(@passkey)), status: :see_other)
  rescue IdentityPasskeyNameCommitter::Denied
    render plain: VerificationBase::STEP_UP_REQUIRED_MESSAGE, status: :unauthorized
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    render inertia: passkey_show_component, props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
           status: :unprocessable_content
  end

  def destroy
    @passkey = current_operator.staff_passkeys.active.find_by!(external_id: params.expect(:id))
    authorize!(@passkey, to: :destroy?, with: OperatorPasskeyPolicy)
    return if require_step_up!(scope: "settings_passkey") == false

    removed = IdentityCredentialRemovalCommitter.call!(
      actor: current_operator, credential: @passkey, current_session: current_session_token, request: request,
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

    OperatorPasskeyPolicy.new(
      OperatorPasskey,
      user: current_operator,
    ).management_requirement(token: current_session_token)
  end

  def registration_surface = "org"

  def identity_actor = current_operator

  def passkey_class = OperatorPasskey

  def passkey_association = :staff_passkeys

  def passkey_reference_attribute = :external_id
end
