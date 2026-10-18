# frozen_string_literal: true

require "test_helper"

class ClientSecretRevocationCommitterTest < ActiveSupport::TestCase
  setup do
    client_tokens(:one).update!(
      last_step_up_at: ClientToken.database_now,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: client_tokens(:one).public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )
  end

  test "scoped owner revokes the final Secret while a Passkey remains and preserves the current session" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      established_authentication_method: "secret",
    )
    actor.client_passkeys.create!(
      webauthn_id: "revocation-owner-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    original_token = token.attributes
    original_digest = credential.password_digest
    before = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count

    assert_no_difference("ClientSecretIssuance.count") do
      assert_difference("ClientSecretAuditOutbox.count", 2) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
        )
      end
    end
    credential.reload

    assert_not_nil credential.revoked_at
    assert_equal credential.revoked_at, credential.discard_at
    assert_equal 1.day, credential.purge_eligible_at - credential.discard_at
    assert_not credential.available_at?(at: Client.database_now)
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: "a" * 32)
    assert_equal before - 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
    assert_equal original_token, token.reload.attributes
    assert_equal original_digest, credential.password_digest
    events = ClientSecretAuditOutbox.where(credential_ref: credential.public_id)

    assert_equal %w(secret.discarded secret.revoked), events.order(:event_name).pluck(:event_name)
    assert_equal ["user_revocation"], events.distinct.pluck(:reason)
    assert_equal [actor.public_id], events.distinct.pluck(:actor_public_ref)
    assert_equal 1, events.distinct.count(:operation_ref)
    assert_equal [nil], events.distinct.pluck(:delivered_at)
    first_deadline = credential.purge_eligible_at
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretRevocationCommitter.call!(
        actor_context: context, token: token, credential: credential, purge_after: 2.days,
      )
    end
    assert_equal first_deadline, credential.reload.purge_eligible_at

    terminal_at = credential.revoked_at
    [nil, terminal_at - Rational(1, 1_000_000), terminal_at + Rational(1, 1_000_000)].each do |replacement|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ActiveRecord::ReadonlyAttributeError, "terminal timestamp replacement #{replacement.inspect}") do
          credential.reload[:revoked_at] = replacement
        end
      end
      assert_equal terminal_at, credential.reload.revoked_at
      assert_not credential.available_at?(at: ClientSecretCredential.database_now)
    end
  end

  test "generic persistence cannot clear or replace a committed revocation fact at adjacent microseconds" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    actor.client_passkeys.create!(
      webauthn_id: "revocation-persistence-key", public_key: "synthetic-public-key",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 1.day,
    )
    terminal_at = credential.reload.revoked_at
    [nil, terminal_at - Rational(1, 1_000_000), terminal_at, terminal_at + Rational(1, 1_000_000)].each do |replacement|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ActiveRecord::ReadonlyAttributeError) do
          credential.reload.update_columns(revoked_at: replacement)
        end
        assert_raises(ActiveRecord::ReadonlyAttributeError) do
          credential.reload.update_column(:revoked_at, replacement)
        end
        assert_raises(ActiveRecord::ReadonlyAttributeError) do
          credential.reload.write_attribute(:revoked_at, replacement)
        end
        assert_raises(ActiveRecord::ReadonlyAttributeError) do
          credential.reload[:revoked_at] = replacement
        end
      end
      assert_equal terminal_at, credential.reload.revoked_at
      assert_not credential.available_at?(at: ClientSecretCredential.database_now)
    end
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.touch(:revoked_at) }
    assert_equal terminal_at, credential.reload.revoked_at
  end

  test "missing and mismatched Step-Up or a stale supplied session leave credential and audit unchanged" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    mismatches = [
      { last_step_up_at: nil }, { last_step_up_scope: "settings_passkey" },
      { last_step_up_method: "secret" }, { last_step_up_session_public_id: client_tokens(:two).public_id },
      { last_step_up_purpose: "bootstrap" }, { last_step_up_audience: "step_up:com" },
      { last_step_up_at: ClientToken.database_now - StepUpRequirement::DEFAULT_TTL - 1.second },
      { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED },
      { discard_at: ClientToken.database_now - 1.second },
    ]
    mismatches.each do |mismatch|
      ClientToken.transaction(requires_new: true) do
        ClientToken.where(id: token.id).update_all(
          {
            last_step_up_at: ClientToken.database_now,
            last_step_up_scope: "settings_secret_credential",
            last_step_up_method: "passkey",
            last_step_up_session_public_id: token.public_id,
            last_step_up_purpose: "step_up",
            last_step_up_audience: "step_up:app",
          }.merge(mismatch),
        )
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretRevocationCommitter::Denied) do
            ClientSecretRevocationCommitter.call!(
              actor_context: context, token: token, credential: credential, purge_after: 1.day,
            )
          end
        end
        assert_nil credential.reload.revoked_at
        assert_equal Float::INFINITY, credential.discard_at
        raise ActiveRecord::Rollback
      end
    end
  end

  test "another owner's credential cannot be revoked with a valid scoped session" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:two)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretRevocationCommitter::Denied) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
        )
      end
    end
    assert_nil credential.reload.revoked_at
  end

  test "source rollback restores both lifecycle facts and source audit" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-rollback-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      Client.transaction(requires_new: true) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
        )

        assert_not_nil credential.reload.revoked_at
        raise ActiveRecord::Rollback
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
    assert_equal Float::INFINITY, credential.purge_eligible_at
  end

  test "nonpositive retention boundary and type sentinels are refused before mutation" do
    actor = clients(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    [-1.second, 0.seconds, nil, 0, "1", [], {}, Float::INFINITY.seconds].each do |duration|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ArgumentError) do
          ClientSecretRevocationCommitter.call!(
            actor_context: context, token: client_tokens(:one), credential: credential, purge_after: duration,
          )
        end
      end
      assert_nil credential.reload.revoked_at
    end
  end

  test "last available login method protection is retained even with current Step-Up" do
    actor = clients(:one)
    token = client_tokens(:one)
    actor.client_external_identities.delete_all
    actor.client_emails.delete_all
    actor.client_passkeys.delete_all
    actor.client_totp_credentials.delete_all
    ClientTelephone.where(user: actor).delete_all
    ClientTelephone.create!(
      user: actor,
      number: "+8190#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretRevocationCommitter::Denied) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: client_secret_credentials(:one), purge_after: 1.day,
        )
      end
    end
  end

  test "smallest DB timestamp increment above zero is a valid explicit retention boundary" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-retention-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 0.000001.seconds,
    )
    credential.reload

    assert_in_delta 0.000001, credential.purge_eligible_at - credential.discard_at, 0.00000001
  end

  test "source audit persistence failure rolls back the irreversible credential transition" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-audit-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    audit_ids = [SecureRandom.uuid, SecureRandom.uuid, "invalid-event-uuid"]

    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { audit_ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretRevocationCommitter.call!(
            actor_context: context, token: token, credential: credential, purge_after: 1.day,
          )
        end
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end

  test "anonymous other surface and absent or foreign session bindings cannot authorize revocation" do
    actor = clients(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    inputs = [
      [nil, client_tokens(:one), credential],
      [ActorValuesContext.empty, client_tokens(:one), credential],
      [context.with(surface: :sign), client_tokens(:one), credential],
      [context.with(tld: :com), client_tokens(:one), credential],
      [context, nil, credential], [context, client_tokens(:two), credential],
      [context, client_tokens(:one), nil],
      [context, client_tokens(:one), ClientSecretCredential.new],
    ]

    inputs.each do |actor_context, token, target|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretRevocationCommitter::Denied) do
          ClientSecretRevocationCommitter.call!(
            actor_context: actor_context, token: token, credential: target, purge_after: 1.day,
          )
        end
      end
    end
    assert_nil credential.reload.revoked_at
  end

  test "pending claimed and discarded credentials cannot be reclassified through management deletion" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-terminal-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    now = Client.database_now
    [{ confirmed_at: nil }, { claimed_at: now,
                              claim_operation_id: SecureRandom.uuid,
                              claim_sign_in_flow_ref: "claimed-test-flow",
                              claim_ceremony_session_id: 1, },
     { discard_at: now }, { revoked_at: now },].each do |state|
      Client.transaction(requires_new: true) do
        ClientSecretCredential.where(id: credential.id).update_all(state)
        before = credential.reload.attributes
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretRevocationCommitter::Denied) do
            ClientSecretRevocationCommitter.call!(
              actor_context: context, token: token, credential: credential, purge_after: 1.day,
            )
          end
        end
        assert_equal before, credential.reload.attributes
        raise ActiveRecord::Rollback
      end
    end
  end

  test "invalid persisted credential metadata stops retirement before lifecycle and source audit commit" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-validation-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    [{ name: "" }, { password_digest: "" }].each do |invalid|
      Client.transaction(requires_new: true) do
        ClientSecretCredential.where(id: credential.id).update_all(invalid)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ActiveRecord::RecordInvalid) do
            ClientSecretRevocationCommitter.call!(
              actor_context: context, token: token, credential: credential, purge_after: 1.day,
            )
          end
        end
        assert_nil credential.reload.revoked_at
        assert_equal Float::INFINITY, credential.discard_at
        raise ActiveRecord::Rollback
      end
    end
  end
end
