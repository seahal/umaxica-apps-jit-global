# frozen_string_literal: true

require "test_helper"

class IdentityTotpEnrollmentFinalCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Base creates the confirmed credential once and retries return the same active credential without freshness" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
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
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i), title: "Authenticator",
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      credential = nil
      assert_difference("actor.client_totp_credentials.count", 1) do
        credential = IdentityTotpEnrollmentFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )
      end

      assert_predicate credential, :active?
      assert_equal candidate.private_key, credential.private_key
      assert_equal candidate.reload.last_otp_at, credential.last_otp_at
      assert_equal "Authenticator", credential.title
      assert_equal "consumed", transaction.reload.status
      assert_equal credential.public_id, transaction.verified_credential_ref
      assert_equal "none", transaction.aal
      assert_not transaction.phishing_resistant
      assert_equal now, transaction.consumed_at
      assert_equal now, candidate.consumed_at
      assert_predicate ceremony.reload, :completed?
      child = ClientTotpCeremonyTransaction.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)

      assert_predicate child, :consumed?
      assert_equal transaction.result_jti, child.result_jti
      assert_no_difference("actor.client_totp_credentials.count") do
        repeated = IdentityTotpEnrollmentFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )

        assert_equal credential.id, repeated.id
      end
      assert_nil token.reload.last_step_up_at
      credential.update!(user_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentFinalCommitter.call!(
          actor: actor, token: token, transaction: transaction, raw_result: result.code,
        )
      end
      assert_predicate credential.reload, :revoked?
    end
  end

  test "a consumed registration with no principal credential fails closed instead of recreating one" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "bootstrap",
      required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: transaction, raw_result: result.code,
      )
      # A missing principal row also represents failure after the ticket commit and before the
      # principal commit. The old result must never authorize a second credential creation.
      credential.destroy!

      assert_no_difference("actor.client_totp_credentials.count") do
        assert_raises(IdentityTotpCeremonyContract::Error) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
          )
        end
      end
      assert_equal "consumed", transaction.reload.status
      assert_nil token.reload.last_step_up_at
    end
  end

  test "a principal write failure retains the unconsumed proof and candidate for a safe retry" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
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
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      # The principal persistence boundary fails while the real ticket locks and validation run.
      unavailable = ->(**_attributes) { raise ActiveRecord::ConnectionNotEstablished, "principal unavailable" }

      ClientTotpCredential.stub(:create_for_user!, unavailable) do
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          IdentityTotpEnrollmentFinalCommitter.call!(
            actor: actor, token: token, transaction: transaction, raw_result: result.code,
          )
        end
      end

      assert_equal "verified", transaction.reload.status
      assert_nil transaction.verified_credential_ref
      assert_nil candidate.reload.consumed_at
      assert_not_predicate ceremony.reload, :completed?
      assert_equal 0, actor.client_totp_credentials.count
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: transaction, raw_result: result.code,
      )

      assert_predicate credential, :active?
      assert_equal "consumed", transaction.reload.status
      assert_nil token.reload.last_step_up_at
    end
  end

  test "Base bootstrap retains the protected operation and only a subsequent TOTP assertion grants freshness" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    bootstrap_requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
      audience: "step_up:app", allowed_methods: [:totp], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: bootstrap_requirement, return_to: "/identity/birthdate",
    ).transaction
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "bootstrap_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    credential = nil
    ClientStepUpCeremonyTransaction.stub(:database_now, now) do
      IdentityTotpEnrollmentVerificationCommitter.call!(
        actor: actor, token: token, transaction: transaction, candidate_ref: candidate.ref,
        code: ROTP::TOTP.new(candidate.private_key).at(now.to_i),
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: transaction, raw_result: result.code,
      )
    end
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "step_up", audience: "step_up:app", allowed_methods: [:totp],
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )

    assert_predicate credential, :active?
    assert_equal "/identity/birthdate", transaction.reload.return_to
    assert_equal "bootstrap", transaction.purpose
    assert_equal "none", transaction.aal
    assert_nil token.reload.last_step_up_at
    assert_not StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
    # The registration window is consumed; independent reauthentication requires a new window.
    next_window = now + 30.seconds
    ClientStepUpCeremonyTransaction.stub(:database_now, next_window) do
      step_up = BaseStepUpAdmissionIssuer.call!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: step_up.transaction_id)
      continuity, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: step_up.transaction_id,
      )

      ClientTotpCredential.stub(:database_now, next_window) do
        assert IdentityStepUpTotpVerificationCommitter.call!(
          actor: actor, transaction: step_up, session_record: record, credential_public_id: credential.public_id,
          code: ROTP::TOTP.new(credential.private_key).at(next_window.to_i),
        )
      end
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: step_up, ceremony_session_ref: continuity.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: actor, token: token, transaction: step_up, requirement: requirement, raw_result: result.code,
      )

      assert_not_equal transaction.id, step_up.id
      assert_equal "consumed", step_up.reload.status
      assert_equal credential.public_id, step_up.verified_credential_ref
      assert_equal next_window, token.reload.last_step_up_at
      assert_equal "step_up", token.last_step_up_purpose
      assert_predicate StepUpResolver.call(token: token, requirement: requirement, now: next_window), :satisfied?
    end
  end
end
