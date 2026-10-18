# typed: false
# frozen_string_literal: true

module SignOutCancellation
  extend ActiveSupport::Concern

  def destroy
    cancel_pending_sign_out!
    respond_to_sign_out_cancellation
  end

  private

  def cancel_pending_sign_out!
    fail_pending_sign_out_transaction!
    session.delete(SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY)
    session.delete(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY)
    @logout_transaction = nil if defined?(@logout_transaction)
  end

  def fail_pending_sign_out_transaction!
    logout_challenge = params[:logout_challenge].to_s
    return if logout_challenge.blank?

    OpBaseAppRecord.connected_to(role: :writing) do
      AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: logout_challenge).fail!
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def respond_to_sign_out_cancellation
    respond_to do |format|
      format.html { redirect_to(sign_out_cancellation_home_path, status: :see_other) }
      format.json { head :no_content }
    end
  end

  def sign_out_cancellation_home_path
    public_send(
      "#{sign_out_route_helper_prefix}_root_path",
      ri: params[:ri].presence,
    )
  end
end
