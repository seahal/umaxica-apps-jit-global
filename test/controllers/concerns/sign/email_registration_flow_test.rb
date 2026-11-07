# frozen_string_literal: true

require "test_helper"

class SignEmailRegistrationFlowTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!("base-app-ww")
    @token.device_session_record!
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: @token.authentication_epoch,
      client_token: @token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 10.minutes,
    )
    refresh_token = grant.issue_refresh_token!
    access_token = AuthenticationTokenService.encode(
      @user,
      host: @host,
      resource_type: "client",
      session_public_id: @token.public_id,
      base_session_public_id: @token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: now,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: client.client_id,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id),
      issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      sid: grant.public_id,
      absolute_expires_at: grant.refresh_token_expires_at,
    )
    raise ArgumentError, "Base APP RP test enrollment failed: #{enrollment.outcome}" unless enrollment.success?

    @rp_session = enrollment.session
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    selection = BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @rp_session)

    assert_equal "selected", selection.fetch(:status)
    assert_predicate RpBaseAppSessionSelection.find_by(rp_session_id: @rp_session.id), :present?
    cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh_token)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{@rp_session.public_id}",
    ].join("; ")
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "Cookie" => cookie,
      "HTTP_COOKIE" => cookie,
    }.freeze
  end

  test "invalid-address registration is refused before creating a candidate" do
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "invalid-address" } }, headers: @headers

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end

  test "verification update is refused before consuming an OTP" do
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    patch(
      base_app_identity_emails_registration_path(ri: "jp"),
      params: { user_email: { pass_code: "123456" } },
      headers: @headers,
    )

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end

  test "verification remains refused even when Turnstile would reject the request" do
    TurnstileVerifierStub.challenge_response = { "success" => false }
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    patch(
      base_app_identity_emails_registration_path(ri: "jp"),
      params: { user_email: { pass_code: "123456" } }, headers: @headers,
    )

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  ensure
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  test "redelivery without a pending browser registration is refused" do
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end

  test "redelivery during cooldown is refused before changing the candidate" do
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end

  test "redelivery after cooldown is refused before issuing another code" do
    before = [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]

    post base_app_identity_emails_registration_redelivery_path(ri: "jp"), headers: @headers

    assert_response :service_unavailable
    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end
end
