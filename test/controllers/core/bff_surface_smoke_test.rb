# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreBffSurfaceSmokeTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :com_preference_binding_methods, :com_preferences,
           :operators, :operator_token_kinds

  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_service.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_APP",
      resource_type: "client",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_corporate.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_corporate.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_COM",
      resource_type: "visitor",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", Rails.configuration.x.boot_config.fetch(:hosts).core_staff.host),
      acme_host: Rails.configuration.x.boot_config.fetch(:hosts).acme_staff.host,
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
      jwt_issuer_id: "surface:CORE_ORG",
      resource_type: "operator",
    },
  ].freeze

  test "core BFF and logout routes are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}/sign/in/callback"

      assert_response :unprocessable_content

      resource_type = surface.fetch(:resource_type)
      user, token = actor_and_token_for(resource_type)
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

      post "https://#{host}/sign/out", params: { ri: "jp" },
                                       headers: bearer_headers(
                                         AuthenticationToken.encode(
                                           user, host: host, session_public_id: token.public_id,
                                                 resource_type: resource_type,
                                                 jwt_issuer_id: surface.fetch(:jwt_issuer_id),
                                         ),
                                       )

      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_select "form#sign-out-handoff-form[method=?]", "post", maximum: 1 if handoff_rendered

      post "https://#{host}#{surface.fetch(:backchannel_logout_path)}",
           params: { logout_token: "invalid" }

      assert_response :bad_request
      assert_equal "invalid_logout_token", response.body

      post "https://#{host}#{surface.fetch(:token_refresh_path)}",
           headers: { "Accept" => "application/json" },
           as: :json

      assert_response :service_unavailable
      assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
    end
  end

  private

  def bearer_headers(token, headers: {})
    headers.merge("Authorization" => "Bearer #{token}")
  end

  def actor_and_token_for(resource_type)
    case resource_type
    when "operator"
      staff = operators(:one)
      token = OperatorToken.where(staff: staff).where(
        "discarded_at > ?",
        Time.current,
      ).order(created_at: :desc).first ||
        OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      [staff, token]
    when "visitor"
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      [visitor, token]
    else
      user = clients(:one)
      token = ClientToken.where(user: user).where("discarded_at > ?", Time.current).order(created_at: :desc).first ||
        ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      [user, token]
    end
  end

  def core_sign_out_url_for(host)
    case host
    when ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))
      core_app_sign_out_url(ri: "jp", host: host)
    when ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"))
      core_com_sign_out_url(ri: "jp", host: host)
    else
      core_org_sign_out_url(ri: "jp", host: host)
    end
  end
end
