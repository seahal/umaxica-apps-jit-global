# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch12OtpAndZerosTest < ActionDispatch::IntegrationTest
  # Only the app realm has public sign-up, so it is the sole OTP proof realm.
  [:email, :telephone].each do |channel|
    test "app #{channel} signup rejects missing and incorrect proof before accepting its scoped code" do
      owner = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      )
      contact =
        if channel == :email
          owner.client_emails.create!(
            raw_address: "scoped-otp-#{SecureRandom.hex(8)}@example.test",
            confirm_policy: true,
          )
        else
          ClientTelephone.create!(
            user_id: owner.id,
            :raw_number => "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(
              8,
              "0",
            )}", :confirm_policy => true,
          )
        end
      now = ClientSignUpFlow.database_now
      nonce = SecureRandom.hex(32)
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: owner.id, entry_method: channel.to_s, step: "start",
        nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      started = SignUpStateMachine.call(ticket: flow, event: :submit_contact, actor_context: nil)

      assert_predicate started, :success?
      issuer = (channel == :email) ? EmailSignUpOtpIssuer : TelephoneSignUpOtpIssuer
      verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
      scope = { :flow => flow, channel => contact, :session_nonce => nonce }
      missing = verifier.call(**scope, code: "012345")

      assert_equal :missing_challenge, missing.status
      issued = issuer.call(**scope)

      assert_predicate issued, :success?
      assert_equal :session_mismatch, issuer.call(**scope.merge(session_nonce: "other-browser")).status
      [nil, "", "0", "12345", "1234567"].each do |code|
        invalid = verifier.call(**scope, code: code)

        assert_equal :invalid_code, invalid.status
        assert_not invalid.verified_evidence?
      end
      wrong = (issued.code == "000000") ? "000001" : "000000"

      assert_equal :invalid_code, verifier.call(**scope, code: wrong).status
      assert_equal 1, contact.reload.otp_attempts_count
      assert_nil issued.transaction.reload.otp_consumed_at
      assert_nil contact.binding_finalized_at
      verified = verifier.call(**scope, code: issued.code)

      assert_predicate verified, :success?
      assert_predicate verified, :verified_evidence?
      assert_not_nil issued.transaction.reload.otp_consumed_at
      assert_equal 0, contact.reload.otp_attempts_count
      assert_nil contact.binding_finalized_at
      assert_equal "contact", flow.reload.step
      assert_equal 0, ClientToken.where(user_id: owner.id).count
    end
  end

  test "the corporate credential host routes no sign-in or sign-up ceremony" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")

    %w(/sign/in /sign/up /sign/out /verification /verification/passkey/options /ceremony_bindings).each do |path|
      assert_raises(ActionController::RoutingError, "#{path} must stay unrouted on the corporate host") do
        Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)
      end
    end
  end
end
