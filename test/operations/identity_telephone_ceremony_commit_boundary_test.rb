# frozen_string_literal: true

require "test_helper"

class IdentityTelephoneCeremonyCommitBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  teardown do
    if @actor
      ClientContactAuditOutbox.where(operation_ref: @transaction&.transaction_id).delete_all
      ClientTelephoneCeremonyTransaction.where(id: @transaction&.id).delete_all
      ClientTelephone.where(id: @telephone&.id).delete_all
      ClientAuthorityLock.where(client_id: @actor.id).delete_all
      ClientPreference.where(client_id: @actor.id).destroy_all
      Client.where(id: @actor.id).delete_all
    end
  end

  test "a Source commit failure retains Ticket consumption without a Contact or audit" do
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @telephone = ClientTelephone.create!(
      user_id: @actor.id, number: "+819012345681", confirm_policy: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )
    now = ClientTelephoneCeremonyTransaction.database_now
    @transaction = ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: SecureRandom.uuid, operation: "registration",
      telephone_candidate_ref: @telephone.public_id, normalized_number_digest: @telephone.number_digest, now: now,
    )
    result_token = IdentityTelephoneCeremonyResult.issue(
      {
        surface: "app",
        actor_ref: @actor.public_id,
        session_ref: @transaction.session_ref,
        transaction_id: @transaction.transaction_id,
        grant_jti: @transaction.grant_jti,
        result_jti: SecureRandom.uuid,
        operation: @transaction.operation,
        verified_at: now.to_i,
        challenge_id: SecureRandom.uuid,
        expires_at: @transaction.expires_at.to_i,
        telephone_candidate_ref: @telephone.public_id,
        normalized_number_digest: @telephone.number_digest,
      },
      issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id("app"), now: now,
    )
    actor_context = ActorValuesContext.empty.with(
      subject: @actor, actor_type: :client, tld: :app, surface: :base,
    )
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected telephone Source commit failure" }

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      Client.connection_class_for_self.lease_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityTelephoneCeremonyFinalCommitter.call!(
          result_token: result_token, actor_context: actor_context, actor: @actor,
          session_ref: @transaction.session_ref, surface: "app", now: now,
        )
      end
    end

    assert_predicate @transaction.reload, :consumed?
    assert_equal ClientTelephoneStatus::UNVERIFIED, @telephone.reload.user_telephone_status_id
    assert_not @telephone.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(operation_ref: @transaction.transaction_id)
    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyFinalCommitter.call!(
        result_token: result_token, actor_context: actor_context, actor: @actor,
        session_ref: @transaction.session_ref, surface: "app", now: now,
      )
    end
  end
end
