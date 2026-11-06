# frozen_string_literal: true

require "test_helper"

# The Secret claim consumes the source Secret before the Ticket evidence commit, so it must own
# its source commit. These cases therefore run outside the fixture transaction and load only the
# reference and principal fixtures they use.
class ClientSecretClaimCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []
  fixtures :client_statuses, :client_visibilities, :client_security_modes, :client_mfa_statuses,
           :client_token_statuses, :client_token_kinds, :client_token_binding_methods,
           :client_token_dbsc_statuses, :clients, :client_secret_issuances, :client_secret_credentials

  setup do
    @created_client_ids = []
    @created_transactions = []
    @created_ceremonies = []
    @created_flows = []
  end

  teardown do
    # Admission bindings restrict deletion of their authorization transaction, so the
    # transaction row is retained like the other committed-flow cases and only unlinked.
    Array(@created_transactions).each do |transaction|
      transaction.update_columns(secret_sign_in_flow_id: nil) if transaction.persisted?
    end
    Array(@created_client_ids).each do |client_id|
      actor = Client.find_by(id: client_id)
      next unless actor

      ClientChronicle.where(subject_type: "Client", subject_id: client_id.to_s).delete_all
      ClientSecretAuditOutbox.where(client_ref: actor.public_id).delete_all
      ClientSecretCredential.where(client_id: client_id).delete_all
      ClientSecretIssuance.where(client_id: client_id).delete_all
      ClientAccount.where(user_id: client_id).delete_all
      ClientTelephone.where(user_id: client_id).delete_all
      tokens = ClientToken.where(user_id: client_id).select(:id)
      ClientStepUpSession.where(user_token_id: tokens).delete_all
      OpAppGrant.where(client_token_id: tokens).delete_all
      ClientDeviceSession.where(user_id: client_id).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: client_id).delete_all
      ClientDeviceSession.where(user_id: client_id).delete_all
      ClientAuthorityLock.where(client_id: client_id).delete_all
      Client.where(id: client_id).delete_all
    end
    Array(@created_ceremonies).each { |ceremony| ceremony.destroy! if ceremony.persisted? }
    Array(@created_flows).each { |flow| flow.destroy! if flow.persisted? }
  end

  test "OIDC Secret flow binding requires the admitted pending transaction and reuses its server-issued flow" do
    transaction, ceremony = oidc_admission
    unrelated, = ClientAuthCeremonySession.rotate_and_admit!(admission_purpose: "step_up_handoff")
    @created_ceremonies << unrelated
    assert_no_difference("ClientSignInFlow.count") do
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        client: clients(:one), secret: "z" * 32, transaction: transaction,
        ceremony: ceremony,
      )
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        client: clients(:one), secret: "a" * 32, transaction: transaction,
        ceremony: unrelated,
      )
    end
    flow = ClientSecretClaimCommitter.bind_oidc_flow!(
      client: clients(:one), secret: "a" * 32,
      transaction: transaction, ceremony: ceremony,
    )
    @created_flows << flow

    assert_equal clients(:one).id, flow.principal_id
    assert_equal flow.id, transaction.reload.secret_sign_in_flow_id
    assert_operator flow.expires_at, :<=, transaction.login_challenge_expires_at
    assert_operator flow.expires_at, :<=, ceremony.expires_at
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_no_difference("ClientSignInFlow.count") do
      assert_equal flow.id, ClientSecretClaimCommitter.bind_oidc_flow!(
        client: clients(:one), secret: "a" * 32, transaction: transaction, ceremony: ceremony,
      ).id
    end
    assert_equal transaction.transaction_id, ceremony.authorization_transaction_ref
    assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
      client: clients(:one), secret: "b" * 32, transaction: transaction, ceremony: ceremony,
    )
    assert_equal clients(:one).id, transaction.reload.secret_sign_in_flow.principal_id
    transaction.update!(login_challenge_expires_at: ClientOidcAuthorizationTransaction.database_now)
    assert_no_difference("ClientSignInFlow.count") do
      assert_nil ClientSecretClaimCommitter.bind_oidc_flow!(
        client: clients(:one), secret: "a" * 32, transaction: transaction, ceremony: ceremony,
      )
    end
  end

  test "OIDC claim is irreversible and bound to its durable transaction flow and admitted browser" do
    transaction, ceremony = oidc_admission
    claim = ClientSecretClaimCommitter.call_for_oidc!(
      client: clients(:one), secret: "a" * 32,
      transaction: transaction, ceremony: ceremony,
    )
    @created_flows << transaction.reload.secret_sign_in_flow

    assert_equal client_secret_credentials(:one).id, claim.id
    assert_equal transaction.reload.secret_sign_in_flow.public_id, claim.claim_sign_in_flow_ref
    assert_equal ceremony.id, claim.claim_ceremony_session_id
    assert_nil ClientSecretLookupQuery.call(client: clients(:one), secret: "a" * 32)
    assert_nil ClientSecretClaimCommitter.call_for_oidc!(
      client: clients(:one), secret: "a" * 32,
      transaction: transaction, ceremony: ceremony,
    )
    assert_nil claim.reload.consumed_at
    assert_not ceremony.reload.authentication_evidence_recorded?
    assert_equal "pending", transaction.reload.status_name
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
          client: clients(:one), secret: "a" * 32, transaction: transaction, ceremony: ceremony,
        )
      end
    end
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_equal "passkey", transaction.reload.auth_method
    assert_equal clients(:two).public_id, transaction.actor_ref
    assert_equal client_secret_credentials(:one).id,
                 ClientSecretLookupQuery.call(client: clients(:one), secret: "a" * 32).id
  end

  test "a verified value binds one irreversible claim to its admitted browser flow" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 9_113_000_000_000 + SecureRandom.random_number(1_000_000_000),
      status_id: ClientStatus::ACTIVE,
    )
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    ClientSecretPresentationIssuer.prepare!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )
    raw = ClientSecretPresentationIssuer.call!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    ).first
    ClientSecretStorageConfirmationCommitter.call!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )
    telephone = ClientTelephone.create!(
      user: actor,
      number: "+8190#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    admission = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    _auth_session, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission.reference, surface: "app", expected_intent: "sign_in",
      binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      authorization_transaction_ref: admission.transaction.transaction_id,
    )
    transaction = admission.transaction
    @created_transactions << transaction
    @created_ceremonies << ceremony

    assert_nil ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: "1" * 32, transaction:, ceremony:)
    credential = ClientSecretLookupQuery.call(client: actor, secret: raw)

    assert_equal [:telephone], AuthenticationCredentialInventory.call(actor).contact_identifiers
    assert_not AuthMethodGuard.can_remove_secret_credential?(actor, credential)
    assert_nil credential.reload.claimed_at
    claim = ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: raw, transaction:, ceremony:)

    assert_equal credential.id, claim.id
    flow = transaction.reload.secret_sign_in_flow
    @created_flows << flow

    assert_equal flow.public_id, claim.claim_sign_in_flow_ref
    assert_equal ceremony.id, claim.claim_ceremony_session_id
    assert_equal actor.id, flow.reload.principal_id
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_nil ClientSecretClaimCommitter.call_for_oidc!(client: actor, secret: raw, transaction:, ceremony:)
    assert_raises(ActiveRecord::ReadonlyAttributeError) { claim.update!(claimed_at: nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { claim.update!(claim_operation_id: SecureRandom.uuid) }
    assert_nil claim.reload.consumed_at
    assert_equal 1, ClientSecretAuditOutbox.where(credential_ref: claim.public_id, event_name: "secret.claimed").count
    assert_equal actor.id, telephone.reload.user_id
  end

  private

  def oidc_admission
    now = ClientOidcAuthorizationTransaction.database_now
    transaction = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "authentication", client_id: "secret-binding-test",
      redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
      state: SecureRandom.hex(16), nonce: SecureRandom.hex(16),
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256", login_challenge: SecureRandom.uuid,
      login_challenge_expires_at: now + 10.minutes, expires_at: now + 15.minutes, now: now,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: transaction.transaction_id,
    )
    @created_transactions << transaction
    @created_ceremonies << ceremony
    [transaction, ceremony]
  end
end
