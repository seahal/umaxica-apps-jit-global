# frozen_string_literal: true

require "test_helper"

class StepUpEmailChallengeTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @token = ClientToken.create!(user: @actor)
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: @token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    @record = ClientStepUpSession.create!(
      user_token: @token, step_up_ceremony_transaction_ref: @transaction.transaction_id,
      scope: @transaction.required_scope, return_to: @transaction.return_to,
      status: "PENDING", discard_at: @transaction.expires_at, attempt_count: 3,
    )
  end

  test "a replacement code rejects the previous generation and preserves the transaction deadline and attempts" do
    deadline = @record.discard_at
    first = @record.issue_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "012345")
    second = @record.issue_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "654321")

    assert_not @record.mark_bound_email_delivery!(transaction: @transaction, generation: first, success: true)
    assert @record.mark_bound_email_delivery!(transaction: @transaction, generation: second, success: true)
    [nil, "", 0, "0", "\0", {}, "012345"].each do |invalid|
      assert_not @record.consume_bound_email_code!(transaction: @transaction, credential_ref: "email", code: invalid)
    end
    assert_equal deadline, @record.reload.discard_at
    assert_equal 3, @record.attempt_count
    assert @record.consume_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "654321")
    assert_equal "verified", @transaction.reload.status
    assert_equal "email", @transaction.verified_credential_ref
    assert_equal "none", @transaction.aal
    assert_nil @token.reload.last_step_up_at
    assert_not @record.consume_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "654321")
  end

  test "pending and failed delivery cannot authenticate" do
    generation = @record.issue_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "000000")

    assert_not @record.consume_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "000000")
    assert @record.mark_bound_email_delivery!(transaction: @transaction, generation: generation, success: false)
    assert_not @record.consume_bound_email_code!(transaction: @transaction, credential_ref: "email", code: "000000")
    assert_equal "pending", @transaction.reload.status
  end
end
