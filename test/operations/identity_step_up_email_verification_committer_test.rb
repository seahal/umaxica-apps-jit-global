# frozen_string_literal: true

require "test_helper"

class IdentityStepUpEmailVerificationCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_emails.create!(
      address: "step-up-verification@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
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
    generation = @record.issue_bound_email_code!(
      transaction: @transaction, credential_ref: @credential.public_id, code: "012345",
    )
    @record.mark_bound_email_delivery!(transaction: @transaction, generation: generation, success: true)
  end

  test "failure persists across replacement codes and success records proof only once" do
    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: "999999",
    )
    assert_equal 1, @credential.reload.step_up_otp_failures
    generation = @record.issue_bound_email_code!(
      transaction: @transaction, credential_ref: @credential.public_id, code: "654321",
    )
    @record.mark_bound_email_delivery!(transaction: @transaction, generation: generation, success: true)

    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: "012345",
    )
    assert_equal 2, @credential.reload.step_up_otp_failures
    assert IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: "654321",
    )
    assert_equal 0, @credential.reload.step_up_otp_failures
    assert_equal "email_otp", @transaction.reload.method
    assert_equal "none", @transaction.aal
    assert_nil @token.reload.last_step_up_at
    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: "654321",
    )
    assert_equal 0, @credential.reload.step_up_otp_failures
  end

  test "fifth consecutive failure locks even the correct code" do
    @credential.update!(step_up_otp_failures: 4)

    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: nil,
    )
    assert_equal 5, @credential.reload.step_up_otp_failures
    assert_operator @credential.step_up_otp_locked_until, :>, ClientStepUpCeremonyTransaction.database_now
    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: @actor, credential: @credential, transaction: @transaction, session_record: @record, code: "012345",
    )
    assert_equal "pending", @transaction.reload.status
    assert_nil @record.reload.email_code_consumed_at
  end
end
