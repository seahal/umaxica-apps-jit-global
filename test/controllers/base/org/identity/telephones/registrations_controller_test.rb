# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration ceremony for attaching a telephone number to an operator on the
# staff surface: the two-step OTP flow plus the Turnstile, missing-code,
# wrong-code, lock-out, and expired-session branches guarding it.
class Base::Org::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :operators, :operator_statuses, :operator_telephone_statuses,
           :operator_token_kinds, :operator_token_statuses, :operator_token_binding_methods,
           :operator_token_dbsc_statuses, :operator_passkeys

  setup do
    clear_enqueued_jobs
    https!
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    install_base_browser_rp_credentials!(surface: "org", host: @host, actor: @operator, token: @token)
    passkey = @operator.operator_passkeys.first!
    passkey.update!(uv_verified_at: Time.current)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: @token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
      last_step_up_credential_ref: passkey.external_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
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

  test "new renders the registration form and leaves no pending registration in the session" do
    get new_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil session[:staff_telephone_registration_id]
  end

  test "management create starts own numeric candidate ceremony and completes through registration" do
    post base_org_identity_telephones_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675332" } }, headers: @headers

    assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
    telephone = OperatorTelephone.find(session[:staff_telephone_registration_id])
    transaction = OperatorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    job = enqueued_jobs.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal ["org", "credential_registration", transaction.transaction_id, telephone.id.to_s,
                  transaction.otp_generation,], payload.fetch(:otp_binding)

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

    assert_redirected_to base_org_identity_telephones_url(ri: "jp", host: @host)
    assert_equal OperatorTelephoneStatus::VERIFIED, telephone.reload.staff_telephone_status_id
    assert_predicate transaction.reload, :consumed?
    assert_nil session[:staff_telephone_registration_id]
    assert_nil session[:settings_telephone_registration_transaction_ref]
  end

  test "edit redirects back to new when no registration is in progress" do
    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
  end

  test "create rejects the submission when the stealth Turnstile check fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("OperatorTelephone.count") do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "+15558675321" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:staff_telephone_registration_id]
  end

  test "create rejects a number that cannot be normalized to E.164" do
    assert_no_difference("OperatorTelephone.count") do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "not-a-number" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_nil session[:staff_telephone_registration_id]
  end

  test "telephone capacity permits MAX minus one and MAX then rejects MAX plus one" do
    assert_equal 0, @operator.staff_telephones.count
    OperatorTelephone::MAX_TELEPHONES_PER_STAFF.times do |index|
      assert_difference("OperatorTelephone.count", 1) do
        post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
             params: { staff_telephone: { raw_number: "+1555867#{format("%04d", 5500 + index)}" } }, headers: @headers
      end

      assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
      assert_equal index + 1, @operator.staff_telephones.count
    end
    assert_no_difference("OperatorTelephone.count") do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "+15558675599" } }, headers: @headers
    end

    assert_response :unprocessable_content
    assert_equal OperatorTelephone::MAX_TELEPHONES_PER_STAFF, @operator.staff_telephones.count
    assert_includes response.body, "maximum telephones"
  end

  test "create stores the pending registration and moves the ceremony to the verification step" do
    assert_difference("OperatorTelephone.count", 1) do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "+15558675322" } }, headers: @headers
    end

    assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
    registered = OperatorTelephone.find(session[:staff_telephone_registration_id])

    assert_equal @operator.id, registered.staff_id
    assert_equal OperatorTelephoneStatus::UNVERIFIED, registered.staff_telephone_status_id
    transaction = OperatorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

    assert_equal ["org", "credential_registration", transaction.transaction_id, registered.id.to_s,
                  transaction.otp_generation,], payload.fetch(:otp_binding)
    assert_equal @operator.public_id, transaction.actor_ref
    assert_equal "registration", transaction.operation
    assert_equal "credential_registration", transaction.purpose
    assert_equal @token.public_id,
                 CredentialRegistrationOtpSessionValue.load(session_ref: transaction.session_ref).root_ref
    assert_match(/\A[0-9]{6}\z/, payload.fetch(:otp_code))
    assert_not_includes JSON.generate(job.fetch(:args)), payload.fetch(:otp_code)
  end

  test "edit renders the verification step while the registration session is valid" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675323" } }, headers: @headers

    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
  end

  test "update redirects back to new when the session holds no pending registration" do
    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
  end

  test "update rejects the verification when the stealth Turnstile check fails" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675324" } }, headers: @headers
    pending = OperatorTelephone.find(session[:staff_telephone_registration_id])
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "123456" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal OperatorTelephoneStatus::UNVERIFIED, pending.reload.staff_telephone_status_id
  end

  test "update rejects a blank verification code before consuming an OTP attempt" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675325" } }, headers: @headers
    pending = OperatorTelephone.find(session[:staff_telephone_registration_id])
    attempts_before = pending.otp_attempts_count

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "" } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal attempts_before, pending.reload.otp_attempts_count
  end

  test "update re-renders the verification step when the submitted code is wrong" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675326" } }, headers: @headers
    pending = OperatorTelephone.find(session[:staff_telephone_registration_id])
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    wrong_code = (payload.fetch(:otp_code) == "000000") ? "000001" : "000000"

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal OperatorTelephoneStatus::UNVERIFIED, pending.reload.staff_telephone_status_id
    assert_equal 1, pending.otp_attempts_count
  end

  test "update clears the session but retains candidate failures once the attempt limit locks it" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675327" } }, headers: @headers
    pending_id = session[:staff_telephone_registration_id]
    pending = OperatorTelephone.find(pending_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    wrong_code = (payload.fetch(:otp_code) == "000000") ? "000001" : "000000"

    TelephoneOtpPolicy::MAX_OTP_ATTEMPTS.times do
      patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
            params: { staff_telephone: { pass_code: wrong_code } }, headers: @headers
    end

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
    assert_nil session[:staff_telephone_registration_id]
    assert_nil session[:settings_telephone_registration_transaction_ref]
    assert_equal TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, pending.reload.otp_attempts_count
    assert pending.locked_at
    assert_equal OperatorTelephoneStatus::UNVERIFIED, pending.staff_telephone_status_id
  end

  test "update verifies the telephone number and returns to the identity page on the correct code" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675328" } }, headers: @headers
    pending = OperatorTelephone.find(session[:staff_telephone_registration_id])
    transaction = OperatorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
    code = payload.fetch(:otp_code)

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: code } }, headers: @headers

    assert_redirected_to base_org_identity_telephones_url(ri: "jp", host: @host)
    assert_nil session[:staff_telephone_registration_id]
    assert_nil session[:settings_telephone_registration_transaction_ref]
    assert_equal OperatorTelephoneStatus::VERIFIED, pending.reload.staff_telephone_status_id
    assert_predicate transaction.reload, :consumed?
    assert transaction.otp_consumed_at
  end

  test "update treats an expired one-time passcode as an expired registration session" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "+15558675329" } }, headers: @headers
    transaction = OperatorTelephoneCeremonyTransaction.find_by!(
      transaction_id: session[:settings_telephone_registration_transaction_ref],
    )
    transaction.update!(otp_expires_at: 1.minute.ago)

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "123456" } }, headers: @headers

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
  end

  %w(foreign_actor foreign_session foreign_candidate wrong_operation canceled).each do |mismatch|
    test "update refuses #{mismatch} Telephone ceremony without finalizing or counting a guess" do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "+15558675330" } }, headers: @headers
      pending = OperatorTelephone.find(session[:staff_telephone_registration_id])
      transaction = OperatorTelephoneCeremonyTransaction.find_by!(
        transaction_id: session[:settings_telephone_registration_transaction_ref],
      )
      job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
      payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
      case mismatch
      when "foreign_actor" then transaction.update!(actor_ref: operators(:two).public_id)
      when "foreign_session"
        foreign = CredentialRegistrationOtpSessionValue.for(
          surface: "org", channel: :telephone, transaction_ref: transaction.transaction_id,
          root_ref: @token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
        )
        transaction.update!(session_ref: foreign.dump)
      when "foreign_candidate" then transaction.update!(telephone_candidate_ref: "0")
      when "wrong_operation" then transaction.update!(operation: "sign_in")
      when "canceled" then transaction.cancel_telephone_otp!
      end

      patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
            params: { staff_telephone: { pass_code: payload.fetch(:otp_code) } }, headers: @headers

      assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
      assert_equal OperatorTelephoneStatus::UNVERIFIED, pending.reload.staff_telephone_status_id
      assert_equal 0, pending.otp_attempts_count
      assert_nil transaction.reload.consumed_at
      assert_nil session[:staff_telephone_registration_id]
      assert_nil session[:settings_telephone_registration_transaction_ref]
    end
  end

  %w(current canceled expired reissued root_revoked owner_changed).each do |state|
    test "HTTP created ORG registration SMS checks #{state} numeric candidate proof before transport" do
      post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
           params: { staff_telephone: { raw_number: "+15558675331" } }, headers: @headers

      assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
      telephone = OperatorTelephone.find(session[:staff_telephone_registration_id])
      transaction = OperatorTelephoneCeremonyTransaction.find_by!(
        transaction_id: session[:settings_telephone_registration_transaction_ref],
      )
      job = enqueued_jobs.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
      payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))

      assert_equal 4, payload.fetch(:version)
      assert_equal telephone.id.to_s, payload.fetch(:otp_binding).fetch(3)
      assert_not_includes JSON.generate(job.fetch(:args)), payload.fetch(:otp_code)
      assert_not_includes JSON.generate(job.fetch(:args)), telephone.number
      transaction.cancel_telephone_otp! if state == "canceled"
      transaction.issue_telephone_otp!(purpose: "credential_registration") if state == "reissued"
      @token.update!(discard_at: @token.class.database_now) if state == "root_revoked"
      telephone.update!(staff: operators(:two)) if state == "owner_changed"
      now = (state == "expired") ? transaction.otp_expires_at : transaction.class.database_now
      transported = []
      transaction.class.stub(:database_now, now) do
        OutboundSms.stub(:deliver_now, ->(**message) { transported << message }) do
          perform_enqueued_jobs(only: Outbound::SmsDeliveryJob)
        end
      end

      assert_equal (state == "current") ? 1 : 0, transported.length
      if state == "current"
        assert_equal telephone.number, transported.fetch(0).fetch(:to)
        assert_includes transported.fetch(0).fetch(:body), payload.fetch(:otp_code)
      end
    end
  end

  %w(source_rollback ticket_fault lost_freshness lost_passkey foreign_browser).each do |state|
    test "ORG named Telephone finalizer #{state} preserves Source before bounded Ticket reconciliation" do
      telephone = @operator.staff_telephones.create!(
        raw_number: "+15558675333", confirm_policy: true, confirm_using_mfa: true,
      )
      nonce = SecureRandom.urlsafe_base64(32)
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: @operator, token: @token, telephone: telephone, browser_nonce: nonce,
      )
      verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
        actor: @operator, token: @token, telephone: telephone, transaction: issued.transaction,
        browser_nonce: nonce, code: issued.code,
      )

      assert_predicate verified, :success?
      arguments = {
        actor: @operator,
        token: @token,
        telephone: telephone,
        transaction: issued.transaction,
        browser_nonce: nonce,
        code: issued.code,
        actor_context: ActorValuesContext.empty.with(
          subject: @operator, actor_type: :operator, tld: :org, surface: :base,
        ),
        requirement: OperatorTelephonePolicy.new(telephone, user: @operator)
          .credential_registration_requirement(token: @token),
      }
      case state
      when "source_rollback"
        rollback =
          lambda do |&finalization|
            telephone.class.transaction(requires_new: true) do
              telephone.lock!
              finalization.call
              raise ActiveRecord::StatementInvalid
            end
          end

        telephone.stub(:with_lock, rollback) do
          assert_raises(ActiveRecord::StatementInvalid) do
            OperatorTelephoneRegistrationOtpFinalizer.call!(**arguments)
          end
        end

        assert_equal OperatorTelephoneStatus::UNVERIFIED, telephone.reload.staff_telephone_status_id
        assert_nil issued.transaction.reload.consumed_at
      when "ticket_fault"
        issued.transaction.stub(:consume_registration_result!, -> { raise ActiveRecord::StatementInvalid }) do
          assert_raises(ActiveRecord::StatementInvalid) do
            OperatorTelephoneRegistrationOtpFinalizer.call!(**arguments)
          end
        end

        assert_equal OperatorTelephoneStatus::VERIFIED, telephone.reload.staff_telephone_status_id
        assert_nil issued.transaction.reload.consumed_at
        assert_equal :finalized, OperatorTelephoneRegistrationOtpFinalizer.call!(**arguments)
        assert_predicate issued.transaction.reload, :consumed?
        deadline = issued.transaction.otp_result_expires_at

        issued.transaction.class.stub(:database_now, deadline) do
          assert_equal :unavailable, OperatorTelephoneRegistrationOtpFinalizer.call!(**arguments)
        end

        assert_equal OperatorTelephoneStatus::VERIFIED, telephone.reload.staff_telephone_status_id
      else
        case state
        when "lost_freshness" then @token.update!(last_step_up_at: @token.class.database_now - 15.minutes)
        when "lost_passkey" then @operator.operator_passkeys.first!.update!(status_id: OperatorPasskeyStatus::REVOKED)
        when "foreign_browser" then arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
        end

        assert_equal :unavailable, OperatorTelephoneRegistrationOtpFinalizer.call!(**arguments)
        assert_equal OperatorTelephoneStatus::UNVERIFIED, telephone.reload.staff_telephone_status_id
        assert_nil issued.transaction.reload.consumed_at
      end
    end
  end
end
