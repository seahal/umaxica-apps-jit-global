# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class StepUpAuthenticationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(clients client_secret_credentials)
  fixtures :clients, :client_secret_credentials

  setup do
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host

    @user = clients(:one)
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    @token.rotate_refresh_token!(now: ClientToken.database_now)
    @token.update!(created_at: 1.hour.ago)

    # Base authenticates only the Browser RP access cookie and follows its sid to the RP Session
    # and that session's root token, so each request presents a real self-RP chain for @token.
    @headers = begin
      fv5010 = @token
      fv5008 = OidcClientRegistry.find!("base-app-ww")
      @grant = OpAppGrant.create!(
        authentication_epoch: 0,
        client_token: fv5010,
        oidc_client_id: fv5008.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_auth_time: 1.minute.ago,
        oidc_acr: nil,
        oidc_amr: JSON.generate([]),
        refresh_token_expires_at: 10.minutes.from_now,
      )
      @grant.issue_refresh_token!(now: OpBaseAppRecord.database_now)
      enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(fv5008),
        subject: OidcSubject.for(@user, resource_type: "client"), sid: @grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )
      raise ArgumentError, "RP enrollment failed" unless enrollment.success?

      @rp_session_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
      fv5007 = AuthenticationTokenService.encode(
        @user,
        host: OidcIssuer.host_for_resource_type("client"),
        resource_type: "client",
        session_public_id: fv5010.public_id,
        base_session_public_id: fv5010.public_id,
        oidc_sid: @grant.public_id,
        oidc_jti: @grant.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(fv5008),
        audiences: [fv5008.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5008),
        subject: OidcSubject.for(@user, resource_type: "client"),
        client_id: fv5008.client_id,
      )
      fv5006 = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{fv5007}; #{@rp_session_cookie}"
      host_headers(@base_host).merge(
        "Cookie" => fv5006,
        "HTTP_COOKIE" => fv5006,
      )
    end.freeze

    @setup_email = ClientEmail.create!(
      user: @user,
      address: "stepup-auth-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  test "RP Secret routes refuse with a localized message without changing credentials" do
    credential = client_secret_credentials(:one)
    before = credential.attributes

    get edit_base_app_secret_url(credential.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body

    patch base_app_secret_url(credential.public_id, ri: "jp", host: @base_host),
          params: { client_secret_credential: { name: "changed" } }, headers: @headers

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    assert_equal before, credential.reload.attributes

    issuance = ClientSecretIssuance.create!(
      client: @user, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      planned_count: 1, browser_session_ref: @token.public_id, expires_at: Client.database_now + 1.minute,
    )
    issuance_before = issuance.attributes
    get base_app_secret_issuance_url(issuance.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body

    post base_app_secret_issuance_presentation_url(issuance.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    assert_equal issuance_before, issuance.reload.attributes
  end

  test "a TOTP page challenges before accepting an event" do
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    get base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :unauthorized
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    assert_includes response.body, credential.public_id
  end

  test "a refused TOTP removal is not reported as successful" do
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    IdentityCredentialRemovalCommitter.stub(:call!, false) do
      delete base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: proof_headers

      assert_response :unprocessable_content
      assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    end
  end

  test "a Step-Up event can open another owned TOTP credential" do
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    first = @user.client_totp_credentials.find_by(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    first ||= ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    second = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    get base_app_identity_totp_url(first.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    get base_app_identity_totp_url(second.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    assert_equal proof_time.to_i, @grant.reload.oidc_auth_time.to_i
  end

  test "another actor's TOTP credential cannot start a verification" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: other, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: @headers
    end

    # The existing Step-Up callback runs before the owner-scoped record lookup.
    assert_response :unauthorized
    assert_nil @token.reload.last_step_up_at
  end

  test "a signed return path cannot bypass ownership at another actor's TOTP" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: other, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    path = base_app_identity_totp_path(credential.public_id, ri: "jp")
    target = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap", "surface" => "app", "session_nonce" => @token.public_id, "pt" => path },
      purpose: :path_target, expires_in: 15.minutes,
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(ri: "jp", host: @base_host, scope: "settings_totp", pt: target), headers: @headers
    end

    assert_response :success
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get "https://#{@base_host}#{path}", headers: proof_headers

    assert_response :not_found
    assert_equal proof_time.to_i, @grant.reload.oidc_auth_time.to_i
  end

  test "a signed return path cannot bypass ownership at another actor's Telephone" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    telephone = ClientTelephone.create!(user: other, number: "+819012345686", confirm_policy: "1")
    path = edit_base_app_identity_telephone_path(telephone.public_id, ri: "jp")
    target = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap", "surface" => "app", "session_nonce" => @token.public_id, "pt" => path },
      purpose: :path_target, expires_in: 15.minutes,
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(ri: "jp", host: @base_host, scope: "settings_telephone", pt: target),
          headers: @headers
    end

    assert_response :success
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get "https://#{@base_host}#{path}", headers: proof_headers

    assert_response :not_found
    assert_equal proof_time.to_i, @grant.reload.oidc_auth_time.to_i
  end

  test "a Telephone page challenges before accepting an event" do
    telephone = ClientTelephone.create!(
      user: @user, number: "+819012345685", confirm_policy: "1",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    telephone.finalize_binding!
    ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :redirect
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    assert_includes response.body, telephone.public_id
  end

  test "an Email preference challenges before accepting an event" do
    email = ClientEmail.find_by!(user_id: @user.id, user_email_status_id: ClientEmailStatus::VERIFIED)
    ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    get edit_base_app_identity_email_url(email.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :unauthorized
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get edit_base_app_identity_email_url(email.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    assert_includes response.body, email.public_id
  end

  test "a Step-Up event can open another owned Email credential" do
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    first = ClientEmail.find_by!(user_id: @user.id, user_email_status_id: ClientEmailStatus::VERIFIED)
    second = ClientEmail.create!(
      user: @user, address: "stepup-other-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    get edit_base_app_identity_email_url(first.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    get edit_base_app_identity_email_url(second.public_id, ri: "jp", host: @base_host), headers: proof_headers

    assert_response :success
    assert_equal proof_time.to_i, @grant.reload.oidc_auth_time.to_i
  end

  test "another actor's Email cannot start a preference verification" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(
      user: other, address: "stepup-foreign-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get edit_base_app_identity_email_url(email.public_id, ri: "jp", host: @base_host), headers: @headers
    end

    # The existing Step-Up callback runs before the owner-scoped record lookup.
    assert_response :unauthorized
    assert_nil @token.reload.last_step_up_at
  end

  test "a signed return path cannot bypass ownership at another actor's Email" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(
      user: other, address: "stepup-foreign-target-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    path = edit_base_app_identity_email_path(email.public_id, ri: "jp")
    target = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap", "surface" => "app", "session_nonce" => @token.public_id, "pt" => path },
      purpose: :path_target, expires_in: 15.minutes,
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(ri: "jp", host: @base_host, scope: "settings_email", pt: target), headers: @headers
    end

    assert_response :success
    proof_client = OidcClientRegistry.find!("base-app-ww")
    proof_now = OpBaseAppRecord.database_now
    proof_time = Time.at(proof_now.to_i).utc
    @grant.update!(
      oidc_auth_time: proof_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    proof_access = AuthenticationTokenService.encode(
      @user, host: @base_host, resource_type: "client", session_public_id: @token.public_id,
             base_session_public_id: @token.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
             expires_at: proof_now + 10.minutes, scopes: %w(openid profile), acr: @grant.oidc_acr,
             amr: ["passkey"], auth_time: proof_time, issuer: OidcIssuer.for_client(proof_client),
             audiences: [proof_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(proof_client),
             subject: OidcSubject.for(@user, resource_type: "client"), client_id: proof_client.client_id,
             authentication_context: @token.strict_authentication_context_value.to_s,
    )
    proof_cookie = [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(proof_access)}", @rp_session_cookie,
    ].join("; ")
    proof_headers = { "Host" => @base_host, "Cookie" => proof_cookie, "HTTP_COOKIE" => proof_cookie }
    get "https://#{@base_host}#{path}", headers: proof_headers

    assert_response :not_found
    assert_equal proof_time.to_i, @grant.reload.oidc_auth_time.to_i
  end

  test "GET sensitive TOTP page returns a Step-Up challenge" do
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    get base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
  end

  test "fresh sign-in token does not satisfy step-up without recorded step-up" do
    @token.update!(created_at: 1.minute.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "RP email registration refuses before writing while its Base writer is out of scope" do
    email_count = @user.client_emails.count

    assert_no_enqueued_jobs(only: OtpNotifierEmailDeliveryJob) do
      post base_app_identity_emails_registration_url(ri: "jp", host: @base_host),
           params: { user_email: { address: "new@example.com" } },
           headers: @headers
    end

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    assert_equal email_count, @user.client_emails.count
  end

  # The bearer header only skips the browser-request check; no Browser RP credential is presented.
  test "PATCH withdrawal without a session is refused by authentication instead of raising" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @base_host),
          params: { ack_schedule_purge: "1" },
          headers: host_headers(@base_host).merge("Authorization" => "Bearer x.y.z")

    assert_response :redirect
    assert_not ClientWithdrawalFlow.exists?(client_id: @user.id)
  end

  test "scope mismatch redirects to verification" do
    mark_step_up_satisfied!(@token, at: 3.minutes.ago, scope: "withdrawal")

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "step-up older than 15 minutes redirects to verification" do
    mark_step_up_satisfied!(@token, at: 15.minutes.ago, scope: "settings_email")

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "step-up within TTL and matching scope passes through" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "step-up satisfied on one session does not satisfy another" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")

    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    other_token.update!(created_at: 1.hour.ago)
    other_headers = other_session_headers(other_token)
    other_grant = OpAppGrant.find_by!(client_token: other_token, oidc_client_id: "base-app-ww")
    other_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_resource_type("client"),
      subject: OidcSubject.for(@user, resource_type: "client"), sid: other_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate other_enrollment, :success?
    other_cookie = [
      other_headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{other_enrollment.session.public_id}",
    ].join("; ")
    other_headers = other_headers.merge("Cookie" => other_cookie, "HTTP_COOKIE" => other_cookie)

    assert_not_equal @rp_session_cookie,
                     "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{other_enrollment.session.public_id}"

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: other_headers

    assert_response :success
  end

  test "mismatched session binding does not satisfy browser step-up" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(last_step_up_session_public_id: "other-session")

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "revoked session is bounced out before any step-up gate" do
    # OP root revocation reaches the RP asynchronously; assert refusal after the local logout commit.
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(discard_at: 1.second.ago)
    result = RpCellSessionRevoker.call(
      cell: RpCellBinding.for_client("base-app-ww"),
      payload: {
        "iss" => OidcIssuer.for_resource_type("client"),
        "sid" => @grant.public_id,
        "jti" => SecureRandom.uuid,
        "exp" => 10.minutes.from_now.to_i,
      },
    )

    assert_equal :revoked, result

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :redirect
  end

  test "session reset clears step-up freshness" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil, last_step_up_session_public_id: nil)

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "missing session binding does not satisfy browser step-up" do
    @token.update!(last_step_up_at: 10.minutes.ago, last_step_up_scope: "settings_email")

    get base_app_identity_emails_url(ri: "jp", host: @base_host), headers: @headers

    assert_response :success
  end

  test "HEAD sensitive TOTP page returns a Step-Up challenge" do
    credential = ClientTotpCredential.create_for_user!(
      user: @user, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    head base_app_identity_totp_url(credential.public_id, ri: "jp", host: @base_host), headers: @headers

    assert_response :unauthorized
    assert_includes response.headers.fetch("WWW-Authenticate"), "insufficient_user_authentication"
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
  end

  test "a Security Mode downgrade through the controller revokes every session including the current one" do
    @user.reload.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    now = OpBaseAppRecord.database_now
    auth_time = now.to_i - 1
    @grant.update!(
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
    )
    ClientStepUpCommit.create!(
      grant: @grant,
      root_token: @token,
      context_ref: PublicId.generate,
      verified_method: "passkey",
      committed_at: Time.at(auth_time).utc,
    )
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    access_token = AuthenticationTokenService.encode(
      @user,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: @token.public_id,
      base_session_public_id: @token.public_id,
      oidc_sid: @grant.public_id,
      oidc_jti: @grant.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      acr: StepUpEvidenceResolver::STEP_UP_ACR,
      amr: ["passkey"],
      auth_time: auth_time,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    access_cookie = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{access_token}; #{@rp_session_cookie}"
    @headers = @headers.merge("Cookie" => access_cookie, "HTTP_COOKIE" => access_cookie)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: 1.day.from_now,
    )
    ClientStepUpSession.create!(
      user_token: other_token,
      scope: "settings_email",
      return_to: base_app_identity_emails_path(ri: "jp"),
      status: "VERIFIED",
      method: "passkey",
      verified_at: 1.minute.ago,
      discard_at: 1.day.from_now,
    )

    before_audit_count = ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count
    selection_client = Object.new
    selection_client.define_singleton_method(:get) do |path|
      raise ArgumentError, "unexpected selection endpoint" unless path == "/identity/selection"

      OrgAdminAuthorityClient::Result.new(status: :ok, data: {}, errors: {}, http_status: 200)
    end
    expected_access_token = access_token
    selection_boundary =
      lambda do |surface:, **arguments|
        raise ArgumentError, "selection actor mismatch" unless
          arguments.fetch(:access_token) == expected_access_token && surface == "app"

        selection_client
      end
    OrgAdminAuthorityClient.stub(:new, selection_boundary) do
      patch base_app_identity_mfa_challenge_url(ri: "jp", host: @base_host),
            params: { user: { security_mode_id: SecurityModeConfigurable::NORMAL } },
            headers: @headers
    end

    assert_response :redirect
    assert_equal before_audit_count + 1,
                 ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count
    # Consolidation ADR 2.5: after ADVANCED -> NORMAL every session is revoked; a new sign-in is required.
    assert_not_predicate @token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
    assert_nil @token.last_step_up_at
    assert_nil other_token.last_step_up_at
    assert_operator other_token.step_up_session.reload.discard_at, :<=, Time.current

    post base_app_identity_emails_registration_url(ri: "jp", host: @base_host),
         params: { user_email: { address: "after-disable@example.com" } },
         headers: other_session_headers(other_token)

    assert_includes [302, 303, 401, 403, 422], response.status
  end

  test "ADVANCED to NORMAL refuses a five-minute-expired OP step-up event" do
    @user.reload.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    now = OpBaseAppRecord.database_now
    auth_time = now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS - 1
    @grant.update!(
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
    )
    ClientStepUpCommit.create!(
      grant: @grant,
      root_token: @token,
      context_ref: PublicId.generate,
      verified_method: "passkey",
      committed_at: Time.at(auth_time).utc,
    )
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    access_token = AuthenticationTokenService.encode(
      @user,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: @token.public_id,
      base_session_public_id: @token.public_id,
      oidc_sid: @grant.public_id,
      oidc_jti: @grant.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      acr: StepUpEvidenceResolver::STEP_UP_ACR,
      amr: ["passkey"],
      auth_time: auth_time,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookie = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{access_token}; #{@rp_session_cookie}"
    headers = @headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

    selection_client = Object.new
    selection_client.define_singleton_method(:get) do |path|
      raise ArgumentError, "unexpected selection endpoint" unless path == "/identity/selection"

      OrgAdminAuthorityClient::Result.new(status: :ok, data: {}, errors: {}, http_status: 200)
    end
    expected_access_token = access_token
    selection_boundary =
      lambda do |surface:, **arguments|
        raise ArgumentError, "selection actor mismatch" unless
          arguments.fetch(:access_token) == expected_access_token && surface == "app"

        selection_client
      end
    OrgAdminAuthorityClient.stub(:new, selection_boundary) do
      patch base_app_identity_mfa_challenge_url(ri: "jp", host: @base_host),
            params: { user: { security_mode_id: SecurityModeConfigurable::NORMAL } }, headers: headers
    end

    assert_response :see_other
    verification_uri = URI.parse(response.location)

    assert_equal "/verification", verification_uri.path
    assert_equal "settings_mfa", Rack::Utils.parse_query(verification_uri.query).fetch("scope")
    assert_equal SecurityModeConfigurable::ADVANCED, @user.reload.security_mode_id
    assert_predicate @token.reload, :currently_usable?
  end

  test "ADVANCED to NORMAL refuses an OP event after its root session is revoked" do
    @user.reload.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    now = OpBaseAppRecord.database_now
    auth_time = now.to_i - 1
    @grant.update!(
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
    )
    ClientStepUpCommit.create!(
      grant: @grant,
      root_token: @token,
      context_ref: PublicId.generate,
      verified_method: "passkey",
      committed_at: Time.at(auth_time).utc,
    )
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    access_token = AuthenticationTokenService.encode(
      @user,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: @token.public_id,
      base_session_public_id: @token.public_id,
      oidc_sid: @grant.public_id,
      oidc_jti: @grant.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      acr: StepUpEvidenceResolver::STEP_UP_ACR,
      amr: ["passkey"],
      auth_time: auth_time,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(@user, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookie = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{access_token}; #{@rp_session_cookie}"
    headers = @headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)
    @token.revoke!

    selection_client = Object.new
    selection_client.define_singleton_method(:get) do |path|
      raise ArgumentError, "unexpected selection endpoint" unless path == "/identity/selection"

      OrgAdminAuthorityClient::Result.new(status: :ok, data: {}, errors: {}, http_status: 200)
    end
    expected_access_token = access_token
    selection_boundary =
      lambda do |surface:, **arguments|
        raise ArgumentError, "selection actor mismatch" unless
          arguments.fetch(:access_token) == expected_access_token && surface == "app"

        selection_client
      end
    OrgAdminAuthorityClient.stub(:new, selection_boundary) do
      patch base_app_identity_mfa_challenge_url(ri: "jp", host: @base_host),
            params: { user: { security_mode_id: SecurityModeConfigurable::NORMAL } }, headers: headers
    end

    assert_response :unprocessable_content
    assert_equal SecurityModeConfigurable::ADVANCED, @user.reload.security_mode_id
    assert_predicate @token.reload, :revoked?
  end

  test "RP email verification refuses before writing while its Base writer is out of scope" do
    emails_before = @user.client_emails.pluck(:id, :address, :user_email_status_id)
    session_ids_before = @user.client_tokens.order(:id).pluck(:id)
    audit_count_before = ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count

    assert_no_enqueued_jobs(only: OtpNotifierEmailDeliveryJob) do
      post base_app_identity_emails_registration_url(ri: "jp", host: @base_host),
           params: { user_email: { address: "out-of-scope-#{SecureRandom.hex(4)}@example.com" } },
           headers: @headers
    end

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    assert_equal emails_before, @user.client_emails.pluck(:id, :address, :user_email_status_id)
    assert_equal session_ids_before, @user.client_tokens.order(:id).pluck(:id)
    assert_equal audit_count_before,
                 ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count
  end

  private

  def other_session_headers(token)
    begin
      fv5005 = token
      fv5003 = OidcClientRegistry.find!("base-app-ww")
      fv5004 = OpAppGrant.create!(
        authentication_epoch: 0,
        client_token: fv5005,
        oidc_client_id: fv5003.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: 10.minutes.from_now,
      )
      fv5002 = AuthenticationTokenService.encode(
        @user,
        host: OidcIssuer.host_for_resource_type("client"),
        resource_type: "client",
        session_public_id: fv5005.public_id,
        base_session_public_id: fv5005.public_id,
        oidc_sid: fv5004.public_id,
        oidc_jti: fv5004.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(fv5003),
        audiences: [fv5003.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5003),
        subject: OidcSubject.for(@user, resource_type: "client"),
        client_id: fv5003.client_id,
      )
      fv5001 = "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{fv5002}"
      host_headers(@base_host).merge(
        "Cookie" => fv5001,
        "HTTP_COOKIE" => fv5001,
      )
    end
  end

  def mark_step_up_satisfied!(token, at:, scope:, method: "passkey", aal: "aal2")
    token.update!(
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: aal,
      last_step_up_method: method,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      last_step_up_credential_ref: "test-step-up",
      last_step_up_phishing_resistant: method == "passkey",
      last_step_up_user_verified: method == "passkey",
      last_step_up_full_reauthentication: false,
    )
  end
end

# DAMP local helper copy for former shared test support.
class StepUpAuthenticationTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("base") || normalized.start_with?("www.umaxica.")
        "BASE"
      else
        "AUTH"
      end
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers =
        as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class StepUpAuthenticationTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
