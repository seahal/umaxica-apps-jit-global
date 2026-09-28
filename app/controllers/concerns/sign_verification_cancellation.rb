# typed: false
# frozen_string_literal: true

module SignVerificationCancellation
  extend ActiveSupport::Concern

  def create
    acme_completion_state_present = acme_step_up_completion_state?
    csrf_token = acme_step_up_completion_csrf_token
    scope = current_step_up_session&.scope
    cancel_local_step_up_state!

    if acme_completion_state_present
      render(
        "sign/shared/step_up_cancellation",
        locals: {
          cancellation_url: acme_step_up_cancellation_url_for(step_up_ceremony_surface),
          csrf_token: csrf_token,
          ri: params[:ri],
          scope: scope,
        },
      )
    else
      redirect_to(verification_cancellation_destination_path, status: :see_other)
    end
  end

  private

  def cancel_local_step_up_state!
    clear_step_up_state! if respond_to?(:clear_step_up_state!, true)
    destroy_current_step_up_session! if respond_to?(:destroy_current_step_up_session!, true)
    clear_acme_step_up_completion_state! if respond_to?(:clear_acme_step_up_completion_state!, true)
  end

  def acme_step_up_cancellation_url_for(surface)
    case surface.to_s
    when "app"
      base_app_verification_cancellation_url(
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      )
    when "com"
      base_com_verification_cancellation_url(
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      )
    when "org"
      base_org_verification_cancellation_url(
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      )
    else
      raise NotImplementedError, "unsupported step-up surface: #{surface}"
    end
  end

  # Where an Auth-initiated Step-Up lands when cancelled: a fixed Auth path of the surface. A
  # Base-initiated one is handed to Base's fixed cancellation endpoint above instead. Neither takes a
  # destination from the request, and the success continuation (the step-up session's return_to) is
  # never used for cancellation.
  def verification_cancellation_destination_path
    raise NotImplementedError, "#{self.class} must define #verification_cancellation_destination_path"
  end
end
