# typed: false
# frozen_string_literal: true

# Shared controller behavior for social sign-up birthdate check steps (Apple and Google).
# Include after SignUpExplicitStepControllerSupport and SignUpSocialPendingClientSupport.
module SignUpSocialCheckBirthdateControllerSupport
  extend ActiveSupport::Concern

  def show
    return unless load_gate_context!(gate_for_show)

    render_sign_up_checkpoint
  end

  def update
    return unless load_gate_context!(gate_for_update)

    clear_sign_up_birthdate_requirement
  end

  def destroy
    cancel_from_explicit_step
  end

  private

  def sign_up_surface = :app

  def sign_up_ticket_class = ClientSignUpFlow

  def sign_up_sequence_session_key = :auth_app_up_sequence_id

  def sign_up_step = :birthdate
end
