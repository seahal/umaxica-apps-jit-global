# typed: false
# frozen_string_literal: true

require "test_helper"

# The org administration consoles are gated by OrgConsolePolicy on operator capability grants
# (adr/operator-capability-authorization.md). An operator with no grant gets no more than an anonymous
# request does; Support and IAM open with their own read capability; audit, billing, configuration,
# and system have no data source yet and stay closed even to an operator holding every capability.
class Base::Org::StaffConsolePagesTest < ActionDispatch::IntegrationTest
  fixtures :operators,
           :operator_statuses,
           :operator_token_kinds,
           :operator_token_statuses,
           :operator_token_binding_methods,
           :operator_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access_token = AuthenticationToken.encode(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @operator, host: rp_host, resource_type: "operator",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             @operator,
                             resource_type: "operator",
                           ), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "audit console denies an operator that holds no grant" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_not_equal "ok", response.parsed_body["status"]
  end

  test "billing console denies an operator that holds no grant" do
    get base_org_billing_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "iam console denies an operator that holds no grant" do
    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "system console denies an operator that holds no grant" do
    get base_org_system_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "support console denies an operator that holds no grant" do
    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "configuration console denies an operator that holds no grant" do
    get base_org_configuration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
  end

  test "audit console denies an anonymous request" do
    get base_org_audit_index_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_not_equal 200, response.status
  end

  test "support console opens with support.console.read and lists only granted areas" do
    [OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
     OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    get base_org_support_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    hrefs =
      inertia_props.fetch("sections").flat_map { |section|
        section.fetch("items")
      }.map { |item| item.fetch("href") }

    assert_equal [base_org_support_visitors_path(ri: "jp")], hrefs
  end

  test "iam console opens with iam.capability.read" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_iam_index_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    assert_equal "base/org/iam/index", inertia_component
  end

  test "consoles without a data source stay closed even to an operator holding every capability" do
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator,
      capabilities: OperatorCapabilityGrant::CAPABILITIES,
      ticket_id: "TEST-1",
      expires_at: 1.day.from_now,
    )

    [base_org_audit_index_url(ri: "jp", host: @host), base_org_billing_index_url(ri: "jp", host: @host),
     base_org_system_index_url(ri: "jp", host: @host), base_org_configuration_url(ri: "jp", host: @host),].each do |url|
      get url, headers: @headers

      assert_not_equal 200, response.status, "expected #{url} to stay closed"
      assert_not_equal 501, response.status, "expected #{url} to be refused by policy before any response"
    end
  end

  test "the dashboard shows Administration only for consoles the operator is granted" do
    get base_org_dashboard_url(ri: "jp", host: @host), headers: @headers

    assert_response :ok
    headings = inertia_props.fetch("sections").map { |section| section.fetch("heading") }

    assert_not_includes headings, I18n.t("base.org.admin.dashboard.administration")

    OperatorCapabilityGrant.create!(
      operator: @operator,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_dashboard_url(ri: "jp", host: @host), headers: @headers
    administration =
      inertia_props.fetch("sections").find do |section|
        section.fetch("heading") == I18n.t("base.org.admin.dashboard.administration")
      end

    assert_equal [base_org_support_index_path(ri: "jp")],
                 administration.fetch("items").map { |item|
                   item.fetch("href")
                 }
    assert_includes inertia_props.fetch("sections").flat_map { |section|
      Array(section["items"])
    }.pluck("href"),
                    new_base_org_sign_out_path(ri: "jp"),
                    "personal links such as logout stay in place"
  end
end
