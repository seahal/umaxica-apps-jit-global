# frozen_string_literal: true

require "test_helper"

class IdentityStepUpTotpVerificationCommitterTest < ActiveSupport::TestCase
  fixtures :client_statuses

  setup do
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @credential = ClientTotpCredential.create_for_user!(
      user: @actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor)
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

  [false, true].each do |superseded|
    test "a #{superseded ? "superseded" : "revoked"} device cannot verify TOTP Step-Up" do
      device = @token.device_session_record!
      if superseded
        replacement = ClientToken.create!(authentication_epoch: 0, user: @actor, device_session: device)
        device.update!(current_refresh_token_id: replacement.id)
      else
        device.revoke!
      end
      now = ClientTotpCredential.database_now
      code = ROTP::TOTP.new(@credential.private_key).at(now.to_i)

      ClientTotpCredential.stub(:database_now, now) do
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpTotpVerificationCommitter.call!(
            actor: @actor, transaction: @transaction, session_record: @record,
            code: code, credential_public_id: @credential.public_id,
          )
        end
      end
      assert_equal "pending", @transaction.reload.status
      assert_nil @credential.reload.last_otp_at
      assert_equal 0, @credential.otp_attempts_count
    end
  end

  %i(owner credential).each do |stopped|
    test "#{stopped} stopped during TOTP verification cannot create evidence" do
      now = ClientTotpCredential.database_now
      code = ROTP::TOTP.new(@credential.private_key).at(now.to_i)
      consumer = TotpWindowConsumer.method(:call)
      verify_then_stop =
        lambda do |**arguments|
          result = consumer.call(**arguments)
          if stopped == :owner
            @actor.update!(status_id: ClientStatus::RESERVED)
          else
            @credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)
          end
          result
        end

      ClientTotpCredential.stub(:database_now, now) do
        TotpWindowConsumer.stub(:call, verify_then_stop) do
          assert_raises(IdentityStepUpCeremonyContract::Error) do
            IdentityStepUpTotpVerificationCommitter.call!(
              actor: @actor, transaction: @transaction, session_record: @record,
              code: code, credential_public_id: @credential.public_id,
            )
          end
        end
      end

      assert_equal "pending", @transaction.reload.status
      assert_not_nil @credential.reload.last_otp_at
      assert_nil @token.reload.last_step_up_at
    end
  end

  test "device revocation during TOTP verification prevents recording evidence" do
    now = ClientTotpCredential.database_now
    code = ROTP::TOTP.new(@credential.private_key).at(now.to_i)
    consumer = TotpWindowConsumer.method(:call)
    verify_then_revoke =
      lambda do |**kwargs|
        result = consumer.call(**kwargs)
        @token.device_session_record!.revoke!
        result
      end

    ClientTotpCredential.stub(:database_now, now) do
      TotpWindowConsumer.stub(:call, verify_then_revoke) do
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpTotpVerificationCommitter.call!(
            actor: @actor, transaction: @transaction, session_record: @record,
            code: code, credential_public_id: @credential.public_id,
          )
        end
      end
    end

    assert_equal "pending", @transaction.reload.status
    assert_not_nil @credential.reload.last_otp_at
    assert_nil @token.reload.last_step_up_at
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
    outsider = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
