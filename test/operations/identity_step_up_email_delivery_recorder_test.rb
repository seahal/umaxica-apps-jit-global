# frozen_string_literal: true

require "test_helper"

class IdentityStepUpEmailDeliveryRecorderTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_emails.create!(
      address: "step-up-recorder@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
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
    @generation = @record.issue_bound_email_code!(
      transaction: @transaction, credential_ref: @credential.public_id, code: "012345",
    )
    @ciphertext = OutboundSensitivePayload.encrypt_email_otp("012345")
  end

  test "stale generation and canceled transaction never reach the mailer" do
    @record.issue_bound_email_code!(transaction: @transaction, credential_ref: @credential.public_id, code: "654321")

    assert_not IdentityStepUpEmailDeliveryRecorder.call!(
      credential: @credential, transaction_ref: @transaction.transaction_id,
      generation: @generation, encrypted_code: @ciphertext,
    )
    @transaction.update!(status: "canceled", canceled_at: ClientStepUpCeremonyTransaction.database_now)

    assert_not IdentityStepUpEmailDeliveryRecorder.call!(
      credential: @credential, transaction_ref: @transaction.transaction_id,
      generation: @record.reload.email_code_generation,
      encrypted_code: OutboundSensitivePayload.encrypt_email_otp("654321"),
    )
    assert_equal "pending", @record.reload.email_delivery_state
    assert_nil @record.email_code_consumed_at
  end

  test "a recipient from another actor cannot use the delivery reference" do
    outsider = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = outsider.client_emails.create!(
      address: "other-step-up@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_not IdentityStepUpEmailDeliveryRecorder.call!(
      credential: credential, transaction_ref: @transaction.transaction_id,
      generation: @generation, encrypted_code: @ciphertext,
    )
    assert_equal "pending", @record.reload.email_delivery_state
  end
end
