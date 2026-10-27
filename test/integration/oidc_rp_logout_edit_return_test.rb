# frozen_string_literal: true

require "test_helper"

class OidcRpLogoutEditReturnTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_token_kinds

  test "Edit RP returns through Visa ORG and Base ORG self-RP returns to Base staff" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    operator = operators(:one)
    root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )

    [
      {
        client_id: "edit-org-ww",
        rp_host: hosts.edit_staff.host,
        expected_op_host: hosts.visa_staff.host,
        forbidden_op_hosts: [
          hosts.visa_service.host,
          hosts.visa_corporate.host,
          hosts.sign_service.host,
          hosts.sign_corporate.host,
          hosts.sign_staff.host,
          hosts.base_staff.host,
        ],
      },
      {
        client_id: "base-org-ww",
        rp_host: hosts.base_staff.host,
        expected_op_host: hosts.visa_staff.host,
        forbidden_op_hosts: [
          hosts.visa_service.host,
          hosts.visa_corporate.host,
          hosts.sign_service.host,
          hosts.sign_corporate.host,
          hosts.sign_staff.host,
          hosts.base_staff.host,
        ],
      },
    ].each do |scenario|
      client = OidcClientRegistry.find!(scenario.fetch(:client_id))
      grant = OpOrgGrant.create!(
        authentication_epoch: 0,
        operator_token: root_token,
        oidc_client_id: client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: 10.minutes.from_now,
      )
      logout_hint = OpOrgGrantLogoutHint.create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource: operator,
          client: client,
          nonce: grant.oidc_nonce,
          issued_at: Time.current,
          expires_at: 10.minutes.from_now,
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
          issuer: OidcIssuer.for_resource_type("operator"),
          subject: OidcSubject.for(operator, resource_type: "operator"),
          sid: grant.public_id,
          auth_time: grant.oidc_auth_time,
        ),
      )
      access_token = AuthenticationTokenService.encode(
        operator,
        host: scenario.fetch(:rp_host),
        resource_type: "operator",
        session_public_id: root_token.public_id,
        base_session_public_id: root_token.public_id,
        oidc_sid: grant.public_id,
        oidc_jti: grant.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(operator, resource_type: "operator"),
        client_id: client.client_id,
      )
      browser = open_session
      browser.host!(scenario.fetch(:rp_host))
      browser.https!
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = grant.issue_refresh_token!

      if scenario.fetch(:client_id) == "edit-org-ww"
        [hosts.visa_service.host, hosts.visa_corporate.host].each do |wrong_op_host|
          [
            { accept: "text/html", status: 400 },
            { accept: "application/json", status: 400 },
          ].each do |response_case|
            wrong_realm_browser = open_session
            wrong_realm_browser.host!(wrong_op_host)
            wrong_realm_browser.https!
            wrong_realm_browser.get(
              "/oidc/logout", params: {
                client_id: client.client_id,
                id_token_hint: logout_hint.id_token,
                post_logout_redirect_uri: client.post_logout_redirect_uris.find do |candidate|
                  URI.parse(candidate).host == scenario.fetch(:rp_host)
                end,
                ri: "jp",
                state: "edit-realm-check",
              }, headers: { "Accept" => response_case.fetch(:accept) },
            )

            assert_equal response_case.fetch(:status), wrong_realm_browser.response.status,
                         "Edit hint must be refused by another OP realm"
            assert_nil wrong_realm_browser.response.location, "A foreign OP realm must not return to Edit"
            grant_active = grant.reload.active?

            assert grant_active, "A rejected Edit hint must not revoke its RP grant"
            root_usable = root_token.reload.currently_usable?

            assert root_usable, "A rejected Edit hint must not revoke the operator root"
          end
        end
      end

      browser.post("/sign/out?ri=jp")

      assert_equal 303, browser.response.status, "#{scenario.fetch(:client_id)} RP sign-out must redirect"
      location = URI.parse(browser.response.location)
      query = Rack::Utils.parse_nested_query(location.query.to_s)

      assert_equal scenario.fetch(:expected_op_host), location.host, "#{scenario.fetch(:client_id)} OP host"
      assert_equal "/oidc/logout", location.path, "#{scenario.fetch(:client_id)} OP path"
      assert_equal client.client_id, query.fetch("client_id")
      stored_hint_matches = logout_hint.id_token == query.fetch("id_token_hint")

      assert stored_hint_matches, "RP sign-out must send its stored hint"
      state = query.fetch("state")

      assert_operator state.length, :>, 0, "RP sign-out must bind the completion with state"
      assert_not_includes scenario.fetch(:forbidden_op_hosts), location.host,
                          "#{scenario.fetch(:client_id)} must not go through another realm or Auth/Base staff"
      grant_active = grant.reload.active?

      assert grant_active, "RP sign-out leaves its grant active until Visa confirmation"
      root_usable = root_token.reload.currently_usable?

      assert root_usable, "RP sign-out must leave the operator root usable"

      return_uri = URI.parse(query.fetch("post_logout_redirect_uri"))

      assert_includes client.post_logout_redirect_uris, return_uri.to_s
      assert_equal scenario.fetch(:rp_host), return_uri.host, "#{scenario.fetch(:client_id)} callback host"
      assert_equal "/sign/out/completion", return_uri.path
      assert_equal({ "ri" => "jp" }, Rack::Utils.parse_nested_query(return_uri.query.to_s))

      if scenario.fetch(:client_id) == "edit-org-ww"
        assert_equal hosts.edit_staff.host, return_uri.host
        wrong_state = "#{(state[0] == "x") ? "y" : "x"}#{state[1..]}"
        [nil, wrong_state].each do |callback_state|
          callback_uri = return_uri.dup
          callback_params = Rack::Utils.parse_nested_query(callback_uri.query.to_s)
          callback_params["state"] = callback_state if callback_state
          callback_uri.query = callback_params.to_query
          browser.host!(hosts.edit_staff.host)
          browser.get(callback_uri.request_uri)

          assert_equal 404, browser.response.status, "Edit callback requires the issued state"
          grant_active = grant.reload.active?

          assert grant_active, "A rejected callback must leave the RP grant active"
          root_usable = root_token.reload.currently_usable?

          assert root_usable, "A rejected callback must not revoke the operator root"
        end
      else
        assert_equal hosts.base_staff.host, return_uri.host
      end

      callback_params = Rack::Utils.parse_nested_query(return_uri.query.to_s)
      callback_params["state"] = state
      return_uri.query = callback_params.to_query
      browser.host!(scenario.fetch(:rp_host))
      browser.get(return_uri.request_uri)

      assert_equal 200, browser.response.status, "#{scenario.fetch(:client_id)} completion page"
      if scenario.fetch(:client_id) == "edit-org-ww"
        assert_includes browser.response.headers.fetch("Clear-Site-Data"), '"storage"'
      else
        page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

        assert page, "Base ORG completion must render its Inertia page object"
        clear_history = JSON.parse(page.text).fetch("clearHistory")

        assert_instance_of TrueClass, clear_history, "Base ORG completion must set clearHistory to true"
      end

      browser.get(return_uri.request_uri)

      assert_equal 404, browser.response.status, "#{scenario.fetch(:client_id)} completion is single use"
    end
  end
end
