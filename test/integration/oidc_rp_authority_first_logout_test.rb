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
        fv5041 = "core-app-jp"
        fv5039 = OidcClientRegistry.find!(fv5041)
        fv5038 = OpAppGrant.create!(
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
        fv5037 = "warp-app-jp"
        fv5035 = OidcClientRegistry.find!(fv5037)
        fv5034 = OpAppGrant.create!(
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
        fv5033 = "core-app-jp"
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
    origin_session_cookie = session_cookie_pair

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
    assert_predicate core_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      id_token_hint: "untrusted-hint",
      ri: "jp",
    ), headers: with_session_cookie(
      {
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    host! @base_host
    authority_access_token = AuthenticationToken.encode(
      user,
      host: @base_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    authority_token_payload = AuthenticationToken.decode(
      authority_access_token,
      host: @base_host,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )

    assert_equal user.id.to_s, AuthenticationToken.extract_subject(authority_token_payload)
    assert_equal root_token.device_session_record.public_id,
                 AuthenticationToken.extract_session_id(authority_token_payload)
    assert_equal user.public_id, transaction.actor_ref
    assert ClientDeviceSession.exists?(id: core_session.device_session_id, user_id: user.id)
    assert_equal root_token.device_session_id, core_session.device_session_id
    assert_equal root_token.class, core_session.parent_token.class
    base_authority_cookie =
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(authority_access_token)}"
    base_authority_headers = {
      "Host" => @base_host,
      "Cookie" => base_authority_cookie,
      "HTTP_COOKIE" => base_authority_cookie,
    }

    same_actor_other_parent = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_user = clients(:two)
    other_actor_parent = ClientToken.create!(
      user: other_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    same_actor_other_parent_access_token = AuthenticationToken.encode(
      user,
      host: @base_host,
      session_public_id: same_actor_other_parent.device_session.public_id,
      oidc_sid: same_actor_other_parent.device_session.public_id,
      oidc_jti: same_actor_other_parent.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: same_actor_other_parent.authentication_context_value.to_s,
    )
    other_actor_access_token = AuthenticationToken.encode(
      other_user,
      host: @base_host,
      session_public_id: other_actor_parent.device_session.public_id,
      oidc_sid: other_actor_parent.device_session.public_id,
      oidc_jti: other_actor_parent.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: other_actor_parent.authentication_context_value.to_s,
    )

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: with_session_cookie(
      {
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      ri: "jp",
    ), headers: with_session_cookie(
      {
        "Host" => @base_host,
        "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(same_actor_other_parent_access_token)}",
        "HTTP_COOKIE" =>
              "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(same_actor_other_parent_access_token)}",
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate same_actor_other_parent.reload, :currently_usable?
    assert_predicate other_actor_parent.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: with_session_cookie(
      {
        "Host" => @base_host,
        "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(other_actor_access_token)}",
        "HTTP_COOKIE" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(other_actor_access_token)}",
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate same_actor_other_parent.reload, :currently_usable?
    assert_predicate other_actor_parent.reload, :currently_usable?
    assert_predicate core_session.reload, :active?
    assert_predicate sibling_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    post base_app_oidc_logout_path(
      logout_challenge: challenge,
      session_ref: same_actor_other_parent.public_id,
      ri: "jp",
    ), headers: with_session_cookie(
      base_authority_headers.merge(
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-site",
      ), session_cookie: origin_session_cookie,
    )

    assert_not_predicate root_token.reload, :currently_usable?
    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step
    assert_response :see_other, response.body
    origin_uri = URI.parse(response.location)

    assert_equal @core_host, origin_uri.host
    assert_equal "/sign/out/completion", origin_uri.path
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
    assert_predicate sibling_session.reload, :revoked?
    assert_equal "success", sibling_session.last_logout_status

    # R5-WU09/WU16: the same OP commit recorded the realm logout flow, one participant and outbox
    # row per RP grant, and a browser receipt; Base /sign/bye reads it without changing state.
    flow = OpAppLogoutFlow.find_by!(target_root_ref: root_token.public_id)

    assert_not_nil flow.op_revoked_at
    assert_equal [core_session.public_id, sibling_session.public_id].sort,
                 OpAppLogoutFlowParticipant.where(logout_flow_id: flow.id).pluck(:sid).sort
    assert_equal 1, OpAppLogoutReceipt.where(logout_flow_id: flow.id, consumed_at: nil).count

    # The initiating RP can arrive with a row that was revoked independently after the parent
    # phase. Phase 4 is idempotent and must still finalize the durable transaction.
    core_session.revoke!(status: "success")

    host! @core_host
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_includes response.body, "logout_challenge", response.body
    form = response.parsed_body.at_css('form[method="post"]')
    form_action = form["action"]
    form_params =
      form.css("input[name]").each_with_object({}) do |input, values|
        values[input["name"]] = input["value"]
      end

    assert_equal "/sign/out/completion", URI.parse(form_action).path
    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step

    failed_revoke = RpSessionRevoker::Result.new(success: false, revoked_count: 0)
    RpSessionRevoker.stub(:call, ->(**) { failed_revoke }) do
      post core_app_sign_out_completion_path(
        logout_challenge: challenge,
        ri: "jp",
      ), params: form_params, headers: with_session_cookie(
        {
          "Origin" => "https://#{@core_host}",
          "Sec-Fetch-Site" => "same-origin",
        }, session_cookie: origin_session_cookie,
      )
    end

    # The parent is already revoked, so a failed origin cleanup is the global result with this
    # origin's cleanup incomplete, never "sign-out was not completed" (REQ-008, DEC-046).
    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED, transaction.reload.expected_step

    post core_app_sign_out_completion_path(
      logout_challenge: challenge,
      ri: "jp",
    ), params: form_params.except("logout_intent_proof"), headers: with_session_cookie(
      {
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-origin",
      }, session_cookie: origin_session_cookie,
    )

    assert_response :unprocessable_entity
    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED, transaction.reload.expected_step

    post core_app_sign_out_completion_path(
      logout_challenge: challenge,
      ri: "jp",
    ), params: form_params, headers: with_session_cookie(
      {
        "Origin" => "https://#{@core_host}",
        "Sec-Fetch-Site" => "same-origin",
      }, session_cookie: origin_session_cookie,
    )

    assert_response :see_other, response.body
    completion_uri = URI.parse(response.location)

    assert_equal @core_host, completion_uri.host
    assert_equal "/sign/out/completion", completion_uri.path
    assert_predicate transaction.reload, :finalized?
    assert_predicate core_session.reload, :revoked?
    assert_predicate sibling_session.reload, :revoked?
    assert_equal "success", sibling_session.last_logout_status

    get completion_uri.request_uri

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "Base Com confirms only the current Visitor parent" do
    visitor = visitors(:reserved_visitor)
    root_token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )
    rp_session = OpComGrant.create!(
      visitor_token: root_token,
      oidc_client_id: "core-com-jp",
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    client = OidcClientRegistry.find!("core-com-jp")
    issue_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "core",
      initiating_client_id: client.client_id,
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: "core",
        surface: "com",
        ri: "jp",
      ),
      actor_ref: visitor.public_id,
      session_ref: rp_session.public_id,
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      **AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
        session_record: rp_session,
        resource_type: "visitor",
        origin_intent_digest: "d".b * 32,
      ),
      surface: "com",
      ri: "jp",
    )

    assert_predicate issue_result, :success?
    transaction = issue_result.transaction
    base_com_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    core_com_host = ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    host! base_com_host

    get base_com_oidc_logout_path(logout_challenge: transaction.logout_challenge, ri: "jp")

    assert_response :ok
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    post base_com_oidc_logout_path(logout_challenge: transaction.logout_challenge, ri: "jp"), headers: {
      "Origin" => "https://#{core_com_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.reload.expected_step

    authority_access_token = AuthenticationToken.encode(
      visitor,
      host: base_com_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "visitor",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("visitor"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    authority_cookie =
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(authority_access_token)}"

    post base_com_oidc_logout_path(logout_challenge: transaction.logout_challenge, ri: "jp"), headers: {
      "Host" => base_com_host,
      "Cookie" => authority_cookie,
      "HTTP_COOKIE" => authority_cookie,
      "Origin" => "https://#{core_com_host}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other
    assert_not_predicate root_token.reload, :currently_usable?
    assert_not_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step
    origin_uri = URI.parse(response.location)

    assert_equal core_com_host, origin_uri.host
    assert_equal "/sign/out/completion", origin_uri.path
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
        fv5027 = "core-app-jp"
        fv5025 = OidcClientRegistry.find!(fv5027)
        fv5024 = OpAppGrant.create!(
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
        fv5023 = "core-app-jp"
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
        fv5014 = OpAppGrant.create!(
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
    origin_session_cookie = session_cookie_pair

    assert_equal @base_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok

    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: with_session_cookie(
      {
        "Origin" => "https://#{@base_host}",
        "Sec-Fetch-Site" => "same-origin",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step

    authority_access_token = AuthenticationToken.encode(
      user,
      host: @base_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    authority_cookie =
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(authority_access_token)}"

    post base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: with_session_cookie(
      {
        "Host" => @base_host,
        "Cookie" => authority_cookie,
        "HTTP_COOKIE" => authority_cookie,
        "Origin" => "https://#{@base_host}",
        "Sec-Fetch-Site" => "same-origin",
      }, session_cookie: origin_session_cookie,
    )

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal @base_host, origin_uri.host
    assert_equal "/sign/out/completion", origin_uri.path

    get base_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    form_params = response_form_params

    post base_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"), params: form_params, headers: {
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
        fv5006 = OidcClientRegistry.find!("edit-org-ww")
        fv5005 = OpOrgGrant.create!(
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
        fv5000 = OidcClientRegistry.find!("edit-org-ww")
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
    origin_session_cookie = session_cookie_pair

    assert_equal base_staff_host, authority_uri.host
    assert_equal "/oidc/logout", authority_uri.path

    host! base_staff_host
    get base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step

    post base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: with_session_cookie(
      {
        "Origin" => "https://#{edit_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_idp_session_error_response
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step

    authority_access_token = AuthenticationToken.encode(
      operator,
      host: base_staff_host,
      session_public_id: root_token.device_session_record.public_id,
      oidc_sid: root_token.device_session_record.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: "operator",
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    authority_cookie =
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(authority_access_token)}"

    post base_org_oidc_logout_path(logout_challenge: challenge, ri: "jp"), headers: with_session_cookie(
      {
        "Host" => base_staff_host,
        "Cookie" => authority_cookie,
        "HTTP_COOKIE" => authority_cookie,
        "Origin" => "https://#{edit_host}",
        "Sec-Fetch-Site" => "same-site",
      }, session_cookie: origin_session_cookie,
    )

    assert_response :see_other
    origin_uri = URI.parse(response.location)

    assert_equal edit_host, origin_uri.host
    assert_equal "/sign/out/completion", origin_uri.path

    host! edit_host
    get edit_org_sign_out_completion_path(logout_challenge: challenge, ri: "jp")

    assert_response :ok
    form = response.parsed_body.at_css('form[method="post"]')
    form_action = form["action"]
    form_params =
      form.css("input[name]").each_with_object({}) do |input, values|
        values[input["name"]] = input["value"]
      end

    assert_equal "/sign/out/completion", URI.parse(form_action).path

    post edit_org_sign_out_completion_path(
      logout_challenge: challenge,
      ri: "jp",
    ), params: form_params, headers: {
      "Origin" => "https://#{edit_host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
    assert_predicate AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge), :finalized?
    assert_predicate root_token.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
  end

  private

  def assert_idp_session_error_response
    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
  end

  def session_cookie_pair
    key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    value = cookies.to_hash[key]
    return if value.blank?

    "#{key}=#{Rack::Utils.escape(value)}"
  end

  def with_session_cookie(headers, session_cookie:)
    return headers if session_cookie.blank?

    cookie = headers["Cookie"].presence || headers["HTTP_COOKIE"].to_s
    cookie = cookie.split(/;\s*/).reject { |entry| entry.start_with?("#{session_cookie.split("=", 2).first}=") }
    cookie << session_cookie
    value = cookie.join("; ")
    headers.merge("Cookie" => value, "HTTP_COOKIE" => value)
  end

  def response_form_params
    form = response.parsed_body.at_css('form[method="post"]')
    return form.css("input[name]").each_with_object({}) do |input, values|
      values[input["name"]] = input["value"]
    end if form

    page = response.parsed_body.at_css('script[type="application/json"][data-page]')
    props = JSON.parse(page.text).fetch("props").fetch("form")
    props.slice("logout_challenge", "ri", "logout_intent_proof").compact
  end
end
