# typed: false
# frozen_string_literal: true

# Relay for org administration pages (R5-WU12): IAM, Support and Enforcement decisions and writes
# belong to their owners; these pages render the owners' answers and start Step-Up when asked.
module OrgAdminRelay
  extend ActiveSupport::Concern

  private

  def org_admin_authority
    @org_admin_authority ||= OrgAdminAuthorityClient.new(
      access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
      browser_request: request,
    )
  end

  # Returns the result for ok/unprocessable/conflict/unavailable answers; otherwise it has already
  # responded (Step-Up, authorization handler, 404 or 503) and returns nil.
  def org_admin_result!(result)
    if result.status == :forbidden && result.data.to_h["error"] == "step_up_required"
      authorize!(result, to: :relay?, with: AvatarRemoteResultPolicy)
      require_step_up!(scope: result.data.fetch("scope"))
      return
    end
    authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
    raise ActiveRecord::RecordNotFound, "not found" if result.status == :not_found
    raise ActionController::BadRequest, "bad request" if result.status == :bad_request

    if result.status == :dependency
      head :service_unavailable
      return
    end

    result
  end

  def org_admin_status(result)
    { unprocessable: :unprocessable_content, conflict: :conflict, unavailable: :service_unavailable }.fetch(
      result.status, :ok,
    )
  end
end
