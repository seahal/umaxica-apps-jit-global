# frozen_string_literal: true

require "test_helper"

class IdentityStepUpTotpVerificationCommitterTest < ActiveSupport::TestCase
  fixtures :client_statuses

  setup do
    @actor = Client.create!(status_id: ClientStatus::ACTIVE)
    @credential = ClientTotpCredential.create_for_user!(
      user: @actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @token = ClientToken.create!(user: @actor)
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: @token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["totp"], return_to: "/identity/emails",
    )
    @record = ClientStepUpSession.create!(
      user_token: @token, step_up_ceremony_transaction_ref: @transaction.transaction_id,
      scope: @transaction.required_scope, return_to: @transaction.return_to,
      status: "PENDING", discard_at: @transaction.expires_at,
    )
  end

  test "a real TOTP records one credential-bound proof with no Base freshness" do
    now = ClientTotpCredential.database_now
    code = ROTP::TOTP.new(@credential.private_key).at(now.to_i)
    ClientTotpCredential.stub(:database_now, now) do
      assert IdentityStepUpTotpVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record,
        code: code, credential_public_id: @credential.public_id,
      )
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpTotpVerificationCommitter.call!(
          actor: @actor, transaction: @transaction, session_record: @record,
          code: code, credential_public_id: @credential.public_id,
        )
      end
    end
    assert_equal "verified", @transaction.reload.status
    assert_equal "totp", @transaction.method
    assert_equal "aal1", @transaction.aal
    assert_not @transaction.phishing_resistant
    assert_equal @credential.public_id, @transaction.verified_credential_ref
    assert_not_nil @credential.reload.last_otp_at
    assert_nil @token.reload.last_step_up_at
  end

  test "another actor's credential and another browser session cannot create proof" do
    outsider = Client.create!(status_id: ClientStatus::ACTIVE)
    foreign_credential = ClientTotpCredential.create_for_user!(
      user: outsider, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    assert_not IdentityStepUpTotpVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record,
      code: ROTP::TOTP.new(foreign_credential.private_key).now, credential_public_id: foreign_credential.public_id,
    )
    assert_equal 0, foreign_credential.reload.otp_attempts_count
    @transaction.update!(session_ref: SecureRandom.uuid)
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpTotpVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record,
        code: "000000", credential_public_id: @credential.public_id,
      )
    end
    assert_equal "pending", @transaction.reload.status
    assert_nil @credential.reload.last_otp_at
  end
end
