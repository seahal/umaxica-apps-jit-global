# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching a telephone number to an existing app
# client: the two-step OTP flow (new -> create -> edit -> update) together with
# the Turnstile, registration-session, and OTP-failure branches guarding it.
class Base::App::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :clients, :client_statuses, :client_telephone_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
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
                authentication_epoch: 0,
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
    passkey = @user.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "telephone-test-key")
    passkey.update!(uv_verified_at: Time.current)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      last_step_up_credential_ref: passkey.public_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
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
                authentication_epoch: 0,
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
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "create queues a random Telephone ceremony code and update finalizes that exact encrypted proof" do
    clear_enqueued_jobs
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+12025550171" } }, headers: @headers

    assert_redirected_to edit_base_app_identity_telephones_registration_path(ri: "jp")
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    job = enqueued_jobs.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal 4, payload.fetch(:version)
    assert_not pending.attributes.key?("credential_registration_otp_context")
    transaction = ClientTelephoneCeremonyTransaction.find_by!(transaction_id: payload.fetch(:otp_binding).fetch(2))

    assert_equal pending.public_id, transaction.telephone_candidate_ref
    assert_equal "credential_registration", transaction.purpose
    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
    assert_predicate pending.reload, :binding_effective?
    assert_predicate transaction.reload, :consumed?
    assert ClientContactAuditOutbox.exists?(
      operation_ref: transaction.transaction_id, contact_ref: pending.public_id, event_name: "finalized",
    )
  end

  %w(current cancelled expired reissued).each do |state|
    test "HTTP created Telephone registration SMS checks #{state} proof before transport" do
      clear_enqueued_jobs
      post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+12025550173" } }, headers: @headers

      assert_redirected_to edit_base_app_identity_telephones_registration_path(ri: "jp")
      transaction = ClientTelephoneCeremonyTransaction.find_by!(
        transaction_id: session[:settings_telephone_registration_transaction_ref],
      )
      job = enqueued_jobs.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
      envelope = job.fetch(:args).fetch(0).fetch("encrypted_payload")
      payload = OutboundSensitivePayload.decrypt_sms_delivery(envelope)

      assert_equal 4, payload.fetch(:version)
      assert_not JSON.generate(job.fetch(:args)).include?(payload.fetch(:otp_code))
      transaction.cancel_telephone_otp! if state == "cancelled"
      transaction.issue_telephone_otp!(purpose: "credential_registration") if state == "reissued"
      now = (state == "expired") ? transaction.otp_expires_at : transaction.class.database_now
      transported = []
      transaction.class.stub(:database_now, now) do
        OutboundSms.stub(:deliver_now, ->(**message) { transported << message }) do
          perform_enqueued_jobs(only: Outbound::SmsDeliveryJob)
        end
      end

      assert_equal (state == "current") ? 1 : 0, transported.length
      if state == "current"
        assert_includes transported.fetch(0).fetch(:body), payload.fetch(:otp_code)
      end
    end
  end

  test "new renders the registration form and leaves no pending registration in the session" do
    get new_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:settings_telephone_registration_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("ClientTelephone.count") do
      post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675311" } },
           headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("ClientTelephone.count", 1) do
      post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675312" } },
           headers: @headers
    end

    assert_redirected_to edit_base_app_identity_telephones_registration_path(ri: "jp")
    registered = ClientTelephone.find(session[:settings_telephone_registration_id])

    assert_equal @user.id, registered.user_id
    assert_equal ClientTelephoneStatus::UNVERIFIED, registered.user_telephone_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675313" } }, headers: @headers

    get edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675314" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientTelephoneStatus::UNVERIFIED, pending.reload.user_telephone_status_id
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675315" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    wrong_code = (payload.fetch(:otp_code) == "000000") ? "000001" : "000000"

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientTelephoneStatus::UNVERIFIED, pending.reload.user_telephone_status_id
  end

  test "separate settings starts for the same telephone retain independent candidates and ceremony generations" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675365" } }, headers: @headers
    first = ClientTelephone.find(session[:settings_telephone_registration_id])
    first_transaction = ClientTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    generation = first_transaction.otp_generation
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675365" } }, headers: @headers
    second = ClientTelephone.find(session[:settings_telephone_registration_id])

    assert_response :found
    assert_not_equal first.id, second.id
    assert_equal first.number_digest, second.number_digest
    assert_equal generation, first_transaction.reload.otp_generation
    assert_not_equal first_transaction.transaction_id, session[:settings_telephone_registration_transaction_ref]
    assert_not first.binding_effective?
    assert_not second.binding_effective?
  end

  test "telephone replacement preserves the old binding on wrong OTP and atomically audits the successful swap" do
    previous = @user.client_telephones.create!(
      number: "+15558675361", user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED, confirm_policy: "1",
    )
    previous.finalize_binding!
    previous.update!(otp_attempts_count: 2)
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675362" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    operation_ref = session[:settings_telephone_registration_transaction_ref]
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)
    wrong = (code == "000000") ? "000001" : "000000"
    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: wrong } }, headers: @headers

    assert_response :unprocessable_content
    assert_predicate previous.reload, :binding_effective?
    assert_equal 2, previous.otp_attempts_count
    assert_not ClientContactAuditOutbox.exists?(operation_ref: operation_ref)
    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: code } }, headers: @headers

    assert_response :see_other
    assert_predicate previous.reload, :binding_released?
    assert_equal 2, previous.otp_attempts_count
    assert_predicate pending.reload, :binding_effective?
    assert_equal [pending.id], @user.client_telephones.effective_binding.pluck(:id)
    assert_equal [[previous.public_id, "released"], [pending.public_id, "finalized"]],
                 ClientContactAuditOutbox.where(operation_ref: operation_ref).order(:id)
                   .pluck(:contact_ref, :event_name)
  end

  test "update verifies the telephone number and returns to the identity page on the correct code" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675316" } }, headers: @headers
    pending = ClientTelephone.find(session[:settings_telephone_registration_id])
    operation_ref = session[:settings_telephone_registration_transaction_ref]
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: code } }, headers: @headers

    assert_response :see_other
    assert_equal ClientTelephoneStatus::VERIFIED, pending.reload.user_telephone_status_id
    intent = ClientContactAuditOutbox.find_by!(contact_ref: pending.public_id, event_name: "finalized")

    assert_equal @user.public_id, intent.owner_ref
    assert_equal @user.public_id, intent.actor_ref
    assert_equal operation_ref, intent.operation_ref
    assert_nil intent.acknowledged_at
    assert_nil session[:settings_telephone_registration_id]
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_app_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+15558675317" } }, headers: @headers
    transaction = ClientTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    transaction.update!(otp_expires_at: transaction.class.database_now - 1.minute)

    patch base_app_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end
end
