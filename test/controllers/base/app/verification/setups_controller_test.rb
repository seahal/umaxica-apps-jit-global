# frozen_string_literal: true

require "test_helper"

# Base owns the choice of a first authenticator. Each choice starts its own bootstrap transaction;
# none of them grants Step-Up freshness.
class Base::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :client_statuses, :client_email_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses, :client_chronicle_events,
           :client_chronicle_levels, :client_totp_credential_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    host! @host
    @user = Client.create!(status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, root_login_established_at: 1.minute.ago,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
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
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    @headers = { "Authorization" => "Bearer #{access_token}", "Client-Agent" => "Mozilla/5.0", "Host" => @host }.freeze
    @return_to = "/identity/telephones"
    # The signed target is bound to the current root token public ID used by Base's RP context.
    session_nonce = @token.public_id
    @pt = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap", "surface" => "app", "session_nonce" => session_nonce, "pt" => @return_to },
      purpose: :path_target, expires_in: 15.minutes,
    )
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the protected operation of an actor without an authenticator leads to the Base method choice" do
    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      post base_app_verification_path(ri: "jp"), params: { scope: "settings_telephone", pt: @pt }, headers: @headers
    end

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @host, location.host
    assert_equal base_app_verification_setup_path, location.path
    assert_equal "settings_telephone", Rack::Utils.parse_query(location.query).fetch("scope")
    assert_equal @pt, Rack::Utils.parse_query(location.query).fetch("pt")
  end

  test "the method choice page lists passkey, authenticator app and email and changes nothing" do
    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_setup_path(ri: "jp", scope: "settings_telephone", pt: @pt), headers: @headers
    end

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)

    assert_equal "base/app/verification/setups/show", page.fetch("component")
    props = page.fetch("props")

    assert_equal %w(passkey totp email_otp), props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal base_app_verification_setup_path(ri: "jp"), props.fetch("form").fetch("action")
    assert_equal "settings_telephone", props.fetch("form").fetch("scope")
    assert_equal @pt, props.fetch("form").fetch("pt")
    assert_equal base_app_identity_path(ri: "jp"), props.fetch("cancel").fetch("href")
    assert_nil session[:base_step_up_transaction_ref]
  end

  test "an actor who already holds an authenticator is sent to ordinary verification instead of the choice" do
    @user.client_emails.create!(
      address: "has-method-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    get base_app_verification_setup_path(ri: "jp", scope: "settings_telephone", pt: @pt), headers: @headers

    assert_response :see_other
    assert_equal base_app_verification_path, URI.parse(response.location).path

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      post base_app_verification_setup_path(ri: "jp"),
           params: { scope: "settings_telephone", pt: @pt, registration_method: "email_otp" }, headers: @headers
    end

    assert_response :bad_request
  end

  # Sentinels and partitions of the chosen method: missing, empty, zero, NUL-bearing, an array,
  # a method that exists but is not a registration method, and an unknown word.
  test "the choice refuses a missing or unsupported method without starting a transaction" do
    [
      {}, { registration_method: "" }, { registration_method: "0" }, { registration_method: "totp\u0000" },
      { registration_method: ["totp"] }, { registration_method: "secret_credential" },
      { registration_method: "telephone" },
    ].each do |choice|
      assert_no_difference -> { ClientStepUpCeremonyTransaction.count }, choice.inspect do
        post base_app_verification_setup_path(ri: "jp"),
             params: { scope: "settings_telephone", pt: @pt }.merge(choice), headers: @headers
      end

      assert_response :bad_request, choice.inspect
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
    end
    assert_nil session[:base_step_up_transaction_ref]
  end

  test "choosing the authenticator app starts a TOTP-only bootstrap that Auth admits straight to enrollment" do
    post base_app_verification_setup_path(ri: "jp"),
         params: { scope: "settings_telephone", pt: @pt, registration_method: "totp" }, headers: @headers

    assert_response :see_other
    transaction =
      begin
        ClientStepUpCeremonyTransaction.where(
          actor_ref: @user.public_id, session_ref: @token.public_id, purpose: "bootstrap",
        ).order(id: :desc).first!
      end

    assert_equal "bootstrap", transaction.purpose
    assert_equal ["totp"], transaction.allowed_methods_array
    assert_equal @return_to, transaction.return_to
    location = URI.parse(response.location)
    if location.host == "jump.umaxica.net"
      target, = JWT.decode(Rack::Utils.parse_nested_query(location.query).fetch("rt"), nil, false)
      location = URI.parse(target.fetch("url"))
    end

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), location.host
    entry_ref = Rack::Utils.parse_query(location.query).fetch("entry_ref")

    auth = open_session
    auth.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth.https!
    begin
      fv5001 = auth
      fv5004 = entry_ref
      fv5001.get(
        new_auth_app_verification_setup_path(
          ri: "jp",
          entry_ref: fv5004,
        ),
      )
      fv5001.assert_response :success
      fv5003 = fv5001.response.parsed_body.at_css("form")

      fv5001.post(
        fv5003["action"],
        params: {
          entry_ref: fv5003.at_css('input[name="entry_ref"]')["value"],
          authenticity_token: fv5003.at_css('input[name="authenticity_token"]')["value"],
        },
      )
      fv5001.assert_response :see_other

      get(fv5001.response.location, headers: @headers)

      assert_response :success
      fv5002 = response.parsed_body.at_css("form")
      post(
        fv5002["action"],
        params: {
          authenticity_token: fv5002.at_css('input[name="authenticity_token"]')["value"],
          ri: fv5002.at_css('input[name="ri"]')["value"],
        },
        headers: @headers,
      )

      assert_response :see_other

      fv5001.get(URI.parse(response.location).request_uri)
      fv5001.assert_response :success
      fv5000 = fv5001.response.parsed_body.at_css("form")
      fv5001.post(
        fv5000["action"],
        params: {
          entry_ref: fv5000.at_css('input[name="entry_ref"]')["value"],
          authenticity_token: fv5000.at_css('input[name="authenticity_token"]')["value"],
        },
      )
    end

    auth.assert_response :see_other

    assert_equal new_auth_app_settings_totp_path(ri: "jp"), URI.parse(auth.response.location).request_uri

    auth.get(new_auth_app_settings_totp_path(ri: "jp"))

    auth.assert_response :success

    assert_nil @token.reload.last_step_up_at
  end

  test "a session whose root login is no longer fresh cannot choose a method" do
    @token.update!(root_login_established_at: 11.minutes.ago)

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      post base_app_verification_setup_path(ri: "jp"),
           params: { scope: "settings_telephone", pt: @pt, registration_method: "email_otp" }, headers: @headers
    end

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.fresh_sign_in_required"), response.body
  end

  test "email registration without a chosen email bootstrap returns to the method choice" do
    get new_base_app_identity_emails_registration_path(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_equal base_app_verification_setup_path, URI.parse(response.location).path
    assert_equal "settings_email", Rack::Utils.parse_query(URI.parse(response.location).query).fetch("scope")

    assert_no_difference -> { ClientEmail.count } do
      post base_app_identity_emails_registration_path(ri: "jp"),
           params: { user_email: { raw_address: "no-bootstrap@example.com" } }, headers: @headers
    end

    assert_response :redirect
    assert_equal base_app_verification_setup_path, URI.parse(response.location).path
  end

  test "email bootstrap completes without freshness and the protected operation then needs a new verification" do
    post base_app_verification_setup_path(ri: "jp"),
         params: { scope: "settings_telephone", pt: @pt, registration_method: "email_otp" }, headers: @headers

    assert_response :see_other
    assert_equal new_base_app_identity_emails_registration_path, URI.parse(response.location).path
    bootstrap =
      begin
        ClientStepUpCeremonyTransaction.where(
          actor_ref: @user.public_id, session_ref: @token.public_id, purpose: "bootstrap",
        ).order(id: :desc).first!
      end

    assert_equal "bootstrap", bootstrap.purpose
    assert_equal ["email_otp"], bootstrap.allowed_methods_array

    get new_base_app_identity_emails_registration_path(ri: "jp"), headers: @headers

    assert_response :success
    clear_enqueued_jobs
    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "first-email-#{SecureRandom.hex(4)}@example.com" } }, headers: @headers

    assert_response :redirect
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    delivery = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: session[:email_registration_transaction_ref],
    )
    code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal ceremony.transaction_id, payload.fetch(:contact_ceremony_transaction_ref)
    assert_equal ceremony.otp_generation, payload.fetch(:contact_otp_generation)
    assert_equal pending.public_id, ceremony.email_candidate_ref
    assert_equal @user.public_id, ceremony.actor_ref

    patch base_app_identity_emails_registration_path(ri: "jp"),
          params: { user_email: { pass_code: code } }, headers: @headers

    assert_response :redirect
    assert_equal @return_to, URI.parse(response.location).path
    bootstrap.reload

    assert_equal "consumed", bootstrap.status
    assert_equal "email_otp", bootstrap.method
    assert_equal "none", bootstrap.aal
    assert_equal pending.public_id, bootstrap.verified_credential_ref
    assert_equal ClientEmailStatus::VERIFIED, pending.reload.user_email_status_id
    assert_not_nil ceremony.reload.otp_consumed_at
    assert_nil ceremony.otp_verifier
    assert_nil session[:base_step_up_transaction_ref]
    @token.reload

    assert_nil @token.last_step_up_at
    assert_nil @token.last_step_up_scope
    assert_predicate @token, :currently_usable?

    # The registered address is now a usable method: the protected operation starts a new,
    # ordinary verification transaction instead of being satisfied by the registration.
    post base_app_verification_path(ri: "jp"), params: { scope: "settings_telephone", pt: @pt }, headers: @headers

    assert_response :see_other
    verification =
      begin
        ClientStepUpCeremonyTransaction.where(
          actor_ref: @user.public_id, session_ref: @token.public_id, purpose: "step_up",
        ).order(id: :desc).first!
      end

    assert_not_equal bootstrap.transaction_id, verification.transaction_id
    assert_equal "step_up", verification.purpose
    assert_equal "pending", verification.status
    assert_equal ["email_otp"], verification.allowed_methods_array
    assert_nil @token.reload.last_step_up_at
  end

  test "a wrong email code leaves the bootstrap pending" do
    post base_app_verification_setup_path(ri: "jp"),
         params: { scope: "settings_telephone", pt: @pt, registration_method: "email_otp" }, headers: @headers
    bootstrap =
      begin
        ClientStepUpCeremonyTransaction.where(
          actor_ref: @user.public_id, session_ref: @token.public_id, purpose: "bootstrap",
        ).order(id: :desc).first!
      end
    clear_enqueued_jobs
    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "wrong-code-#{SecureRandom.hex(4)}@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    delivery = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: session[:email_registration_transaction_ref],
    )
    code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    wrong = format("%06d", (Integer(code, 10) + 1) % 1_000_000)

    assert_equal ceremony.transaction_id, payload.fetch(:contact_ceremony_transaction_ref)
    assert_equal ceremony.otp_generation, payload.fetch(:contact_otp_generation)

    patch base_app_identity_emails_registration_path(ri: "jp"),
          params: { user_email: { pass_code: wrong } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal "pending", bootstrap.reload.status
    assert_equal ClientEmailStatus::UNVERIFIED, pending.reload.user_email_status_id
    assert_nil ceremony.reload.otp_consumed_at
    assert_not_nil ceremony.otp_verifier
    assert_nil @token.reload.last_step_up_at
  end

  private
end
