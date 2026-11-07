# frozen_string_literal: true

require "test_helper"

class BaseOrgIdentityRpRootFeatureRefusalTest < ActionDispatch::IntegrationTest
  test "local RP session receives explicit refusal for root token features" do
    previous_role = ENV["UMAXICA_RUNTIME_ROLE"]
    previous_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    client_id = "base-org-ww"
    cell = RpCellBinding.for_client(client_id)
    ENV["UMAXICA_RUNTIME_ROLE"] = "#{cell.connection.tr("_", "-")}-#{cell.region}"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    OidcOpJwksClient::CLIENTS.clear
    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    https!

    operator = operators(:one)
    root = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    client = OidcClientRegistry.find!(client_id)
    verifier = SecureRandom.urlsafe_base64(48)
    params = {
      client_id: client_id,
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    code = OidcAuthorizationCodeIssuer.call(
      client: client, params: params, resource: operator, session_token: root, authentication_event_at: 1.minute.ago,
    )
    exchange =
      OidcClientRegistry.stub(
        :verify_client_assertion,
        ->(id, *, **) {
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true, client: OidcClientRegistry.find(id),
            step_up_claims_state: :none, step_up_expectation: nil,
          )
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: code.code, redirect_uri: code.redirect_uri, client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "local-cell-test-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("operator"), code_verifier: verifier,
          expected_resource_type: "operator",
        )
      end

    assert_predicate exchange, :success?
    tokens = exchange.token_response
    payload, = JWT.decode(tokens.fetch(:id_token), nil, false)
    enrollment = RpCallbackCommitter.call(
      cell: cell, issuer: payload.fetch("iss"), subject: payload.fetch("sub"), sid: payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = tokens.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = tokens.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

    ["/sessions", "/identity/secrets"].each do |path|
      get(path, params: { ri: "jp" })

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    end

    token_state = root.reload.attributes
    credential_count = operator.staff_secret_credentials.count
    delete("/sessions/other", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body

    post("/identity/secrets/nonexistent/removal", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body

    assert_equal token_state, root.reload.attributes
    assert_equal credential_count, operator.staff_secret_credentials.count

    cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
    get("/sessions", params: { ri: "jp" })

    assert_not_equal 503, response.status
  ensure
    previous_role.nil? ? ENV.delete("UMAXICA_RUNTIME_ROLE") : ENV["UMAXICA_RUNTIME_ROLE"] = previous_role
    previous_admission.nil? ? ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") :
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_admission
    OidcOpJwksClient::CLIENTS.clear
  end
end
