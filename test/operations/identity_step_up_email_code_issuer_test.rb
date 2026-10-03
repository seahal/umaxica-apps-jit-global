# frozen_string_literal: true

require "test_helper"

class IdentityStepUpEmailCodeIssuerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_emails.create!(
      address: "step-up-issuer@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @token = ClientToken.create!(user: @actor)
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: @token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    @record = ClientStepUpSession.create!(
      user_token: @token, step_up_ceremony_transaction_ref: @transaction.transaction_id,
      scope: @transaction.required_scope, return_to: @transaction.return_to,
      status: "PENDING", discard_at: @transaction.expires_at,
    )
    clear_enqueued_jobs
  end

  test "issuing queues only encrypted code and immediate resend preserves failures and generation" do
    @credential.update!(step_up_otp_failures: 3)
    assert_enqueued_jobs 1, only: StepUpEmailDeliveryJob do
      assert_equal 1, IdentityStepUpEmailCodeIssuer.call!(
        actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
      )
    end
    assert_equal "pending", @record.reload.email_delivery_state
    assert_equal 3, @credential.reload.step_up_otp_failures
    assert_raises(IdentityStepUpEmailCodeIssuer::Unavailable) do
      IdentityStepUpEmailCodeIssuer.call!(
        actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
      )
    end
    assert_equal 1, @record.reload.email_code_generation
    assert_equal 3, @credential.reload.step_up_otp_failures
  end

  test "unverified credential and another session cannot enqueue proof" do
    @credential.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    assert_raises(IdentityStepUpEmailCodeIssuer::Unavailable) do
      IdentityStepUpEmailCodeIssuer.call!(
        actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
      )
    end
    @credential.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
    @transaction.update!(session_ref: SecureRandom.uuid)
    assert_raises(IdentityStepUpEmailCodeIssuer::Unavailable) do
      IdentityStepUpEmailCodeIssuer.call!(
        actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
      )
    end
    assert_equal 0, @record.reload.email_code_generation
    assert_enqueued_jobs 0
  end

  test "resend rejects one microsecond before sixty seconds and allows the boundary and after" do
    now = ClientStepUpCeremonyTransaction.database_now
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      @credential.update!(step_up_otp_last_issued_at: now - 60.seconds - offset)
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        if offset.negative?
          assert_raises(IdentityStepUpEmailCodeIssuer::Unavailable) do
            IdentityStepUpEmailCodeIssuer.call!(
              actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
            )
          end
        else
          assert_equal offset.zero? ? 1 : 2, IdentityStepUpEmailCodeIssuer.call!(
            actor: @actor, credential: @credential, transaction: @transaction, session_record: @record,
          )
        end
      end
    end

    assert_equal 2, @record.reload.email_code_generation
  end
end
