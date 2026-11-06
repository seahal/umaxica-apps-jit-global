# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class TotpRenameCommittedHttpTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @rp_enrollment = nil
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @base_host
    @user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @email = ClientEmail.create!(
      user: @user, address: "totp-rename-#{SecureRandom.hex(8)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @token = ClientToken.create!(
      authentication_epoch: 0, user: @user, user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB, discard_at: 1.day.from_now,
      root_login_established_at: Time.current, established_authentication_method: "passkey",
    )
    @token.update!(created_at: 1.hour.ago)
    now = OpBaseAppRecord.database_now
    @token.device_session_record!
    @token.rotate_refresh_token!(now:)
    client = OidcClientRegistry.find!("base-app-ww")
    @grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token: @token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: 10.minutes.from_now,
    )
    @grant.issue_refresh_token!(now:)
    @rp_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@user, resource_type: "client"), sid: @grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )
    raise ArgumentError, "RP enrollment failed: #{@rp_enrollment.outcome}" unless @rp_enrollment.success?

    @rp_session_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{@rp_enrollment.session.public_id}"
    access = AuthenticationTokenService.encode(
      @user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
             session_public_id: @token.public_id, base_session_public_id: @token.public_id, oidc_sid: @grant.public_id,
             oidc_jti: @grant.oidc_jti, expires_at: 10.minutes.from_now, scopes: %w(openid profile),
             acr: @grant.oidc_acr, amr: ["passkey"], auth_time: @grant.oidc_auth_time,
             issuer: OidcIssuer.for_client(client), audiences: [client.aud],
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    cookie = ["#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{access}", @rp_session_cookie].join("; ")
    @headers = { "Host" => @base_host, "Cookie" => cookie, "HTTP_COOKIE" => cookie }
  end

  teardown do
    if @rp_enrollment&.success?
      RpBaseAppRecord.connected_to(role: :writing) do
        session = RpBaseAppSession.find(@rp_enrollment.session.id)
        binding = RpBaseAppOpSessionBinding.find(session.op_session_binding_id)
        identity = RpBaseAppIdentityBinding.find(binding.identity_binding_id)
        RpBaseAppSession.where(id: session.id).delete_all
        RpBaseAppOpSessionBinding.where(id: binding.id).delete_all
        RpBaseAppIdentityBinding.where(id: identity.id).delete_all
        RpBaseAppPrincipal.where(id: identity.principal_id).delete_all
      end
    end
    @grant&.delete
    device = @token&.device_session
    device&.update!(current_refresh_token_id: nil)
    @token&.delete
    device&.delete
    Client.connection_class_for_self.connected_to(role: :writing) do
      ClientTotpCredential.where(user_id: @user.id).delete_all if @user
      @email&.delete
      if @user
        client_id = @user.id
        ClientPreference.where(client_id: client_id).destroy_all
        Client.where(id: client_id).delete_all

        assert_not Client.uncached { Client.exists?(id: client_id) }, "the test's Client must be removed"
      end
    end
  end

  %w(joined savepoint).each do |nesting|
    test "an outer OP #{nesting} transaction makes the TOTP rename unavailable without consuming proof" do
      credential = ClientTotpCredential.create_for_user!(
        user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )
      @token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "totp",
        last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
        last_step_up_user_verified: false, last_step_up_credential_ref: credential.public_id,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
      )
      evidence_at = @token.reload.last_step_up_at
      OpBaseAppRecord.transaction do
        OpBaseAppRecord.transaction(requires_new: nesting == "savepoint") do
          patch base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host),
                params: { client_totp_credential: { title: "Renamed" } }, headers: @headers

          assert_response :service_unavailable
          assert_nil credential.reload.title
          assert_equal evidence_at, @token.reload.last_step_up_at
        end
        raise ActiveRecord::Rollback
      end

      assert_nil credential.reload.title
      assert_equal evidence_at, @token.reload.last_step_up_at
    end
  end

  test "a target-bound TOTP rename returns to the list using the current Step-Up event" do
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "totp",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: credential.public_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    step_up_at = @token.reload.last_step_up_at
    failure = ->(**) { raise IdentityTotpNameCommitter::DependencyFailure, "injected storage failure" }
    IdentityTotpNameCommitter.stub(:call!, failure) do
      patch base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host),
            params: { client_totp_credential: { title: "Renamed" } }, headers: @headers

      assert_response :service_unavailable
      assert_nil credential.reload.title
      assert_equal step_up_at, @token.reload.last_step_up_at
    end

    patch base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host),
          params: { client_totp_credential: { title: "Renamed" } }, headers: @headers

    assert_response :see_other
    assert_equal base_app_identity_totps_path, URI.parse(response.location).path
    assert_equal "Renamed", credential.reload.title
    assert_equal step_up_at, @token.reload.last_step_up_at
  end

  test "a TOTP rename storage failure returns 503 without consuming the target-bound Step-Up" do
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "totp",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: credential.public_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    step_up_at = @token.reload.last_step_up_at
    failure_injected = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)

        failure_injected = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      patch base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host),
            params: { client_totp_credential: { title: "Renamed" } }, headers: @headers
    end

    assert failure_injected
    assert_response :service_unavailable
    assert_nil credential.reload.title
    assert_equal step_up_at, @token.reload.last_step_up_at
  end
end
