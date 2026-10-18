# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

# R5-WU17 per-cell readiness (AT-R5-17, source side): as its own `rp-*` process each of the twelve
# JP-development cells authenticates a protected request from its local session and the OP-verified
# Access JWT only, refuses the same Access JWT without that session, and refuses it once the local
# OP binding is revoked (a back-channel logout tombstone).
class RpCellLocalSessionReadinessTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  # client_id => [host env, protected GET path]
  CELLS = {
    "base-app-ww" => ["PUBLIC_BASE_SERVICE_URL", "/accounts"],
    "base-com-ww" => ["PUBLIC_BASE_CORPORATE_URL", "/accounts"],
    "base-org-ww" => ["PUBLIC_BASE_STAFF_URL", "/accounts"],
    "core-app-jp" => ["PUBLIC_CORE_SERVICE_URL", "/api/v0/session"],
    "core-com-jp" => ["PUBLIC_CORE_CORPORATE_URL", "/api/v0/session"],
    "core-org-jp" => ["PUBLIC_CORE_STAFF_URL", "/api/v0/session"],
    "warp-app-jp" => ["PUBLIC_WARP_SERVICE_URL", "/dashboard"],
    "warp-com-jp" => ["PUBLIC_WARP_CORPORATE_URL", "/dashboard"],
    "warp-org-jp" => ["PUBLIC_WARP_STAFF_URL", "/dashboard"],
    "palm-app-jp" => ["PUBLIC_PALM_SERVICE_URL", "/dashboard"],
    "edit-org-ww" => ["PUBLIC_EDIT_STAFF_URL", "/dashboard"],
    "tech-org-ww" => ["PUBLIC_TECH_STAFF_URL", "/dashboard"],
  }.freeze

  CELLS.each do |client_id, (host_env, path)|
    test "#{client_id} authenticates from its local session and refuses without it or after logout" do
      host!(ENV.fetch(host_env))
      https!
      actor, root_token = cell_actor(client_id)

      with_core_browser_api_enabled do
        as_rp_cell(client_id) do
          token_response, _payload, local_session = sign_in_rp_cell(client_id, actor:, root_token:)
          get path, params: { ri: "jp" }

          assert authenticated_response?(path),
                 "#{client_id} #{path}: #{response.status} #{response.location} #{response.body.to_s.first(200)}"

          # The same Access JWT without the local session is not authenticated.
          session_cookie = cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
          cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
          get path, params: { ri: "jp" }

          assert_not authenticated_response?(path)

          # A revoked local OP binding (logout tombstone) stops authenticating the same credentials.
          cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = session_cookie
          cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
          binding_class = "#{RpCellBinding.for_client(client_id).record_prefix}OpSessionBinding".constantize
          binding_class.where(id: local_session.op_session_binding_id).update_all(revoked_at: Time.current)
          get path, params: { ri: "jp" }

          assert_not authenticated_response?(path)
        end
      end
    end
  end

  private

  # Core's session endpoint answers 200 either way and states the outcome in its body. Base app
  # requires a selected account first: a signed-in actor whose OP root has none is sent to the
  # selector (an authenticated-only step), an unauthenticated one to sign-in.
  def authenticated_response?(path)
    return response.status == 200 && response.parsed_body["authenticated"] == true if path == "/api/v0/session"
    return response.status == 200 unless response.redirect? && host == ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    URI.parse(response.location).path == "/selector"
  end

  def with_core_browser_api_enabled
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    yield
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end

  def cell_actor(client_id)
    actor =
      case RpCellBinding.for_client(client_id).realm
      when "app" then clients(:one)
      when "com" then Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
      else operators(:one)
      end
    grant_tech_access(actor) if client_id == "tech-org-ww"
    [actor, authentication_harness_create_token(actor)]
  end

  # Tech admits only an operator holding the in-force tech.access capability.
  def grant_tech_access(operator)
    OperatorCapabilityGrant.create!(
      operator:, granted_by_operator: operators(:two), origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
  end
end
