# frozen_string_literal: true

require "test_helper"

class IdentityTotpEnrollmentVerificationCommitterTest < ActiveSupport::TestCase
  # This operation owns enrollment data; unrelated credential fixtures are outside its boundary.
  self.fixture_table_names = []
  fixtures :clients, :client_statuses

  test "first code accepts six digits and refuses five seven embedded letters and NUL" do
    %i(five six seven letter nul).each_with_index do |format, index|
      actor = Client.create!(id: 9_105_000_000_000 + index, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", required_aal: "none", step_up_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
        require_session_binding: true, allowed_methods: ["totp"],
      )
      record = ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
      now = ClientStepUpCeremonyTransaction.database_now
      correct = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
      code =
        case format
        when :five then correct.first(5)
        when :six then correct
        when :seven then "#{correct}0"
        when :letter then "#{correct.first(3)}x#{correct.last(3)}"
        when :nul then "#{correct.first(3)}\0#{correct.last(3)}"
        end
      accepted = nil

      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        assert_no_difference("ClientTotpCredential.count") do
          accepted = IdentityTotpEnrollmentVerificationCommitter.call!(
            actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref, code: code,
          )
        end
      end

      assert_equal format == :six, accepted, format.to_s
      assert_equal (format == :six) ? "verified" : "pending", transaction.reload.status, format.to_s
      assert_equal (format == :six) ? 0 : 1, record.reload.attempt_count, format.to_s
      assert_nil token.reload.last_step_up_at
    end
  end

  test "initial code confirms the encrypted candidate once without credential creation or freshness" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      assert_no_difference("ClientTotpCredential.count") do
        assert IdentityTotpEnrollmentVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref, code: code,
          title: "Authenticator",
        )
      end

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref, code: code,
        )
      end
    end

    assert_not_nil candidate.reload.last_otp_at
    assert_equal "Authenticator", candidate.title
    assert_equal "verified", transaction.reload.status
    assert_equal "totp", transaction.method
    assert_equal "none", transaction.aal
    assert_not transaction.phishing_resistant
    assert_nil transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_equal now, transaction.verified_at
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction)
    payload = BaseAuthAdmissionCoordinator.read_result!(
      raw_code: result.code, surface: "app", transaction_ref: transaction.transaction_id,
      expected_intent: "credential_registration",
    )

    assert_equal "credential_registration_result", payload.fetch("purpose")
    requirement = StepUpRequirement.new(
      scope: "settings_totp", step_up_required: true, allowed_methods: [:totp], purpose: "step_up",
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil, audience: "step_up:app",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: actor, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
      )
    end
    assert_nil token.reload.last_step_up_at
    assert_equal "verified", transaction.reload.status
  end

  test "the fourth and fifth failed confirmations persist and subsequent attempts are rejected" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["totp"],
    )
    record = ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING", attempt_count: 3,
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    [4, 5].each do |attempts|
      assert_not IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref, code: "invalid",
      )
      assert_equal attempts, record.reload.attempt_count
    end

    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).now,
      )
    end
    assert_equal 5, record.reload.attempt_count
    assert_nil candidate.reload.last_otp_at
    assert_equal "pending", transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "title length below at and above 32 preserves enrollment authorization" do
    [31, 32, 33].each do |length|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", required_aal: "none", step_up_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
        require_session_binding: true, allowed_methods: ["totp"],
      )
      record = ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
      now = ClientStepUpCeremonyTransaction.database_now

      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        assert_equal length <= 32, IdentityTotpEnrollmentVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
          code: ROTP::TOTP.new(candidate.private_key).at(now.to_i), title: "x" * length,
        )
      end
      assert_equal (length <= 32) ? "verified" : "pending", transaction.reload.status
      assert_equal 0, record.reload.attempt_count
      assert_nil token.reload.last_step_up_at
    end
  end

  test "missing empty zero NUL and non-string codes consume a failure without confirming the candidate" do
    [nil, "", 0, "\0", ["123456"]].each do |code|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", required_aal: "none", step_up_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
        require_session_binding: true, allowed_methods: ["totp"],
      )
      record = ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)

      assert_not IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref, code: code,
      )
      assert_equal 1, record.reload.attempt_count
      assert_equal "pending", transaction.reload.status
      assert_nil candidate.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
    end
  end

  test "cancellation logout and refresh end enrollment without transferring its candidate" do
    %i(cancel logout refresh).each do |transition|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", required_aal: "none", step_up_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
        require_session_binding: true, allowed_methods: ["totp"],
      )
      ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
      ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "credential_registration_handoff",
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      case transition
      when :cancel
        IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: transaction)
      when :logout
        token.revoke!
      when :refresh
        raw = token.rotate_refresh_token!
        _, verifier = ClientToken.parse_refresh_token(raw)
        result = ClientToken.rotate_refresh!(presented_refresh_digest: ClientToken.digest_refresh_token(verifier))

        assert_equal :rotated, result.fetch(:status)
        assert_nil result.fetch(:token).last_step_up_at
      end

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentVerificationCommitter.call!(
          actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
          code: ROTP::TOTP.new(candidate.private_key).now,
        )
      end
      assert_equal (transition == :cancel) ? "canceled" : "revoked", transaction.reload.status
      assert_not ceremony.reload.active?(now: ClientAuthCeremonySession.database_now)
      assert_nil candidate.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
      assert_equal 0, actor.client_totp_credentials.count
    end
  end
end
