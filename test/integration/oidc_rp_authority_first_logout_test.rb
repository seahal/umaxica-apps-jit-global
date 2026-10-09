# frozen_string_literal: true

require "test_helper"

class OidcRpAuthorityFirstLogoutTest < ActionDispatch::IntegrationTest
  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    host! @core_host
  end

  test "authority-first logout revokes the parent before origin cleanup" do # rubocop:disable Minitest/MultipleAssertions -- Verifies the ordered authority and origin cleanup boundaries.
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    core_session, core_refresh =
      begin
        fv5040 = root_token
        fv5041 = "core-app"
        fv5039 = OidcClientRegistry.find!(fv5041)
        fv5038 = ClientRpSession.create!(
          client_token: fv5040,
          oidc_client_id: fv5039.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        [fv5038, fv5038.issue_refresh_token!]
      end
    sibling_session, sibling_refresh =
      begin
        fv5036 = root_token
        fv5037 = "warp-app"
        fv5035 = OidcClientRegistry.find!(fv5037)
        fv5034 = ClientRpSession.create!(
          client_token: fv5036,
          oidc_client_id: fv5035.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        [fv5034, fv5034.issue_refresh_token!]
      end
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5029 = user
        fv5031 = root_token
        fv5030 = core_session
        fv5033 = "core-app"
        fv5032 = @core_host
        fv5028 = OidcClientRegistry.find!(fv5033)
        AuthenticationTokenService.encode(
          fv5029,
          host: fv5032,
          resource_type: "client",
          session_public_id: fv5031.public_id,
          base_session_public_id: fv5031.public_id,
          oidc_sid: fv5030.public_id,
          oidc_jti: fv5030.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5028),
          audiences: [fv5028.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5028),
          subject: OidcSubject.for(fv5029, resource_type: "client"),
          client_id: fv5028.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = core_refresh

    post core_app_sign_out_url(ri: "jp")

    assert_response :see_other, response.body
    authority_uri = URI.parse(response.location)
    authority_query = Rack::Utils.parse_nested_query(authority_uri.query.to_s)
    challenge = authority_query.fetch("logout_challenge")
    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)

    assert_equal @base_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path
    assert_equal AcmeLogoutTransaction::BROWSER_RP_WORKFLOW, transaction.workflow
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.expected_step
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?

    host! @base_host
    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_select "form[action=?][method=?]", base_app_oidc_logout_path, "post"
    assert_predicate root_token.reload, :currently_usable?

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: {
      "Origin" => "https://#{@core_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other, response.body
    origin_uri = URI.parse(response.location)

    assert_equal @core_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path
    assert_equal challenge, Rack::Utils.parse_nested_query(origin_uri.query.to_s).fetch("logout_challenge")

    transaction.reload

    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.expected_step
    assert_equal [
      AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
      AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
    ], transaction.completed_steps
    assert_not_predicate root_token.reload, :currently_usable?
    assert_not core_session.reload.active?
    assert_not sibling_session.reload.active?
    assert_not core_session.authenticate_refresh_token(core_refresh)
    assert_not sibling_session.authenticate_refresh_token(sibling_refresh)
    assert_nil sibling_session.reload.revoked_at

    # The initiating RP can arrive with a row that was revoked independently after the parent
    # phase. Phase 4 is idempotent and must still finalize the durable transaction.
    core_session.revoke!(status: "success")

    host! @core_host
    get core_app_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_includes response.body, "logout_challenge", response.body

    post core_app_sign_out_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: {
      "Origin" => "https://#{@core_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other, response.body
    completion_uri = URI.parse(response.location)

    assert_equal @core_host, completion_uri.host
    assert_equal "/sign/out", completion_uri.path
    assert_predicate transaction.reload, :finalized?
    assert_predicate core_session.reload, :revoked?
    assert_nil sibling_session.reload.revoked_at

    get completion_uri.request_uri

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "an untrusted origin cannot commit authority-first logout" do
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    core_session, =
      begin
        fv5026 = root_token
        fv5027 = "core-app"
        fv5025 = OidcClientRegistry.find!(fv5027)
        fv5024 = ClientRpSession.create!(
          client_token: fv5026,
          oidc_client_id: fv5025.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        [fv5024, fv5024.issue_refresh_token!]
      end
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5019 = user
        fv5021 = root_token
        fv5020 = core_session
        fv5023 = "core-app"
        fv5022 = @core_host
        fv5018 = OidcClientRegistry.find!(fv5023)
        AuthenticationTokenService.encode(
          fv5019,
          host: fv5022,
          resource_type: "client",
          session_public_id: fv5021.public_id,
          base_session_public_id: fv5021.public_id,
          oidc_sid: fv5020.public_id,
          oidc_jti: fv5020.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5018),
          audiences: [fv5018.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5018),
          subject: OidcSubject.for(fv5019, resource_type: "client"),
          client_id: fv5018.client_id,
        )
      end

    post(core_app_sign_out_path(ri: "jp"))

    authority_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)
    challenge = authority_query.fetch("logout_challenge")

    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host!(@base_host)
    post(
      base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
        "Origin" => "https://attacker.example",
        "Sec-Fetch-Site" => "cross-site",
      },
    )

    assert_response :unprocessable_entity
    assert_predicate root_token.reload, :currently_usable?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  test "Base self-RP logout returns to Base without an Auth hop" do
    user = clients(:one)
    root_token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    rp_session, refresh_token =
      begin
        fv5016 = root_token
        fv5017 = "base-app-ww"
        fv5015 = OidcClientRegistry.find!(fv5017)
        fv5014 = ClientRpSession.create!(
          client_token: fv5016,
          oidc_client_id: fv5015.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        [fv5014, fv5014.issue_refresh_token!]
      end
    host! @base_host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5009 = user
        fv5011 = root_token
        fv5010 = rp_session
        fv5013 = "base-app-ww"
        fv5012 = @base_host
        fv5008 = OidcClientRegistry.find!(fv5013)
        AuthenticationTokenService.encode(
          fv5009,
          host: fv5012,
          resource_type: "client",
          session_public_id: fv5011.public_id,
          base_session_public_id: fv5011.public_id,
          oidc_sid: fv5010.public_id,
          oidc_jti: fv5010.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5008),
          audiences: [fv5008.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5008),
          subject: OidcSubject.for(fv5009, resource_type: "client"),
          client_id: fv5008.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    post base_app_sign_out_path(ri: "jp")

    assert_response :see_other
    authority_uri = URI.parse(response.location)
    challenge = Rack::Utils.parse_nested_query(authority_uri.query.to_s).fetch("logout_challenge")

    assert_equal @base_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{@base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal @base_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path

    get base_app_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_app_sign_out_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{@base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_predicate root_token.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
    assert_not_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), response.location.to_s
  end

  test "Edit RP logout returns through the staff Base authority" do
    operator = operators(:one)
    root_token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
    )
    rp_session, refresh_token =
      begin
        fv5007 = root_token
        fv5006 = OidcClientRegistry.find!("edit-org")
        fv5005 = OperatorRpSession.create!(
          operator_token: fv5007,
          oidc_client_id: fv5006.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
        [fv5005, fv5005.issue_refresh_token!]
      end
    edit_host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    base_staff_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! edit_host
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5001 = operator
        fv5003 = root_token
        fv5002 = rp_session
        fv5004 = edit_host
        fv5000 = OidcClientRegistry.find!("edit-org")
        AuthenticationTokenService.encode(
          fv5001,
          host: fv5004,
          resource_type: "operator",
          session_public_id: fv5003.public_id,
          base_session_public_id: fv5003.public_id,
          oidc_sid: fv5002.public_id,
          oidc_jti: fv5002.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5000),
          audiences: [fv5000.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5000),
          subject: OidcSubject.for(fv5001, resource_type: "operator"),
          client_id: fv5000.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token

    post edit_org_sign_out_path(ri: "jp")

    assert_response :see_other
    authority_uri = URI.parse(response.location)
    challenge = Rack::Utils.parse_nested_query(authority_uri.query.to_s).fetch("logout_challenge")

    assert_equal base_staff_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    host! base_staff_host
    get base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{edit_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal edit_host, origin_uri.host
    assert_equal "/sign/out", origin_uri.path

    host! edit_host
    get edit_org_sign_out_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post edit_org_sign_out_path(logout_challenge: challenge, ri: "jp"), headers: {
      "Origin" => "https://#{edit_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_predicate root_token.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
  end

  private
end
