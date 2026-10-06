# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching an email address to an existing app
# client: the two-step OTP flow, the redelivery endpoint, and the Turnstile,
# missing-code, wrong-code and lock-out branches that guard them.
class Base::App::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    install_base_browser_rp_credentials!(surface: "app", host: @host, actor: @user, token: @token)
    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = @user.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @user.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
    )
    transaction = issue_base_step_up_admission!(
      actor: @user, token: @token, requirement: requirement, return_to: "/identity/emails/registration/new",
    ).transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.public_id,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @user, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
    }.freeze

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "unavailable credential history cannot authorize initial-contact registration" do
    %i(revoked_passkey inactive_totp revoked_totp).each do |state|
      actor = Client.create!
      case state
      when :revoked_passkey
        actor.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "revoked-contact-public-key", sign_count: 0,
          status_id: ClientPasskeyStatus::REVOKED,
        )
      when :inactive_totp, :revoked_totp
        actor.client_totp_credentials.create!(
          private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: (state == :inactive_totp) ?
            ClientTotpCredentialStatus::INACTIVE : ClientTotpCredentialStatus::REVOKED,
        )
      end
      token = ClientToken.create!(user: actor)
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      browser = open_session
      browser.https!
      browser.host!(@host)
      install_base_browser_rp_credentials!(
        surface: "app", host: @host, actor: actor, token: token, cookie_jar: browser.cookies,
      )
      browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
        actor, host: @host, session_public_id: token.public_id,
               resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
      )

      assert_empty StepUpConfiguredMethodsQuery.call(actor), state.to_s
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor), state.to_s
      assert_no_difference ["ClientEmail.count", "ClientStepUpCeremonyTransaction.count"] do
        browser.post(
          base_app_identity_emails_registration_path(ri: "jp"),
          params: { user_email: { address: "unavailable-app-contact-#{SecureRandom.hex(4)}@example.com" } },
          headers: { "Client-Agent" => "Mozilla/5.0" }, as: :json,
        )
      end

      assert_equal 422, browser.response.status, state.to_s
      assert_nil token.reload.last_step_up_at
      assert_predicate token, :currently_usable?
    end
  end

  test "new renders the registration form" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:email_registration_public_id]
  end

  test "new links back and cancel to the email index" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    expected = base_app_identity_emails_url(ri: "jp", host: @host, protocol: request.protocol)

    assert_equal expected, inertia_props.dig("back_link", "href")
    assert_equal expected, inertia_props.dig("cancel_link", "href")
  end

  test "new ships the stealth Turnstile configuration that create verifies" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    turnstile = inertia_props.dig("form", "turnstile")

    assert_equal Rails.app.creds.option(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY), turnstile["site_key"]
    assert_equal "execute", turnstile["mode"]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end

  test "create rejects an address that fails model validation" do
    assert_no_difference("ClientEmail.count") do
      post base_app_identity_emails_registration_url(ri: "jp", host: @host),
           params: { user_email: { raw_address: "not-an-email" } }, headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("ClientEmail.count", 1) do
      post base_app_identity_emails_registration_url(ri: "jp", host: @host),
           params: { user_email: { raw_address: "app_email_reg_created@example.com" } }, headers: @headers
    end

    assert_response :redirect
    assert_match %r{/identity/emails/registration/edit}, response.location
    registered = ClientEmail.find_by!(public_id: session[:email_registration_public_id])

    assert_equal @user.id, registered.user_id
    assert_equal ClientEmailStatus::UNVERIFIED, registered.user_email_status_id
  end

  test "create verifies the Turnstile token against the stealth secret the form's site key belongs to" do
    modes = []
    verify =
      lambda do |**arguments|
        modes << arguments[:mode]
        { "success" => true }
      end

    TurnstileVerifierStub.stub(:verify, verify) do
      post base_app_identity_emails_registration_url(ri: "jp", host: @host),
           params: { user_email: { raw_address: "app_email_reg_stealth@example.com" } }, headers: @headers
    end

    assert_response :redirect
    assert_equal [:stealth], modes
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_edit@example.com" } }, headers: @headers

    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_turnstile@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientEmailStatus::UNVERIFIED, pending.reload.user_email_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_blank@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    attempts_before = pending.otp_attempts_count

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_wrong@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal ClientEmailStatus::UNVERIFIED, pending.reload.user_email_status_id
  end

  test "update abandons the registration once the attempt limit is exceeded" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_locked@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    OtpLockable::MAX_OTP_ATTEMPTS.times do
      patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
            params: { user_email: { pass_code: wrong_code } }, headers: @headers
    end

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
    assert_nil session[:email_registration_public_id]
  end

  test "update verifies the address and returns to the identity page on the correct code" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_verified@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: code } }, headers: @headers

    assert_response :redirect
    assert_equal ClientEmailStatus::VERIFIED, pending.reload.user_email_status_id
    assert_nil session[:email_registration_public_id]
  end

  test "redelivery issues a new passcode for the pending registration" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_resend@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    first_counter = pending.otp_counter

    decision_time = pending.otp_last_sent_at + 5.minutes
    ClientEmail.stub(:database_now, decision_time) do
      travel 5.minutes do
        post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers
      end
    end

    assert_response :redirect
    assert_not_equal first_counter, pending.reload.otp_counter
  end

  test "redelivery inside the cooldown window does not reissue the passcode" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "app_email_reg_cooldown@example.com" } }, headers: @headers
    pending = ClientEmail.find_by!(public_id: session[:email_registration_public_id])
    first_counter = pending.otp_counter

    post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_equal first_counter, pending.reload.otp_counter
  end

  test "redelivery without a pending registration returns to the registration form" do
    post base_app_identity_emails_registration_redelivery_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end
end
