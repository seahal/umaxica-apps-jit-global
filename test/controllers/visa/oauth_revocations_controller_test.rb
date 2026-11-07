# frozen_string_literal: true

require "test_helper"

class VisaOauthRevocationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  APP_CLIENT_ID = "core-app-jp"
  ORG_CLIENT_ID = "core-org-jp"

  test "ZR-1 APP form revocation without browser metadata stops only its grant and refresh then fails" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    sibling = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: "warp-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    other_realm_root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    other_realm_grant = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: other_realm_root, oidc_client_id: ORG_CLIENT_ID,
      oidc_scope: "openid", oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    refresh_token = target.issue_refresh_token!
    endpoint = OidcIssuer.revocation_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint)

    post visa_app_oauth_revocation_url(host:), params: {
      token: refresh_token,
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: assertion,
    }, headers: { "Sec-Fetch-Site" => nil }

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
    assert_predicate other_realm_root.reload, :currently_usable?
    assert_predicate other_realm_grant.reload, :active?
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil response.headers["Set-Cookie"]

    post visa_app_oauth_token_url(host:), params: {
      grant_type: "refresh_token",
      refresh_token:,
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(
        client_id: APP_CLIENT_ID,
        token_url: OidcIssuer.token_endpoint("client"),
      ),
    }

    assert_response :bad_request
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
  end

  test "ZR-1 ORG form revocation without browser metadata stops only its grant and refresh then fails" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    sibling = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: "warp-org-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    other_realm_root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:two), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    other_realm_grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: other_realm_root, oidc_client_id: APP_CLIENT_ID,
      oidc_scope: "openid", oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    refresh_token = target.issue_refresh_token!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    assertion = OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint)

    post visa_org_oauth_revocation_url(host:), params: {
      token: refresh_token,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: assertion,
    }, headers: { "Sec-Fetch-Site" => nil }

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
    assert_predicate other_realm_root.reload, :currently_usable?
    assert_predicate other_realm_grant.reload, :active?
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil response.headers["Set-Cookie"]

    post visa_org_oauth_token_url(host:), params: {
      grant_type: "refresh_token",
      refresh_token:,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(
        client_id: ORG_CLIENT_ID,
        token_url: OidcIssuer.token_endpoint("operator"),
      ),
    }

    assert_response :bad_request
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
  end

  test "ZR-2 APP rejects missing, unknown, wrong-key, wrong-audience and expired client proofs" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("client")
    token_endpoint = OidcIssuer.token_endpoint("client")
    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    stop_count = OpAppAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}").count
    valid_assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint)
    wrong_key_assertion = OidcClientAssertionJwt.issue(
      client_id: ORG_CLIENT_ID, token_url: OidcIssuer.revocation_endpoint("operator"),
    )
    wrong_audience_assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: token_endpoint)
    expired_assertion = OidcClientAssertionJwt.issue(
      client_id: APP_CLIENT_ID, token_url: endpoint, now: Time.current - OidcClientAssertionJwt::TTL - 1.second,
    )
    now = Time.current
    issuer_namespace = OidcClientRegistry.jwt_namespace_for(APP_CLIENT_ID)
    issuer_id = "oidc_client:#{issuer_namespace}"
    wrong_subject_assertion = JitSecurityJwtKeyring.encode(
      {
        "iss" => APP_CLIENT_ID,
        "sub" => "warp-app-jp",
        "aud" => endpoint,
        "jti" => SecureRandom.uuid,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
        "typ" => OidcClientAssertionJwt::TOKEN_TYPE,
      },
      typ: OidcClientAssertionJwt::TOKEN_TYPE, issuer_id:,
    )
    wrong_issuer_assertion = JitSecurityJwtKeyring.encode(
      {
        "iss" => "warp-app-jp",
        "sub" => APP_CLIENT_ID,
        "aud" => endpoint,
        "jti" => SecureRandom.uuid,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
        "typ" => OidcClientAssertionJwt::TOKEN_TYPE,
      },
      typ: OidcClientAssertionJwt::TOKEN_TYPE, issuer_id:,
    )
    forged_header, payload, signature = valid_assertion.split(".")
    parsed_header = JSON.parse(Base64.urlsafe_decode64(forged_header))
    wrong_algorithm_assertion = [
      Base64.urlsafe_encode64(parsed_header.merge("alg" => "none").to_json, padding: false), payload, signature,
    ].join(".")
    invalid_credentials = [
      { client_id: APP_CLIENT_ID },
      { client_id: "" },
      { client_id: "0" },
      { client_id: "malformed client id" },
      { client_id: "missing-client",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: valid_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "unsigned-or-forged", },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_algorithm_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_issuer_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_subject_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_key_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_audience_assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: expired_assertion, },
    ]

    invalid_credentials.each do |credentials|
      post visa_app_oauth_revocation_url(host:), params: { token: target_refresh }.merge(credentials)

      assert_response :unauthorized
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, target_refresh
    end

    assert_predicate target.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_equal stop_count,
                 OpAppAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}").count
  end

  test "ZR-2 ORG rejects an APP assertion and an invalid registered-client proof" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    stop_count = OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
    valid_assertion = OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint)
    wrong_realm_assertion = OidcClientAssertionJwt.issue(
      client_id: APP_CLIENT_ID, token_url: OidcIssuer.revocation_endpoint("client"),
    )
    now = Time.current
    issuer_namespace = OidcClientRegistry.jwt_namespace_for(ORG_CLIENT_ID)
    issuer_id = "oidc_client:#{issuer_namespace}"
    wrong_subject_assertion = JitSecurityJwtKeyring.encode(
      {
        "iss" => ORG_CLIENT_ID,
        "sub" => "warp-org-jp",
        "aud" => endpoint,
        "jti" => SecureRandom.uuid,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
        "typ" => OidcClientAssertionJwt::TOKEN_TYPE,
      },
      typ: OidcClientAssertionJwt::TOKEN_TYPE, issuer_id:,
    )
    wrong_issuer_assertion = JitSecurityJwtKeyring.encode(
      {
        "iss" => "warp-org-jp",
        "sub" => ORG_CLIENT_ID,
        "aud" => endpoint,
        "jti" => SecureRandom.uuid,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
        "typ" => OidcClientAssertionJwt::TOKEN_TYPE,
      },
      typ: OidcClientAssertionJwt::TOKEN_TYPE, issuer_id:,
    )
    forged_header, payload, signature = valid_assertion.split(".")
    wrong_algorithm_assertion = [
      Base64.urlsafe_encode64(
        JSON.parse(Base64.urlsafe_decode64(forged_header)).merge("alg" => "none").to_json, padding: false,
      ), payload, signature,
    ].join(".")
    expired_assertion = OidcClientAssertionJwt.issue(
      client_id: ORG_CLIENT_ID,
      token_url: endpoint,
      now: Time.current - OidcClientAssertionJwt::TTL - 1.second,
    )
    invalid_credentials = [
      { client_id: ORG_CLIENT_ID },
      { client_id: "0" },
      { client_id: ORG_CLIENT_ID, client_secret: "wrong-secret" },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_realm_assertion, },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "unsigned-or-forged", },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_algorithm_assertion, },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_issuer_assertion, },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: wrong_subject_assertion, },
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: expired_assertion, },
      { client_id: "unknown-client", client_secret: "wrong-secret" },
      { client_id: ORG_CLIENT_ID, client_assertion_type: "wrong-type", client_assertion: "assertion" },
    ]

    invalid_credentials.each do |credentials|
      post visa_org_oauth_revocation_url(host:), params: { token: target_refresh }.merge(credentials)

      assert_response :unauthorized
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, target_refresh
    end

    assert_predicate target.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_equal stop_count,
                 OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
  end

  test "ZR-3 malformed body fields are bounded 400 responses and an authenticated unknown target is generic" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint)
    invalid_bodies = [
      { token: nil,
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "",
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: ["unknown-token"],
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "unknown-token",
        client_id: [APP_CLIENT_ID],
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "unknown-token",
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: { value: assertion }, },
    ]

    invalid_bodies.each do |body|
      post visa_app_oauth_revocation_url(host:), params: body

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body.fetch("error")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, APP_CLIENT_ID
    end

    post visa_app_oauth_revocation_url(host:), params: {
      token: "0",
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
    }

    assert_response :ok
    assert_equal "", response.body
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "ZR-3 ORG rejects zero-like client ids and JSON null security fields without mutation" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    stop_count = OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
    assertion = OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint)
    invalid_bodies = [
      { client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "",
        client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: ["unknown-token"],
        client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "unknown-token",
        client_id: [ORG_CLIENT_ID],
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, },
      { token: "unknown-token",
        client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: { value: assertion }, },
    ]

    invalid_bodies.each do |body|
      post visa_org_oauth_revocation_url(host:), params: body

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body.fetch("error")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end

    ["0", "malformed client id"].each do |client_id|
      post visa_org_oauth_revocation_url(host:), params: { token: "unknown-token", client_id: }

      assert_response :unauthorized
    end

    post visa_org_oauth_revocation_url(host:), params: {
      token: "unknown-token",
      client_id: ORG_CLIENT_ID,
      client_assertion: nil,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
    }, as: :json

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_includes response.headers.fetch("Cache-Control"), "no-store"

    post visa_org_oauth_revocation_url(host:), params: {
      token: "0",
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }

    assert_response :ok
    assert_equal "", response.body
    assert_predicate target.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_equal stop_count,
                 OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
  end

  test "ZR-4 APP ignores caller authority fields and rejects query credentials and body-query collisions" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("client")
    body = {
      token: "unknown-token",
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
      host: ENV.fetch("PUBLIC_VISA_STAFF_URL"),
      expected_resource_type: "operator",
      revocation_endpoint_uri: OidcIssuer.revocation_endpoint("operator"),
    }

    post visa_app_oauth_revocation_url(host:), params: body

    assert_response :ok
    assert_includes response.headers.fetch("Cache-Control"), "no-store"

    post "/oauth/revoke?client_id=#{APP_CLIENT_ID}", params: body

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")

    post "/oauth/revoke?client_id=#{APP_CLIENT_ID}", params: { token: "unknown-token" }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "ZR-4 ORG refuses an APP client assertion and body fields cannot switch its realm" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!

    post visa_org_oauth_revocation_url(host:), params: {
      token: "unknown-token",
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(
        client_id: APP_CLIENT_ID, token_url: OidcIssuer.revocation_endpoint("client"),
      ),
      expected_resource_type: "client",
      revocation_endpoint_uri: OidcIssuer.revocation_endpoint("client"),
      host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
    }

    assert_response :unauthorized
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_not_includes response.body, APP_CLIENT_ID
  end

  test "ZR-2 APP accepts a proof just before expiry and refuses at and after its expiry" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("client")
    expires_at = Time.zone.at((2.minutes.from_now).to_i)
    proofs =
      3.times.map do
        OidcClientAssertionJwt.issue(
          client_id: APP_CLIENT_ID, token_url: endpoint, now: expires_at - OidcClientAssertionJwt::TTL,
        )
      end
    cases = [
      [expires_at - 1.second, proofs.fetch(0), :ok],
      [expires_at, proofs.fetch(1), :unauthorized],
      [expires_at + 1.second, proofs.fetch(2), :unauthorized],
    ]

    cases.each do |request_time, proof, expected_status|
      travel_to(request_time) do
        post visa_app_oauth_revocation_url(host:), params: {
          token: "unknown-token",
          client_id: APP_CLIENT_ID,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: proof,
        }

        assert_response expected_status
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
      end
    end
  end

  test "ZR-2 ORG accepts a proof just before expiry and refuses at and after its expiry" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    expires_at = Time.zone.at((2.minutes.from_now).to_i)
    proofs =
      3.times.map do
        OidcClientAssertionJwt.issue(
          client_id: ORG_CLIENT_ID, token_url: endpoint, now: expires_at - OidcClientAssertionJwt::TTL,
        )
      end
    cases = [
      [expires_at - 1.second, proofs.fetch(0), :ok],
      [expires_at, proofs.fetch(1), :unauthorized],
      [expires_at + 1.second, proofs.fetch(2), :unauthorized],
    ]

    cases.each do |request_time, proof, expected_status|
      travel_to(request_time) do
        post visa_org_oauth_revocation_url(host:), params: {
          token: "unknown-token",
          client_id: ORG_CLIENT_ID,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: proof,
        }

        assert_response expected_status
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
      end
    end
  end

  test "ZR-5 APP refuses a bare token id, wrong verifier, foreign-client token and invalid Access JWT binding" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    sibling = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: "warp-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    other_realm_root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    other_realm_grant = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: other_realm_root, oidc_client_id: ORG_CLIENT_ID,
      oidc_scope: "openid", oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target.issue_refresh_token!
    sibling_refresh = sibling.issue_refresh_token!
    other_realm_refresh = other_realm_grant.issue_refresh_token!
    client = OidcClientRegistry.find!(APP_CLIENT_ID)
    invalid_access_token = AuthenticationTokenService.encode(
      clients(:one), host:, resource_type: "client", session_public_id: root.public_id,
                     base_session_public_id: root.public_id, oidc_sid: target.public_id, oidc_jti: SecureRandom.uuid,
                     expires_at: 1.minute.from_now, scopes: ["openid"], issuer: OidcIssuer.for_client(client),
                     audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                     subject: OidcSubject.for(clients(:one), resource_type: "client"), client_id: APP_CLIENT_ID,
    )
    invalid_targets = [
      target.public_id, "#{target.public_id}:wrong-verifier", sibling_refresh, other_realm_refresh,
      invalid_access_token,
    ]

    invalid_targets.each do |token|
      post visa_app_oauth_revocation_url(host:), params: {
        token:,
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: OidcClientAssertionJwt.issue(
          client_id: APP_CLIENT_ID, token_url: OidcIssuer.revocation_endpoint("client"),
        ),
      }

      assert_response :ok
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end

    assert_predicate target.reload, :active?
    assert_predicate sibling.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_predicate other_realm_root.reload, :currently_usable?
    assert_predicate other_realm_grant.reload, :active?
  end

  test "ZR-6 APP ignores victim cookies, Origin and Fetch Metadata without matching client proof" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    headers = {
      "Cookie" => "visa_session=victim-cookie; access_token=victim-access",
      "Origin" => "https://attacker.example",
      "Sec-Fetch-Site" => "cross-site",
    }

    ["cross-site", "same-site", "same-origin", nil, "none"].each do |fetch_site|
      post visa_app_oauth_revocation_url(host:), params: {
        token: target.public_id,
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "attacker-controlled-assertion",
      }, headers: headers.merge("Sec-Fetch-Site" => fetch_site)

      assert_response :unauthorized
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end

    assert_predicate target.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_nil response.headers["Set-Cookie"]
    assert_not_includes response.body, target.public_id

    post visa_app_oauth_revocation_url(host:), params: {
      token: target_refresh,
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(
        client_id: APP_CLIENT_ID, token_url: OidcIssuer.revocation_endpoint("client"),
      ),
    }, headers: headers.merge("Sec-Fetch-Site" => "same-site")

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate root.reload, :currently_usable?
  end

  test "ZR-7 APP rejects assertion replay and fresh-proof retry is idempotent" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    sibling = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: "warp-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    endpoint = OidcIssuer.revocation_endpoint("client")
    replayed_assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint)
    stop_count = OpAppAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}").count
    body = {
      token: target_refresh,
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: replayed_assertion,
    }

    post visa_app_oauth_revocation_url(host:), params: body

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?

    post visa_app_oauth_revocation_url(host:), params: body

    assert_response :unauthorized
    assert_predicate target.reload, :revoked?
    assert_equal stop_count + 1,
                 OpAppAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}").count

    post visa_app_oauth_revocation_url(host:), params: body.merge(
      client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
    )

    assert_response :ok
    assert_equal stop_count + 1,
                 OpAppAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}").count
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
  end

  test "ZR-5 and ZR-6 ORG do not let browser cookies or another grant authorize revocation" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    foreign = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: "warp-org-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    app_root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:two), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    app_grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: app_root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!(ORG_CLIENT_ID)
    invalid_access_token = AuthenticationTokenService.encode(
      operators(:one),
      host: URI.parse(client.redirect_uris.first).host,
      resource_type: "operator",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: target.public_id,
      oidc_jti: SecureRandom.uuid,
      expires_at: 1.minute.from_now,
      scopes: ["openid"],
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(operators(:one), resource_type: "operator"),
      client_id: ORG_CLIENT_ID,
    )
    target_refresh = target.issue_refresh_token!
    foreign_refresh = foreign.issue_refresh_token!
    app_refresh = app_grant.issue_refresh_token!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    no_proof_headers = {
      "Cookie" => "visa_session=victim-cookie; access_token=victim-access",
      "Origin" => "https://attacker.example",
      "Sec-Fetch-Site" => "cross-site",
    }

    ["cross-site", "same-site", "same-origin", nil, "none"].each do |fetch_site|
      post visa_org_oauth_revocation_url(host:), params: {
        token: target.public_id,
        client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "attacker-controlled-assertion",
      }, headers: no_proof_headers.merge("Sec-Fetch-Site" => fetch_site)

      assert_response :unauthorized
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end

    assert_predicate target.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_nil response.headers["Set-Cookie"]

    post visa_org_oauth_revocation_url(host:), params: {
      token: foreign_refresh,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }, headers: no_proof_headers.merge("Sec-Fetch-Site" => nil)

    assert_response :ok
    assert_predicate target.reload, :active?
    assert_predicate foreign.reload, :active?
    assert_predicate root.reload, :currently_usable?

    [
      target.public_id,
      "#{target.public_id}:#{SecureRandom.urlsafe_base64(32)}",
      app_refresh,
      invalid_access_token,
    ].each do |token|
      post visa_org_oauth_revocation_url(host:), params: {
        token:,
        client_id: ORG_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
      }, headers: no_proof_headers.merge("Sec-Fetch-Site" => nil)

      assert_response :ok
      assert_predicate target.reload, :active?
      assert_predicate app_grant.reload, :active?
    end

    post visa_org_oauth_revocation_url(host:), params: {
      token: target_refresh,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }, headers: no_proof_headers

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate foreign.reload, :active?
    assert_predicate root.reload, :currently_usable?
    assert_predicate app_root.reload, :currently_usable?
    assert_predicate app_grant.reload, :active?
  end

  test "ZR-7 concurrent APP requests with one assertion JTI cannot both authenticate" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    endpoint = OidcIssuer.revocation_endpoint("client")
    body = {
      token: "unknown-token",
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
    }
    ready = Queue.new
    start = Queue.new
    statuses = Queue.new
    browsers = [open_session, open_session]
    threads =
      browsers.map do |browser|
        browser.host!(host)
        browser.https!
        Thread.new do
          ready << true
          start.pop
          browser.post("/oauth/revoke", params: body, headers: { "Host" => host })
          statuses << browser.response.status
        end
      end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)

    assert_equal [200, 401], 2.times.map { statuses.pop }.sort
  end

  test "ZR-7 concurrent ORG requests with one assertion JTI cannot both authenticate" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    endpoint = OidcIssuer.revocation_endpoint("operator")
    body = {
      token: "unknown-token",
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }
    ready = Queue.new
    start = Queue.new
    statuses = Queue.new
    browsers = [open_session, open_session]
    threads =
      browsers.map do |browser|
        browser.host!(host)
        browser.https!
        Thread.new do
          ready << true
          start.pop
          browser.post("/oauth/revoke", params: body, headers: { "Host" => host })
          statuses << browser.response.status
        end
      end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)

    assert_equal [200, 401], 2.times.map { statuses.pop }.sort
  end

  test "ZR-7 ORG replay is rejected and a fresh-proof retry does not duplicate the grant stop" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    sibling = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: "warp-org-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    refresh_token = target.issue_refresh_token!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    replayed_assertion = OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint)
    stop_count = OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
    body = {
      token: refresh_token,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: replayed_assertion,
    }

    post visa_org_oauth_revocation_url(host:), params: body

    assert_response :ok
    assert_predicate target.reload, :revoked?
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?

    post visa_org_oauth_revocation_url(host:), params: body

    assert_response :unauthorized
    assert_predicate target.reload, :revoked?
    assert_equal stop_count + 1,
                 OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count

    post visa_org_oauth_revocation_url(host:), params: body.merge(
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    )

    assert_response :ok
    assert_equal stop_count + 1,
                 OpOrgAuthorityStop.where(authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}").count
    assert_predicate root.reload, :currently_usable?
    assert_predicate sibling.reload, :active?
  end

  test "ZR-8 APP assertion-store, grant-lookup and stop-write failures fail closed" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint)
    assertion_body = {
      token: "unknown-token",
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: assertion,
    }

    SecurityConsumedJti.stub(
      :consume!, ->(**) { raise ActiveRecord::StatementInvalid, "injected assertion store failure" },
    ) do
      post visa_app_oauth_revocation_url(host:), params: assertion_body
    end

    assert_response :unauthorized
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_not_includes response.body, "injected assertion store failure"

    root = ClientToken.create!(
      authentication_epoch: 0, user: clients(:one), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpAppGrant.create!(
      authentication_epoch: 0, client_token: root, oidc_client_id: APP_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    lookup_body = {
      token: target_refresh,
      client_id: APP_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
    }

    OpAppGrant.stub(:find_by, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
      post visa_app_oauth_revocation_url(host:), params: lookup_body
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate target.reload, :active?
    assert_not_includes response.body, target_refresh

    OpAppAuthorityStopGrantTarget.stub(
      :create!, ->(*, **) { raise ActiveRecord::StatementInvalid, "injected stop persistence failure" },
    ) do
      post visa_app_oauth_revocation_url(host:), params: lookup_body.merge(
        client_assertion: OidcClientAssertionJwt.issue(client_id: APP_CLIENT_ID, token_url: endpoint),
      )
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate target.reload, :active?
    assert_equal 0, OpAppAuthorityStop.where(
      authority_evidence_ref: "oauth_revocation:#{APP_CLIENT_ID}",
    ).count
    assert_not_includes response.body, "injected stop persistence failure"
  end

  test "ZR-8 ORG assertion-store, grant-lookup and stop-write failures fail closed" do
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! host
    https!
    endpoint = OidcIssuer.revocation_endpoint("operator")
    assertion_body = {
      token: "unknown-token",
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }

    SecurityConsumedJti.stub(
      :consume!, ->(**) { raise ActiveRecord::StatementInvalid, "injected assertion store failure" },
    ) do
      post visa_org_oauth_revocation_url(host:), params: assertion_body
    end

    assert_response :unauthorized
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_not_includes response.body, "injected assertion store failure"

    root = OperatorToken.create!(
      authentication_epoch: 0, staff: operators(:one), staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 2.days.from_now,
    )
    target = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token: root, oidc_client_id: ORG_CLIENT_ID, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.day.from_now,
    )
    target_refresh = target.issue_refresh_token!
    lookup_body = {
      token: target_refresh,
      client_id: ORG_CLIENT_ID,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
    }

    OpOrgGrant.stub(:find_by, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
      post visa_org_oauth_revocation_url(host:), params: lookup_body
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate target.reload, :active?
    assert_not_includes response.body, target_refresh

    OpOrgAuthorityStopGrantTarget.stub(
      :create!, ->(*, **) { raise ActiveRecord::StatementInvalid, "injected stop persistence failure" },
    ) do
      post visa_org_oauth_revocation_url(host:), params: lookup_body.merge(
        client_assertion: OidcClientAssertionJwt.issue(client_id: ORG_CLIENT_ID, token_url: endpoint),
      )
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_predicate target.reload, :active?
    assert_equal 0, OpOrgAuthorityStop.where(
      authority_evidence_ref: "oauth_revocation:#{ORG_CLIENT_ID}",
    ).count
    assert_not_includes response.body, "injected stop persistence failure"
  end

  test "ZR-9 both realms enforce the 20 per minute IP boundary with valid fresh proofs" do
    rate_store = Rails.configuration.x.rate_limit.fetch(:store)
    endpoints = [
      [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "/oauth/revoke", APP_CLIENT_ID, "client"],
      [ENV.fetch("PUBLIC_VISA_STAFF_URL"), "/oauth/revoke", ORG_CLIENT_ID, "operator"],
    ]

    rate_store.with do
      endpoints.each do |host, path, client_id, resource_type|
        endpoint = OidcIssuer.revocation_endpoint(resource_type)
        remote_ip = (resource_type == "client") ? "198.51.100.41" : "198.51.100.42"
        21.times do |index|
          post path, params: {
            token: "unknown-token",
            client_id:,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: OidcClientAssertionJwt.issue(client_id:, token_url: endpoint),
          }, headers: { "Host" => host, "REMOTE_ADDR" => remote_ip, "Sec-Fetch-Site" => nil }

          expected_status = (index < 20) ? :ok : :too_many_requests
          assert_response expected_status if [18, 19, 20].include?(index)
          assert_includes response.headers.fetch("Cache-Control"), "no-store" if index == 20
          assert_equal "60", response.headers["Retry-After"] if index == 20
          assert_not_includes response.body, client_id if index == 20
          assert_not_includes response.body, "unknown-token" if index == 20
        end
      end
    end
  end

  test "ZR-9 both realms enforce the 600 per minute authenticated-client boundary" do
    rate_store = Rails.configuration.x.rate_limit.fetch(:store)
    endpoints = [
      [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "/oauth/revoke", APP_CLIENT_ID, "client"],
      [ENV.fetch("PUBLIC_VISA_STAFF_URL"), "/oauth/revoke", ORG_CLIENT_ID, "operator"],
    ]

    rate_store.with do
      endpoints.each do |host, path, client_id, resource_type|
        endpoint = OidcIssuer.revocation_endpoint(resource_type)
        601.times do |index|
          remote_ip = "198.51.100.#{(index % 200) + 1}"
          post path, params: {
            token: "unknown-token",
            client_id:,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: OidcClientAssertionJwt.issue(client_id:, token_url: endpoint),
          }, headers: { "Host" => host, "REMOTE_ADDR" => remote_ip, "Sec-Fetch-Site" => nil }

          expected_status = (index < 600) ? :ok : :too_many_requests
          assert_response expected_status if [598, 599, 600].include?(index)
          assert_includes response.headers.fetch("Cache-Control"), "no-store" if index == 600
          assert_equal "60", response.headers["Retry-After"] if index == 600
          assert_not_includes response.body, client_id if index == 600
          assert_not_includes response.body, "unknown-token" if index == 600
        end
      end
    end
  end

  test "ZR-9 FQDN gate refuses before authentication and rate limiting with no-store" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    slot = FqdnAvailabilityRegistry.slot_for(host)
    flag = FqdnAvailabilityRegistry.flag_name_for(slot)
    Flipper.disable(flag)

    post(
      visa_app_oauth_revocation_url(host:), params: {
        token: "unknown-token",
        client_id: APP_CLIENT_ID,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "unverified-assertion",
      }, headers: { "Sec-Fetch-Site" => nil },
    )

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "fqdn_unavailable", response.parsed_body.fetch("error")
  ensure
    Flipper.enable(flag) if flag
  end

  test "ZR-10 only create is routable, private helpers stay private, and unsupported verbs do not revoke" do
    app_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    org_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    app_controller = Visa::App::Oauth::RevocationsController
    org_controller = Visa::Org::Oauth::RevocationsController

    assert_equal Set["create"], app_controller.action_methods
    assert_equal Set["create"], org_controller.action_methods
    assert_includes app_controller.private_instance_methods, :revoke
    assert_includes org_controller.private_instance_methods, :revoke
    assert_includes app_controller.private_instance_methods, :prepare_revocation_request!
    assert_includes org_controller.private_instance_methods, :prepare_revocation_request!

    host! app_host
    https!
    [
      -> { get("/oauth/revoke") },
      -> { head "/oauth/revoke" },
      -> { put("/oauth/revoke") },
      -> { patch("/oauth/revoke") },
      -> { delete("/oauth/revoke") },
      -> { post("/oauth/revoke/revoke") },
    ].each do |unsupported_request|
      unsupported_request.call

      assert_not_predicate response, :successful?
    end

    host! org_host
    get "/oauth/revoke"

    assert_not_predicate response, :successful?
  end
end
