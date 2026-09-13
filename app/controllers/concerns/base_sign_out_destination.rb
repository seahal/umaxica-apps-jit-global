# typed: false
# frozen_string_literal: true

# Base-local sign-out finishes on GET /lobby rather than a reloadable completion page.
#
# `logout_current_session!` resets the Rails session. The one-time completion marker must be
# written after that reset so the following 303 can still read it. Rails flash is not used;
# `SignOutNotice` is the existing session-bound transport for this one-shot message.
module BaseSignOutDestination
  private

  def finish_local_sign_out!
    if current_resource.present? || current_session_public_id.present?
      prepare_sign_out_completion_notice!
      logout_current_session!(reason: "user_logout")
      issue_sign_out_notice!
    end

    redirect_to(sign_out_finished_path, status: :see_other)
  end

  def sign_out_finished_path
    public_send("#{sign_out_route_helper_prefix}_lobby_path", **sign_out_finished_route_params)
  end

  def sign_out_finished_route_params
    { ri: sign_out_route_params[:ri] }.compact
  end
end
