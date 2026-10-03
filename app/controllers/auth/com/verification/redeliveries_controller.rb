# frozen_string_literal: true

class Auth::Com::Verification::RedeliveriesController < Auth::Com::Verification::EmailsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  public

  def create
    return unless load_email_ceremony!
    unless params[:email_id] == @step_up_ceremony_transaction.transaction_id &&
        @step_up_ceremony_session.email_code_generation.positive?
      return render_invalid_step_up_context!
    end

    IdentityStepUpEmailCodeIssuer.call!(
      actor: @step_up_ceremony_actor, credential: ceremony_email_credential,
      transaction: @step_up_ceremony_transaction, session_record: @step_up_ceremony_session,
    )
    redirect_to(edit_auth_com_verification_email_path(@step_up_ceremony_transaction.transaction_id, ri: params[:ri]))
  rescue IdentityStepUpEmailCodeIssuer::Unavailable, IdentityStepUpCeremonyContract::Error
    @verification_errors = [t("otp.resend.failed")]
    render inertia: EDIT_COMPONENT, props: edit_page_props, status: :unprocessable_content
  end
end
