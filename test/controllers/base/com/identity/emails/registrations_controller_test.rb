# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching an email address to a visitor on the
# corporate surface: the two-step OTP flow plus the invalid-address,
# missing-code, wrong-code, lock-out, and expired-session branches guarding it.
class Base::Com::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_statuses, :visitor_email_statuses,
           :visitor_token_kinds, :visitor_token_statuses, :visitor_token_binding_methods,
           :visitor_token_dbsc_statuses

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    install_base_browser_rp_credentials!(surface: "com", host: @host, actor: @visitor, token: @token)
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    # Synthetic credential evidence isolates contact mutation; Base finalization is the real public operation.
    @passkey = @visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "com-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @visitor.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
    )
    transaction = issue_base_step_up_admission!(
      actor: @visitor, token: @token, requirement: requirement, return_to: "/identity/emails/registration/new",
    ).transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: VisitorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.public_id,
    )
    ceremony, = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @visitor, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )
    access_token = AuthenticationToken.encode(
      @visitor, host: @host, session_public_id: @token.public_id,
                resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
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

  test "new renders the registration form and leaves no pending registration in the session" do
    get new_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:com_settings_email_registration_public_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end

  test "create rejects an address that fails model validation" do
    assert_no_difference("VisitorEmail.count") do
      post base_com_identity_emails_registration_url(ri: "jp", host: @host),
           params: { visitor_email: { raw_address: "not-an-email" } }, headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("VisitorEmail.count", 1) do
      post base_com_identity_emails_registration_url(ri: "jp", host: @host),
           params: { visitor_email: { raw_address: "com_reg_created@example.com", notifiable: "1" } },
           headers: @headers
    end

    assert_response :redirect
    assert_match %r{/identity/emails/registration/edit}, response.location
    registered = VisitorEmail.find_by!(public_id: session[:com_settings_email_registration_public_id])

    assert_equal @visitor.id, registered.visitor_id
    assert_equal VisitorEmailStatus::UNVERIFIED, registered.visitor_email_status_id
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_edit@example.com" } }, headers: @headers

    get edit_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "123456" } }, headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_blank_code@example.com" } }, headers: @headers
    pending = VisitorEmail.find_by!(public_id: session[:com_settings_email_registration_public_id])
    attempts_before = pending.otp_attempts_count

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_wrong_code@example.com" } }, headers: @headers
    pending = VisitorEmail.find_by!(public_id: session[:com_settings_email_registration_public_id])
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s
    freshness_before = @token.reload.last_step_up_at

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorEmailStatus::UNVERIFIED, pending.reload.visitor_email_status_id
    assert_equal freshness_before, @token.reload.last_step_up_at
  end

  test "update discards the pending registration once the attempt limit locks it" do
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_locked@example.com" } }, headers: @headers
    pending_public_id = session[:com_settings_email_registration_public_id]
    pending = VisitorEmail.find_by!(public_id: pending_public_id)
    otp = pending.get_otp
    wrong_code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter] + 1).to_s

    OtpLockable::MAX_OTP_ATTEMPTS.times do
      patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
            params: { visitor_email: { pass_code: wrong_code } }, headers: @headers
    end

    assert_redirected_to new_base_com_identity_emails_registration_path(ri: "jp")
    assert_nil VisitorEmail.find_by(public_id: pending_public_id)
  end

  test "update verifies the address and returns to the identity page on the correct code" do
    other_token = VisitorToken.create!(visitor: @visitor)
    other_requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @visitor.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: other_token.public_id, token_binding: other_token.public_id, require_session_binding: true,
    )
    pending_transaction = issue_base_step_up_admission!(
      actor: @visitor, token: other_token, requirement: other_requirement,
      return_to: "/identity/emails/registration/new",
    ).transaction
    pending_ceremony, = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: pending_transaction.transaction_id,
    )
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_verified@example.com" } }, headers: @headers
    pending = VisitorEmail.find_by!(public_id: session[:com_settings_email_registration_public_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: code } }, headers: @headers

    assert_response :redirect
    assert_equal VisitorEmailStatus::VERIFIED, pending.reload.visitor_email_status_id
    assert_nil session[:com_settings_email_registration_public_id]
    assert_nil @token.reload.last_step_up_at
    assert_equal "revoked", pending_transaction.reload.status
    assert_not_nil pending_ceremony.reload.revoked_at
    assert_predicate @token, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  test "revoked credential history does not qualify for the first-contact exception" do
    visitor = Visitor.create!
    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "revoked-contact-test-public-key", sign_count: 0,
      status_id: VisitorPasskeyStatus::REVOKED,
    )
    token = VisitorToken.create!(visitor: visitor)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    install_base_browser_rp_credentials!(surface: "com", host: @host, actor: visitor, token: token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      visitor, host: @host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )

    assert_empty StepUpConfiguredMethodsQuery.call(visitor)
    assert_not StepUpBootstrapEligibilityQuery.call(actor: visitor)
    assert_no_difference ["VisitorEmail.count", "VisitorStepUpCeremonyTransaction.count"] do
      post base_com_identity_emails_registration_path(ri: "jp"),
           params: { visitor_email: { raw_address: "revoked-com-contact-#{SecureRandom.hex(4)}@example.com" } },
           headers: { "Host" => @host, "Client-Agent" => "Mozilla/5.0" }, as: :json
    end

    assert_response :unprocessable_content
    assert_nil token.reload.last_step_up_at
    assert_predicate token, :currently_usable?
    assert_no_difference("VisitorEmail.count") do
      post base_com_identity_emails_registration_path(ri: "jp"),
           params: { visitor_email: { raw_address: "revoked-html-contact-#{SecureRandom.hex(4)}@example.com" } },
           headers: { "Host" => @host, "Client-Agent" => "Mozilla/5.0" }
    end

    assert_response :see_other
    assert_equal base_com_verification_path, URI.parse(response.location).path
    assert_nil session[:flash]
  end

  test "first confirmed contact is registered on Base without freshness and ends the initial exception" do
    visitor = Visitor.create!
    token = VisitorToken.create!(visitor: visitor)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    install_base_browser_rp_credentials!(surface: "com", host: @host, actor: visitor, token: token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      visitor, host: @host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    headers = { "Host" => @host, "Client-Agent" => "Mozilla/5.0" }

    assert_nil token.last_step_up_at
    assert_empty StepUpConfiguredMethodsQuery.call(visitor)
    assert_difference(-> { visitor.visitor_emails.count }, 1) do
      post base_com_identity_emails_registration_path(ri: "jp"),
           params: { visitor_email: { raw_address: "first-com-contact-#{SecureRandom.hex(4)}@example.com" } },
           headers: headers
    end

    assert_response :redirect
    pending = visitor.visitor_emails.find_by!(public_id: session[:com_settings_email_registration_public_id])
    otp = pending.get_otp
    code = ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s
    patch base_com_identity_emails_registration_path(ri: "jp"),
          params: { visitor_email: { pass_code: code } }, headers: headers

    assert_response :redirect
    assert_equal VisitorEmailStatus::VERIFIED, pending.reload.visitor_email_status_id
    assert_nil token.reload.last_step_up_at
    assert_predicate token, :currently_usable?
    assert_includes StepUpConfiguredMethodsQuery.call(visitor), :email_otp
    assert_no_difference(-> { visitor.visitor_emails.count }) do
      post base_com_identity_emails_registration_path(ri: "jp"),
           params: { visitor_email: { raw_address: "another-com-contact-#{SecureRandom.hex(4)}@example.com" } },
           headers: headers
    end

    assert_response :unauthorized
    assert_nil token.reload.last_step_up_at
    assert_empty visitor.visitor_passkeys
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "com_reg_expired@example.com" } }, headers: @headers
    VisitorEmail.find_by!(public_id: session[:com_settings_email_registration_public_id])
      .update!(otp_expires_at: 1.minute.ago)

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "123456" } }, headers: @headers

    assert_response :redirect
    assert_match %r{/identity/emails/registration/new}, response.location
  end
end
