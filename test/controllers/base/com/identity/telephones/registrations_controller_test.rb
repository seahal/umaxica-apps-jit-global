# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching a telephone number to a visitor on the
# corporate surface: the two-step OTP flow plus the Turnstile, missing-code,
# wrong-code, lock-out, and expired-session branches guarding it.
class Base::Com::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :visitors, :visitor_statuses, :visitor_telephone_statuses,
           :visitor_token_kinds, :visitor_token_statuses, :visitor_token_binding_methods,
           :visitor_token_dbsc_statuses

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = Visitor.create!
    @visitor.visitor_emails.create!(
      address: "telephone-settings-proof@example.test", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    ).finalize_binding!
    passkey = @visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "telephone-settings-proof", uv_verified_at: Time.current,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    install_base_browser_rp_credentials!(surface: "com", host: @host, actor: @visitor, token: @token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: @token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
      last_step_up_credential_ref: passkey.public_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      @visitor, host: @host, session_public_id: @token.public_id,
                resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    install_base_browser_rp_credentials!(
      surface: "com", host: @host, actor: @visitor, token: @token,
    )
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

  test "management create queues own ceremony and completes through the existing registration endpoint" do
    clear_enqueued_jobs
    post base_com_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "+12025550179" } }, headers: @headers

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    telephone = VisitorTelephone.find(session[:settings_telephone_registration_id])
    transaction = VisitorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal telephone.public_id, transaction.telephone_candidate_ref
    assert_equal ["com", "credential_registration", transaction.transaction_id, telephone.public_id,
                  transaction.otp_generation,], payload.fetch(:otp_binding)
    assert_not_includes JSON.generate(job.fetch(:args)), payload.fetch(:otp_code)

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

    assert_redirected_to base_com_identity_telephones_url(ri: "jp", host: @host)
    assert_predicate telephone.reload, :binding_effective?
    assert_predicate transaction.reload, :consumed?
    assert_nil session[:settings_telephone_registration_id]
    assert_nil session[:settings_telephone_registration_transaction_ref]
  end

  test "create queues a random Telephone ceremony code and update finalizes that exact encrypted proof" do
    clear_enqueued_jobs
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+12025550172" } }, headers: @headers

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    job = enqueued_jobs.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal 4, payload.fetch(:version)
    assert_nil pending.credential_registration_otp_context
    transaction = VisitorTelephoneCeremonyTransaction.find_by!(transaction_id: payload.fetch(:otp_binding).fetch(2))

    assert_equal pending.public_id, transaction.telephone_candidate_ref
    assert_equal "credential_registration", transaction.purpose
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

    assert_redirected_to base_com_identity_telephones_path(ri: "jp")
    assert_predicate pending.reload, :binding_effective?
    assert_predicate transaction.reload, :consumed?
    assert VisitorContactAuditOutbox.exists?(
      operation_ref: transaction.transaction_id, contact_ref: pending.public_id, event_name: "finalized",
    )
  end

  %w(current cancelled expired reissued).each do |state|
    test "HTTP created Telephone registration SMS checks #{state} proof before transport" do
      clear_enqueued_jobs
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { visitor_telephone: { raw_number: "+12025550174" } }, headers: @headers

      assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
      transaction = VisitorTelephoneCeremonyTransaction.find_by!(
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
    get new_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:settings_telephone_registration_id]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { visitor_telephone: { raw_number: "+15558675331" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create rejects a number that cannot be normalized to E.164" do
    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { visitor_telephone: { raw_number: "not-a-number" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("VisitorTelephone.count", 1) do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { visitor_telephone: { raw_number: "+15558675332" } }, headers: @headers
    end

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    registered = VisitorTelephone.find(session[:settings_telephone_registration_id])

    assert_equal @visitor.id, registered.visitor_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED, registered.visitor_telephone_status_id
  end

  test "create refuses the obsolete user scope instead of adopting an unpublished parameter fallback" do
    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { user_telephone: { raw_number: "+15558675332" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:settings_telephone_registration_id]
  end

  test "first telephone attachment requires scoped Step-Up despite existing verified email" do
    @token.update!(last_step_up_at: nil)

    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { visitor_telephone: { raw_number: "+15558675367" } }, headers: @headers
    end

    assert_response :unauthorized
    assert_nil session[:settings_telephone_registration_id]
    assert_not VisitorContactAuditOutbox.exists?(owner_ref: @visitor.public_id)
  end

  test "telephone confirmation refuses expired Step-Up without consuming OTP or finalizing binding" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675368" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    transaction = VisitorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    original = transaction.attributes.slice("otp_verifier", "otp_generation", "otp_consumed_at")
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)
    @token.update!(last_step_up_at: nil)

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: code } }, headers: @headers

    assert_response :unauthorized
    assert_equal original, transaction.reload.attributes.slice(*original.keys)
    assert_not pending.binding_effective?
    assert_not VisitorContactAuditOutbox.exists?(operation_ref: transaction.transaction_id)
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675333" } }, headers: @headers

    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675334" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED, pending.reload.visitor_telephone_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675335" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    attempts_before = pending.otp_attempts_count

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675336" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    wrong_code = (payload.fetch(:otp_code) == "000000") ? "000001" : "000000"

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED, pending.reload.visitor_telephone_status_id
  end

  test "update clears the session but retains candidate failures once the attempt limit locks it" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675337" } }, headers: @headers
    pending_id = session[:settings_telephone_registration_id]
    pending = VisitorTelephone.find(pending_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    wrong_code = (payload.fetch(:otp_code) == "000000") ? "000001" : "000000"

    TelephoneOtpPolicy::MAX_OTP_ATTEMPTS.times do
      patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
            params: { visitor_telephone: { pass_code: wrong_code } }, headers: @headers
    end

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
    assert_equal TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, pending.reload.otp_attempts_count
    assert_predicate pending, :locked?
    assert_not pending.binding_effective?
    assert_nil session[:settings_telephone_registration_id]
  end

  test "separate settings starts for the same telephone retain independent candidates and ceremony generations" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675366" } }, headers: @headers
    first = VisitorTelephone.find(session[:settings_telephone_registration_id])
    first_transaction = VisitorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    generation = first_transaction.otp_generation
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675366" } }, headers: @headers
    second = VisitorTelephone.find(session[:settings_telephone_registration_id])

    assert_response :found
    assert_not_equal first.id, second.id
    assert_equal first.number_digest, second.number_digest
    assert_equal generation, first_transaction.reload.otp_generation
    assert_not_equal first_transaction.transaction_id, session[:settings_telephone_registration_transaction_ref]
    assert_not first.binding_effective?
    assert_not second.binding_effective?
  end

  test "telephone replacement preserves the old binding on wrong OTP and atomically audits the successful swap" do
    previous = @visitor.visitor_telephones.create!(
      number: "+15558675363", visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED, confirm_policy: "1",
    )
    previous.finalize_binding!
    previous.update!(otp_attempts_count: 2)
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675364" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    operation_ref = session[:settings_telephone_registration_transaction_ref]
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)
    wrong = (code == "000000") ? "000001" : "000000"
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: wrong } }, headers: @headers

    assert_response :unprocessable_content
    assert_predicate previous.reload, :binding_effective?
    assert_equal 2, previous.otp_attempts_count
    assert_not VisitorContactAuditOutbox.exists?(operation_ref: operation_ref)
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: code } }, headers: @headers

    assert_response :found
    assert_predicate previous.reload, :binding_released?
    assert_equal 2, previous.otp_attempts_count
    assert_predicate pending.reload, :binding_effective?
    assert_equal [pending.id], @visitor.visitor_telephones.effective_binding.pluck(:id)
    assert_equal [[previous.public_id, "released"], [pending.public_id, "finalized"]],
                 VisitorContactAuditOutbox.where(operation_ref: operation_ref).order(:id)
                   .pluck(:contact_ref, :event_name)
  end

  test "update verifies the telephone number and returns to the identity page on the correct code" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675338" } }, headers: @headers
    pending = VisitorTelephone.find(session[:settings_telephone_registration_id])
    operation_ref = session[:settings_telephone_registration_transaction_ref]
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: code } }, headers: @headers

    assert_redirected_to base_com_identity_telephones_url(ri: "jp", host: @host)
    intent = VisitorContactAuditOutbox.find_by!(contact_ref: pending.public_id, event_name: "finalized")

    assert_equal @visitor.public_id, intent.owner_ref
    assert_equal @visitor.public_id, intent.actor_ref
    assert_equal operation_ref, intent.operation_ref
    assert_nil intent.acknowledged_at
    assert_nil session[:settings_telephone_registration_id]
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { visitor_telephone: { raw_number: "+15558675339" } }, headers: @headers
    transaction = VisitorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    transaction.update!(otp_expires_at: transaction.class.database_now - 1.minute)

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { visitor_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end
end
