# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::Oidc::CallbacksControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
    @operator = operators(:one)
    OperatorIdentityState.ensure_defaults!
    OperatorIdentity.create!(
      issuer: OidcIssuer.for_resource_type("operator"),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      audience: "base-org-ww",
      source_record_id: @operator.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
    @grant = OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get tech_org_sign_show_path(ri: "jp")
    csrf_token = css_select('input[name="authenticity_token"]').first["value"]
    post tech_org_sign_create_path(ri: "jp"),
         params: { authenticity_token: csrf_token, pt: "/dashboard" },
         headers: {
           "Origin" => "https://#{@host}",
           "Sec-Fetch-Site" => "same-origin",
         }

    assert_response :see_other
    authorize_params = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    @state = authorize_params.fetch("state")
    flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(@state)
    @client = OidcClientRegistry.find!("tech-org")
    authentication_event_at = 1.minute.ago
    @operator_token = OperatorToken.create!(staff: @operator, authentication_event_at: authentication_event_at)
    code = OidcAuthorizationCodeIssuer.call(
      client: @client,
      params: authorize_params.symbolize_keys,
      resource: @operator,
      session_token: @operator_token,
      authentication_event_at: authentication_event_at,
    )
    @code = code
    @token_url = OidcIssuer.token_endpoint("operator")
    @exchange_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) {
          client_id == "tech-org" && assertion.present? && token_url == @token_url
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code.code,
          redirect_uri: code.redirect_uri,
          client_id: "tech-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "tech-callback-test-assertion",
          token_endpoint_uri: @token_url,
          code_verifier: flow.fetch("code_verifier"),
          expected_resource_type: "operator",
        )
      end

    assert_predicate @exchange_result, :success?

    @token_response = @exchange_result.token_response
    id_token_payload, = JWT.decode(@token_response.fetch(:id_token), nil, false)
    @candidate_session = OperatorRpSession.find_by!(public_id: id_token_payload.fetch("sid"))
    @access_token_authentication = OidcAccessTokenAuthenticator.call(
      access_token: @token_response.fetch(:access_token),
      resource_type: "operator",
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      authorization_scheme: "Bearer",
    )
    @id_token_verification = OidcIdTokenVerifier.call(
      id_token: @token_response.fetch(:id_token),
      client_id: "tech-org",
      resource_type: "operator",
      expected_nonce: flow.fetch("nonce"),
      issuer: OidcIssuer.for_resource_type("operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
    )
    @token_result = OidcRpTokenClient::Result.new(success: true, token_response: @token_response, error: nil)
    @userinfo_result = OidcRpUserInfoClient::Result.new(
      success: true,
      claims: { "sub" => OidcSubject.for(@operator, resource_type: "operator") },
      error: nil,
      dependency_failure: false,
    )
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  test "a valid authorized callback establishes the Tech session and reaches the dashboard" do
    assert_predicate @access_token_authentication, :success?, @access_token_authentication.error.inspect
    assert_predicate @id_token_verification, :success?, @id_token_verification.error.inspect

    OidcRpTokenClient.stub(:call, @token_result) do
      OidcRpUserInfoClient.stub(:call, @userinfo_result) do
        get "/oidc/callback",
            params: {
              code: @code.code,
              state: @state,
              iss: OidcIssuer.for_resource_type("operator"),
            }
      end
    end

    assert_response :redirect
    assert_equal "/dashboard", URI.parse(response.location).path
    get tech_org_dashboard_path(ri: "jp")

    assert_response :success
    assert_select "h1", I18n.t("tech.org.dashboard.heading")
    assert_predicate @candidate_session.reload, :active?
  end

  test "a capability revoked after token exchange refuses the candidate and revokes only its Tech session" do
    @grant.update!(revoked_at: Time.current, revoked_by_operator: operators(:two), revoke_reason_code: "duty_ended")

    OidcRpTokenClient.stub(:call, @token_result) do
      OidcRpUserInfoClient.stub(:call, @userinfo_result) do
        get "/oidc/callback",
            params: {
              code: @code.code,
              state: @state,
              iss: OidcIssuer.for_resource_type("operator"),
            }
      end
    end

    assert_response :forbidden
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "h1", I18n.t("tech.org.access_denial.heading")
    assert_no_set_cookie OidcRpBrowserCredentialContract::ACCESS_COOKIE
    assert_no_set_cookie OidcRpBrowserCredentialContract::REFRESH_COOKIE
    assert_predicate @candidate_session.reload, :revoked?
    assert_predicate @operator_token.reload, :currently_usable?
    assert_not OperatorOidcIdentityBinding.exists?(audience: @client.aud)
  end
end
