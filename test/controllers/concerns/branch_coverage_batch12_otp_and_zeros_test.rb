# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch12OtpAndZerosTest < ActionDispatch::IntegrationTest
  [[:app, :email], [:app, :telephone], [:com, :telephone]].each do |surface, channel|
    test "#{surface} #{channel} signup rejects missing and incorrect proof before accepting its scoped code" do
      owner_model, flow_model, owner_key, status =
        if surface == :app
          [Client, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        else
          [Visitor, VisitorSignUpFlow, :visitor_id, VisitorStatus::UNVERIFIED_WITH_SIGN_UP]
        end
      owner = owner_model.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status)
      contact =
        if channel == :email
          owner.client_emails.create!(
            raw_address: "scoped-otp-#{SecureRandom.hex(8)}@example.test",
            confirm_policy: true,
          )
        else
          model = (surface == :app) ? ClientTelephone : VisitorTelephone
          model.create!(
            owner_key => owner.id,
            :raw_number => "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(
              8,
              "0",
            )}", :confirm_policy => true,
          )
        end
      now = flow_model.database_now
      nonce = SecureRandom.hex(32)
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, entry_method: channel.to_s, step: "start",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
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
      assert_equal 0, ((surface == :app) ? ClientToken : VisitorToken).where(owner_key => owner.id).count
    end
  end

  test "com passkey signup endpoints refuse a browser without admission or a current flow" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    token_count = VisitorToken.count
    transaction_count = VisitorPasskeyCeremonyTransaction.count
    get "/sign/up/check/telephone/passkey", params: { ri: "jp" }

    assert_response :bad_request
    post "/sign/up/check/telephone/passkey", params: { ri: "jp" }

    assert_response :bad_request
    patch "/sign/up/check/telephone/passkey", params: { ri: "jp" }

    assert_response :bad_request
    assert_equal token_count, VisitorToken.count
    assert_equal transaction_count, VisitorPasskeyCeremonyTransaction.count
  end
end
