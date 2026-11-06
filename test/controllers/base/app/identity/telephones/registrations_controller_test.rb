# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  include ActiveJob::TestHelper

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    @token.rotate_refresh_token!

    client = OidcClientRegistry.find!("base-app-ww")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: @token.authentication_epoch,
      client_token: @token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now,
      refresh_token_expires_at: now + 10.minutes,
    )
    refresh_token = grant.issue_refresh_token!(expires_at: now + 10.minutes, now:)
    access_token = AuthenticationTokenService.encode(
      @actor, host: @host, resource_type: "client",
              session_public_id: @token.public_id, base_session_public_id: @token.public_id,
              oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
              expires_at: now + 10.minutes, scopes: %w(openid profile),
              issuer: OidcIssuer.for_client(client), audiences: [client.aud],
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
              subject: OidcSubject.for(@actor, resource_type: "client"), client_id: client.client_id,
    )
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id),
      issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@actor, resource_type: "client"),
      sid: grant.public_id,
      absolute_expires_at: now + 10.minutes,
    )
    raise ArgumentError, "RP session enrollment failed: #{enrollment.outcome}" unless enrollment.success?

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
  end

  test "APP telephone registration stays unavailable until its RP source receipt boundary is enabled" do
    before = [ClientTelephone.count, ClientTelephoneCeremonyTransaction.count, enqueued_jobs.size]

    get new_base_app_identity_telephones_registration_path(ri: "jp")

    assert_response :service_unavailable

    get edit_base_app_identity_telephones_registration_path(ri: "jp")

    assert_response :service_unavailable

    post base_app_identity_telephones_registration_path(ri: "jp"),
         params: { user_telephone: { raw_number: "+12025550171" } }

    assert_response :service_unavailable

    patch base_app_identity_telephones_registration_path(ri: "jp"),
          params: { user_telephone: { pass_code: "123456" } }

    assert_response :service_unavailable

    assert_equal before, [ClientTelephone.count, ClientTelephoneCeremonyTransaction.count, enqueued_jobs.size]
  end
end
