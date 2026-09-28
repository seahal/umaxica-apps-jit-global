# typed: false
# frozen_string_literal: true

class Auth::Com::Verification::CancellationsController < ::Auth::Com::Verification::BaseController
  include SignVerificationCancellation

  AUTHENTICATION_MODE = :private

  # Cancelling only ends state. An actor with no Step-Up method reaches it from the setup page, so
  # the method prerequisite, which would send them back to setup, does not apply here.
  skip_before_action :enforce_step_up_prereqs!

  private

  def verification_cancellation_destination_path
    auth_com_settings_path(ri: params[:ri])
  end
end
