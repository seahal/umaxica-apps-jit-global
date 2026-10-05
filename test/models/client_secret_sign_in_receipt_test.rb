# frozen_string_literal: true

require "test_helper"

class ClientSecretSignInReceiptTest < ActiveSupport::TestCase
  test "receipt rejects a pending flow instead of recording a failed attempt" do
    now = Client.database_now
    flow = ClientSignInFlow.create!(
      principal: clients(:one), nonce_digest: "a" * 64,
      issued_at: now, expires_at: now + 1.minute,
      status_id: ClientSignInFlowStatus::PRIMARY_PENDING, state: "PRIMARY_PENDING", step: "primary",
    )

    assert_raises(ClientSecretSignInReceipt::InvalidCommit) do
      ClientSecretSignInReceipt.create!(
        operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1",
        client_ref: clients(:one).public_id, sign_in_flow: flow,
        root_token_ref: client_tokens(:one).public_id, committed_at: now,
      )
    end
  end

  test "receipt persists only matching successful root login facts and cannot change identity" do
    now = Client.database_now
    owner = clients(:one)
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal: owner, token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      status_id: ClientSignInFlowStatus::COMPLETED, state: "COMPLETED", step: "completed",
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )
    receipt = ClientSecretSignInReceipt.create!(
      operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1",
      client_ref: owner.public_id, sign_in_flow: flow,
      root_token_ref: token.public_id, committed_at: now,
    )

    assert_equal flow.id, receipt.reload.sign_in_flow_id
    assert_equal token.public_id, receipt.root_token_ref
    assert_raises(ActiveRecord::ReadonlyAttributeError) { receipt.update!(client_ref: clients(:two).public_id) }
  end

  test "receipt rejects a different actor even when flow and token have completed" do
    now = Client.database_now
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal: clients(:one), token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      status_id: ClientSignInFlowStatus::COMPLETED, state: "COMPLETED", step: "completed",
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )

    assert_raises(ClientSecretSignInReceipt::InvalidCommit) do
      ClientSecretSignInReceipt.create!(
        operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1",
        client_ref: clients(:two).public_id, sign_in_flow: flow,
        root_token_ref: token.public_id, committed_at: now,
      )
    end
  end

  test "receipt rejects adjacent commit times other methods and restricted context" do
    now = Client.database_now
    owner = clients(:one)
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal: owner, token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      status_id: ClientSignInFlowStatus::COMPLETED, state: "COMPLETED", step: "completed",
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )

    [now - Rational(1, 1_000_000), now + Rational(1, 1_000_000)].each do |timestamp|
      assert_raises(ClientSecretSignInReceipt::InvalidCommit) do
        ClientSecretSignInReceipt.create!(
          operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1",
          client_ref: owner.public_id, sign_in_flow: flow,
          root_token_ref: token.public_id, committed_at: timestamp,
        )
      end
    end
    [["passkey", "normal"], ["secret", "emergency"]].each do |method, context|
      flow.update!(authentication_method: method, authentication_context: context)
      assert_raises(ClientSecretSignInReceipt::InvalidCommit) do
        ClientSecretSignInReceipt.create!(
          operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1",
          client_ref: owner.public_id, sign_in_flow: flow,
          root_token_ref: token.public_id, committed_at: now,
        )
      end
    end
  end
end
