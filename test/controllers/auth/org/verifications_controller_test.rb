# frozen_string_literal: true

require "test_helper"

class Auth::Org::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :operator_passkeys

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  test "GET redeems the admission and the entry page offers the operator's passkey only" do
    actor = operators(:one)
    token = operator_tokens(:one)
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: entry_ref)
    [{}, { "Sec-Fetch-Mode" => "navigate" }, { "Sec-Fetch-Dest" => "document" },
     { "Sec-Fetch-Mode" => "cors", "Sec-Fetch-Dest" => "document" },
     { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "empty" },
     { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "iframe" },].each do |headers|
      get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: headers

      assert_response :bad_request
      assert_not_predicate binding.reload, :redeemed?
      assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    end
    head auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_not_predicate binding.reload, :redeemed?
    assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_equal auth_org_verification_path(ri: "jp"), URI.parse(response.location).request_uri

    foreign = open_session
    foreign.host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))
    foreign.https!
    foreign.get(auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS)

    assert_equal 409, foreign.response.status
    assert_not foreign.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    [9, 10, 11].each do |seconds|
      OperatorAuthAdmissionBinding.stub(:database_now, binding.created_at + seconds.seconds) do
        get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS
      end

      assert_equal((seconds == 9) ? 303 : 400, response.status)
      assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
      assert_equal 1, OperatorAuthCeremonySession.where(
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      ).count
    end

    get auth_org_verification_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal(
      [{ "key" => "passkey",
         "label" => I18n.t("sign.org.verification.new.methods.passkey"),
         "href" => new_auth_org_verification_passkey_path(ri: "jp"), }],
      props.fetch("methods"),
    )
    assert_equal auth_org_verification_cancellation_path(ri: "jp"), props.fetch("cancel").fetch("action")
    assert_equal "pending", transaction.reload.status
    assert_nil token.reload.last_step_up_at
    token.device_session.revoke!
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
  end

  # Sentinels of the reference parameter: missing, empty, unknown, NUL-bearing, and two references at once.
  test "the entry refuses a missing, empty, unknown or ambiguous admission reference without redirecting to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    existing_session_count = OperatorAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count

    get auth_org_verification_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]

    [
      {}, { entry_ref: "" }, { entry_ref: "unknown-reference" }, { entry_ref: "abc\u0000def" }, { entry_ref: "0" },
      { entry_ref: "a", transaction_ref: "b" },
    ].each do |params|
      get auth_org_verification_path(ri: "jp"), params: params, headers: NAVIGATION_HEADERS

      assert_response :bad_request, params.inspect
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil response.headers["Location"]
    end
    assert_equal existing_session_count,
                 OperatorAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
  end

  test "an admission issued for the org surface is refused on the app host" do
    actor = operators(:one)
    token = operator_tokens(:one)
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    existing_session_count = ClientAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
    get auth_app_verification_path(ri: "jp"), params: { entry_ref: entry_ref }, headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_equal existing_session_count,
                 ClientAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
    assert_equal "pending", transaction.reload.status
    assert_not_predicate OperatorAuthAdmissionBinding.find_by!(entry_ref: entry_ref), :redeemed?
  end
end
