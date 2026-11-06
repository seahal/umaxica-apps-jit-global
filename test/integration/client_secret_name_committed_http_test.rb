# frozen_string_literal: true

require "test_helper"

class ClientSecretNameCommittedHttpTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  fixtures :clients, :client_secret_credentials

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @base_host
    @actor = clients(:one)
    @credential = client_secret_credentials(:one)
    @original_name = @credential.name
    @audit_ids = ClientSecretAuditOutbox.where(credential_ref: @credential.public_id).pluck(:id)
    @token = ClientToken.create!(
      authentication_epoch: 0, user: @actor, user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB, public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    @token.update!(created_at: 1.hour.ago)
  end

  teardown do
    @grant&.delete
    device = @token&.device_session
    device&.update!(current_refresh_token_id: nil)
    @token&.delete
    device&.delete
    ClientSecretAuditOutbox.where(credential_ref: @credential.public_id).where.not(id: @audit_ids).delete_all
    ClientSecretCredential.where(id: @credential.id).update_all(name: @original_name)
  end

  test "current Step-Up renames the Secret and commits one source event over HTTP" do
    now = ClientToken.database_now
    @token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @token.rotate_refresh_token!(now: now)
    @token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = Time.at(now.to_i).utc
    @grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access = AuthenticationTokenService.encode(
      @actor,
      host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
      session_public_id: @token.public_id, base_session_public_id: @token.public_id,
      oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti, expires_at: 10.minutes.from_now,
      acr: @grant.oidc_acr, amr: ["passkey"], auth_time: auth_time,
      scopes: %w(openid profile), issuer: OidcIssuer.for_client(client), audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@actor, resource_type: "client"), client_id: client.client_id,
    )
    cookie = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{access}"
    @headers = { "Host" => @base_host, "Cookie" => cookie, "HTTP_COOKIE" => cookie }

    patch base_app_secret_url(@credential.public_id, ri: "jp", host: @base_host),
          params: { name: "Renamed over HTTP" }, headers: @headers

    assert_response :see_other
    assert_equal "Renamed over HTTP", @credential.reload.name
    assert_equal StepUpEvidenceResolver::STEP_UP_ACR, @grant.reload.oidc_acr
    event = ClientSecretAuditOutbox.find_by!(
      credential_ref: @credential.public_id, event_name: "secret.renamed",
    )

    assert_equal @actor.public_id, event.client_ref
  end
end
