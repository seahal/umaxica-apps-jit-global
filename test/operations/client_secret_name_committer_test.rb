# frozen_string_literal: true

require "test_helper"

class ClientSecretNameCommitterTest < ActiveSupport::TestCase
  test "session revocation restriction and expiry are reread instead of trusting the supplied token" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    states = [
      { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED },
      { discard_at: ClientToken.database_now - 1.second },
    ]
    states.each do |state|
      ClientToken.transaction(requires_new: true) do
        ClientToken.where(id: token.id).update_all(state)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretNameCommitter::Denied) do
            ClientSecretNameCommitter.call!(
              actor_context: context, token: token, credential: credential, name: "Rejected",
            )
          end
        end
        assert_equal "Fixture Secret 1", credential.reload.name
        raise ActiveRecord::Rollback
      end
    end
  end

  test "claimed revoked discarded and unconfirmed credentials cannot be renamed or revived" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    now = Client.database_now
    states = [
      { claimed_at: now, claim_operation_id: SecureRandom.uuid },
      { revoked_at: now },
      { discard_at: now },
      { confirmed_at: nil },
    ]
    states.each do |state|
      ClientSecretCredential.transaction(requires_new: true) do
        # Persist lifecycle facts to exercise the public operation against actual DB rows.
        ClientSecretCredential.where(id: credential.id).update_all(state)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretNameCommitter::Denied) do
            ClientSecretNameCommitter.call!(
              actor_context: context, token: token, credential: credential, name: "Rejected",
            )
          end
        end
        assert_equal "Fixture Secret 1", credential.reload.name
        state.each do |column, value|
          if value.nil?
            assert_nil credential[column]
          else
            assert_equal value, credential[column]
          end
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "source rollback discards both the name change and its outbox event" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      Client.transaction(requires_new: true) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token: token, credential: credential, name: "Rolled back",
        )

        assert_equal "Rolled back", credential.reload.name
        assert_equal 1, ClientSecretAuditOutbox.where(
          event_name: "secret.renamed", credential_ref: credential.public_id,
        ).count
        raise ActiveRecord::Rollback
      end
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "name boundaries 254 and 255 succeed while 256 and input sentinels leave no mutation" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: Client.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    [254, 255].each do |length|
      assert_difference("ClientSecretAuditOutbox.count", 1) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token: token, credential: credential, name: "n" * length,
        )
      end
      assert_equal length, credential.reload.name.length
    end

    ["n" * 256, nil, "", " ", 0, [], {}, "n\0", "\xFF".b.force_encoding("UTF-8")].each do |name|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::InvalidName) do
          ClientSecretNameCommitter.call!(actor_context: context, token: token, credential: credential, name: name)
        end
      end
      assert_equal "n" * 255, credential.reload.name
    end
  end

  test "wrong scope method session purpose audience and expired freshness refuse rename" do
    actor = clients(:one)
    token = client_tokens(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    mismatches = [
      { last_step_up_scope: "settings_passkey" },
      { last_step_up_method: "secret" },
      { last_step_up_session_public_id: client_tokens(:two).public_id },
      { last_step_up_purpose: "bootstrap" },
      { last_step_up_audience: "step_up:com" },
      { last_step_up_at: ClientToken.database_now - StepUpRequirement::DEFAULT_TTL - 1.second },
      { last_step_up_at: ClientToken.database_now + 1.minute },
    ]
    mismatches.each do |mismatch|
      token.update!(
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
        assert_raises(ClientSecretNameCommitter::Denied) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token: token, credential: credential, name: "Rejected",
          )
        end
      end
      assert_equal "Fixture Secret 1", credential.reload.name
    end
  end

  test "owner with current scoped Step-Up renames only metadata and commits one source event" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = Client.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_secret_credential", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    credential = client_secret_credentials(:one)
    original_digest = credential.password_digest
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    ClientSecretNameCommitter.call!(
      actor_context: context, token: token, credential: credential,
      name: "Personal label",
    )

    assert_equal "Personal label", credential.reload.name
    assert_equal original_digest, credential.password_digest
    assert_nil credential.claimed_at
    event = ClientSecretAuditOutbox.find_by!(event_name: "secret.renamed", credential_ref: credential.public_id)

    assert_equal actor.public_id, event.actor_public_ref
    assert_equal actor.public_id, event.client_ref
    assert_nil event.reason
    assert_nil event.delivered_at
  end

  test "missing Step-Up cannot rename and creates no source event" do
    actor = clients(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretNameCommitter::Denied) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token: client_tokens(:one), credential: credential, name: "Rejected",
        )
      end
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "another owner's credential is refused even with a valid scoped session" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: Client.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:two)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretNameCommitter::Denied) do
        ClientSecretNameCommitter.call!(actor_context: context, token: token, credential: credential, name: "Rejected")
      end
    end
    assert_equal "Fixture Secret 2", credential.reload.name
  end
end
