# typed: false
# frozen_string_literal: true

# Base Self-RP relay for org administration pages whose logic lives at an HTTPS owner (R5-WU12).
# The request (method, params, wanted format) is forwarded to the owner's mirror path under
# /api/v0; the owner's answer is rendered, redirected, passed through (JSON) or turned into the
# Step-Up ceremony. The RP reads no Enforcement data and makes no decision itself.
module OrgOwnerPageRelay
  extend ActiveSupport::Concern

  FORWARDED_PARAM_EXCLUSIONS = %w(controller action authenticity_token format).freeze

  private

  def relay_owner_page!
    forwarded = request.request_parameters.merge(request.query_parameters).except(*FORWARDED_PARAM_EXCLUSIONS)
    client = OrgAdminAuthorityClient.new(
      access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
      browser_request: request,
      surface: owner_page_surface,
    )
    path = request.path
    # The owner answers in the format the browser asked for and builds links with this page's own
    # URL context (ri and preference parameters).
    context = {
      "X-Browser-Format" => request.format.symbol.to_s, "X-Browser-Url-Options" => default_url_options.to_json,
    }
    result =
      if request.get? || request.head?
        client.get(path, forwarded, extra_headers: context)
      else
        client.post(path, forwarded, extra_headers: context)
      end
    respond_with_owner(result)
  end

  def respond_with_owner(result)
    body = result.data.to_h
    if body["error"] == "step_up_required"
      authorize!(result, to: :relay?, with: AvatarRemoteResultPolicy)
      return require_step_up!(scope: body.fetch("scope"))
    end
    # The owner's decision; a refusal goes through the authorization handler as before.
    authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
    raise ActiveRecord::RecordNotFound, "not found" if result.status == :not_found
    return head(:service_unavailable) if result.status == :dependency

    if body.key?("redirect")
      redirect_to(body.fetch("redirect"), status: :see_other)
    elsif body.key?("component")
      render inertia: body.fetch("component"), props: body.fetch("props"), status: owner_status(result)
    else
      render json: body, status: result.http_status
    end
  end

  def owner_status(result) = result.http_status

  # The realm whose Base Self-RP calls the owner; a page may declare OWNER_PAGE_SURFACE, else org.
  def owner_page_surface
    self.class.const_defined?(:OWNER_PAGE_SURFACE) ? self.class.const_get(:OWNER_PAGE_SURFACE) : "org"
  end
end
