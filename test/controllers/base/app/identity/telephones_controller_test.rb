# typed: false
# frozen_string_literal: true

require "test_helper"

# Telephone list, form, and removal pages on the app identity surface,
# including the contactability guard that refuses to remove the last way of
# reaching the client.
class Base::App::Identity::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_telephone_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @passkey = @user.client_passkeys.create!(
      webauthn_id: "app-telephone-controller-#{SecureRandom.hex(8)}",
      public_key: "public-key-#{SecureRandom.hex(8)}",
      description: "Telephone controller test passkey",
      uv_verified_at: Time.current,
    )
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_credential_ref: @passkey.public_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @user, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(@user, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    @headers = begin
      rp_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
      rp_host = rp_headers["Host"]
      rp_route =
        begin
          Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
        rescue ActionController::RoutingError
          nil
        end
      rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
      if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
        rp_client_id =
          case rp_family
          when "base" then "base-#{rp_surface}-ww"
          when "edit" then "edit-org-ww"
          when "tech" then "tech-org-ww"
          else "#{rp_family}-#{rp_surface}-jp"
          end
        rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        rp_client = OidcClientRegistry.find!(rp_client_id)
        rp_key = [rp_client.client_id, rp_token.public_id]
        @base_browser_rp_credentials ||= {}
        if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
            !(rp_token.device_session_id && OpAppGrant.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            ))
          rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
          rp_now = Time.current
          rp_session = OpAppGrant.create!(
            client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            rp_token.actor_record, host: rp_host, resource_type: "client",
                                   session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                   oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                   expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                   issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                   jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                   subject: OidcSubject.for(
                                     rp_token.actor_record,
                                     resource_type: "client",
                                   ), client_id: rp_client.client_id,
          )
          @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
        end
        if @base_browser_rp_credentials[rp_key]
          rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
          rp_cookie = [
            rp_headers.fetch("Cookie"),
            "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
            "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
          ].join("; ")
          rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
        end
      end
      rp_headers
    end
      .except("Cookie", "HTTP_COOKIE")
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "index lists the telephones owned by the signed-in client" do
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675401", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    listed = inertia_props.fetch("telephones").pluck("public_id")

    assert_includes listed, telephone.public_id
    assert_equal new_base_app_identity_telephone_path(ri: "jp"), inertia_props.dig("new_link", "href")
    assert_equal new_base_app_identity_telephones_registration_path(ri: "jp"),
                 inertia_props.dig("registration_link", "href")
  end

  test "index does not list another client's telephones" do
    other = clients(:two)
    other_telephone = other.client_telephones.create!(
      raw_number: "+15558675402", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    listed = inertia_props.fetch("telephones").pluck("public_id")

    assert_not_includes listed, other_telephone.public_id
  end

  test "new renders the telephone form" do
    get new_base_app_identity_telephone_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal I18n.t("sign.app.settings.telephone.new.title"), inertia_props.fetch("title")
  end

  test "edit renders the removal page for a telephone the client owns" do
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675403", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal telephone.number.to_s, inertia_props.fetch("number")
  end

  test "edit answers not found for a telephone owned by another client" do
    other_telephone = clients(:two).client_telephones.create!(
      raw_number: "+15558675404", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_base_app_identity_telephone_url(other_telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :not_found
  end

  test "create starts telephone verification and moves on to the registration step" do
    clear_enqueued_jobs
    number = "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"

    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: number } },
         headers: @headers

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host)
    telephone = ClientTelephone.find(session[:settings_telephone_registration_id])
    transaction = ClientTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal telephone.public_id, transaction.telephone_candidate_ref
    assert_equal ["app", "credential_registration", transaction.transaction_id, telephone.public_id,
                  transaction.otp_generation,], payload.fetch(:otp_binding)
    assert_not_includes JSON.generate(job.fetch(:args)), payload.fetch(:otp_code)

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

    assert_redirected_to base_app_identity_telephones_url(ri: "jp", host: @host)
    assert_predicate telephone.reload, :binding_effective?
    assert_predicate transaction.reload, :consumed?
    assert_nil session[:settings_telephone_registration_id]
    assert_nil session[:settings_telephone_registration_transaction_ref]
  end

  test "create re-renders the form when the number cannot be verified" do
    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "not-a-telephone-number" } },
         headers: @headers

    assert_response :unprocessable_content
  end

  test "destroy removes the telephone while another verified contact remains" do
    @user.client_emails.create!(
      raw_address: "telephone_removal_contact@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675405", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    telephone.finalize_binding!
    delete base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
    assert_equal ClientTelephoneStatus::DELETED, telephone.reload.user_identity_telephone_status_id
    assert_predicate telephone, :binding_released?
    audit = ClientContactAuditOutbox.find_by!(contact_ref: telephone.public_id, event_name: "released")

    assert_equal @user.public_id, audit.owner_ref
    assert_equal @user.public_id, audit.actor_ref
    assert_nil audit.acknowledged_at
  end

  test "destroy may remove the last contact method when a passkey remains" do
    @user.client_emails.destroy_all
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675406", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    telephone.finalize_binding!
    delete base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
    assert_equal ClientTelephoneStatus::DELETED, telephone.reload.user_identity_telephone_status_id
    assert_predicate telephone, :binding_released?
  end
end
