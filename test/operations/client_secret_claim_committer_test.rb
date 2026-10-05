# frozen_string_literal: true

require "test_helper"

class ClientSecretClaimCommitterTest < ActiveSupport::TestCase
  test "OIDC Secret flow binding requires the admitted pending transaction and reuses its server-issued flow" do
    transaction, ceremony = oidc_admission
    unrelated, = ClientAuthCeremonySession.rotate_and_admit!(admission_purpose: "local_sign_in")
    assert_no_difference("ClientSignInFlow.count") do
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        secret: "z" * 32, transaction: transaction,
        ceremony: ceremony,
      )
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        secret: "a" * 32, transaction: transaction,
        ceremony: unrelated,
      )
    end
    flow = ClientSecretClaimCommitter.bind_oidc_flow!(secret: "a" * 32, transaction: transaction, ceremony: ceremony)

    assert_equal clients(:one).id, flow.principal_id
    assert_equal flow.id, transaction.reload.secret_sign_in_flow_id
    assert_operator flow.expires_at, :<=, transaction.login_challenge_expires_at
    assert_operator flow.expires_at, :<=, ceremony.expires_at
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_no_difference("ClientSignInFlow.count") do
      assert_equal flow.id, ClientSecretClaimCommitter.bind_oidc_flow!(
        secret: "a" * 32, transaction: transaction, ceremony: ceremony,
      ).id
    end
    assert_nil ceremony.reload.local_sign_in_flow_ref
    assert_equal transaction.transaction_id, ceremony.authorization_transaction_ref
    assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
      secret: "b" * 32, transaction: transaction, ceremony: ceremony,
    )
    assert_equal clients(:one).id, transaction.reload.secret_sign_in_flow.principal_id
    transaction.update!(login_challenge_expires_at: ClientOidcAuthorizationTransaction.database_now)
    assert_no_difference("ClientSignInFlow.count") do
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        secret: "a" * 32, transaction: transaction, ceremony: ceremony,
      )
    end
  end

  test "OIDC claim is irreversible and bound to its durable transaction flow and admitted browser" do
    transaction, ceremony = oidc_admission
    claim = ClientSecretClaimCommitter.call_for_oidc!(secret: "a" * 32, transaction: transaction, ceremony: ceremony)

    assert_equal client_secret_credentials(:one).id, claim.id
    assert_equal transaction.reload.secret_sign_in_flow.public_id, claim.claim_sign_in_flow_ref
    assert_equal ceremony.id, claim.claim_ceremony_session_id
    assert_nil ClientSecretLookupQuery.call(secret: "a" * 32)
    assert_nil ClientSecretClaimCommitter.call_for_oidc!(secret: "a" * 32, transaction: transaction, ceremony: ceremony)
    assert_nil claim.reload.consumed_at
    assert_not ceremony.reload.authentication_evidence_recorded?
    assert_equal "pending", transaction.reload.status
  end

  test "already authenticated OIDC transaction cannot claim or replace evidence with a Secret" do
    transaction, ceremony = oidc_admission
    now = ClientOidcAuthorizationTransaction.database_now
    transaction.register_authentication!(
      actor_ref: clients(:two).public_id, session_ref: nil, auth_method: "passkey",
      acr: "aal1", authentication_event_at: now,
    )
    assert_no_difference("ClientSignInFlow.count") do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_nil ClientSecretClaimCommitter.call_for_oidc!(
          secret: "a" * 32, transaction: transaction, ceremony: ceremony,
        )
      end
    end
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_equal "passkey", transaction.reload.auth_method
    assert_equal clients(:two).public_id, transaction.actor_ref
    assert_equal client_secret_credentials(:one).id, ClientSecretLookupQuery.call(secret: "a" * 32).id
  end

  test "a verified value binds one irreversible claim to its admitted browser flow" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
    raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance).first
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission.reference, surface: "app",
      expected_intent: "sign_in",
    )
    flow = ClientSignInFlow.find_by!(public_id: payload.fetch("subject_ref"))
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "local_sign_in",
      local_sign_in_flow_ref: flow.public_id,
    )

    assert_nil ClientSecretClaimCommitter.call!(secret: "1" * 32, flow: flow, ceremony: ceremony)
    credential = ClientSecretLookupQuery.call(secret: raw)

    assert_nil credential.reload.claimed_at
    claim = ClientSecretClaimCommitter.call!(secret: raw, flow: flow, ceremony: ceremony)

    assert_equal credential.id, claim.id
    assert_equal flow.public_id, claim.claim_sign_in_flow_ref
    assert_equal ceremony.id, claim.claim_ceremony_session_id
    assert_equal actor.id, flow.reload.principal_id
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    assert_nil ClientSecretClaimCommitter.call!(secret: raw, flow: flow, ceremony: ceremony)
    assert_raises(ActiveRecord::ReadonlyAttributeError) { claim.update!(claimed_at: nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { claim.update!(claim_operation_id: SecureRandom.uuid) }
    assert_nil claim.reload.consumed_at
    assert_equal 1, ClientSecretAuditOutbox.where(credential_ref: claim.public_id, event_name: "secret.claimed").count
  end

  private

  def oidc_admission
    now = ClientOidcAuthorizationTransaction.database_now
    transaction = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "authentication", client_id: "secret-binding-test",
      redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
      state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
      code_challenge_method: "S256", login_challenge: SecureRandom.uuid,
      login_challenge_expires_at: now + 10.minutes, expires_at: now + 15.minutes, now: now,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: transaction.transaction_id,
    )
    [transaction, ceremony]
  end
end
