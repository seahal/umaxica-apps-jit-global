# frozen_string_literal: true

require "test_helper"

class ClientSecretRevocationCommitterTest < ActiveSupport::TestCase
  test "a superseded device token cannot authorize Secret revocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    credential = client_secret_credentials(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-superseded-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    device = token.device_session_record!
    token_before = token.reload.attributes
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(ClientSecretRevocationCommitter::Denied) do
      ClientSecretRevocationCommitter.call!(
        actor_context: context, token: token, credential: credential, purge_after: 1.day,
        step_up_evidence: evidence,
      )
    end
    assert_nil credential.reload.revoked_at
    assert_equal token_before, token.reload.attributes
  end

  test "a revoked device cannot authorize Secret revocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    credential = client_secret_credentials(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-device-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    token_before = token.attributes
    token.device_session_record!.revoke!

    assert_raises(ClientSecretRevocationCommitter::Denied) do
      ClientSecretRevocationCommitter.call!(
        actor_context: context, token: token, credential: credential, purge_after: 1.day,
        step_up_evidence: evidence,
      )
    end
    assert_nil credential.reload.revoked_at
    assert_equal token_before, token.reload.attributes
  end

  test "a Step-Up event for a different OP grant is refused before revocation writes" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    credential = client_secret_credentials(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-order-key", public_key: "synthetic-public-key", status_id: ClientPasskeyStatus::ACTIVE,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    invalid_evidence = StepUpEvidenceValue.new(**evidence.to_h.merge(sid: SecureRandom.uuid))
    token_before = token.attributes

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretRevocationCommitter::Denied) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
          step_up_evidence: invalid_evidence,
        )
      end
    end

    assert_nil credential.reload.revoked_at
    assert_equal token_before, token.reload.attributes
  end

  test "owner revokes the final Secret while a Passkey remains and preserves the current session" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
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
          step_up_evidence: evidence,
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
    # Step-Up is reusable evidence and does not mutate the OP access-token row.
    assert_equal original_token, token.reload.attributes
    assert_equal original_digest, credential.password_digest
    events = ClientSecretAuditOutbox.where(
      credential_ref: credential.public_id, event_name: %w(secret.discarded secret.revoked),
    )

    assert_equal %w(secret.discarded secret.revoked), events.order(:event_name).pluck(:event_name)
    assert_equal ["user_revocation"], events.distinct.pluck(:reason)
    assert_equal [actor.public_id], events.distinct.pluck(:actor_public_ref)
    assert_equal 1, events.distinct.count(:operation_ref)
    assert_equal [nil], events.distinct.pluck(:delivered_at)
    first_deadline = credential.purge_eligible_at
    # The same current Step-Up evidence remains valid for a second operation.
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretRevocationCommitter.call!(
        actor_context: context, token: token, credential: credential, purge_after: 2.days,
        step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    actor.client_passkeys.create!(
      webauthn_id: "revocation-persistence-key", public_key: "synthetic-public-key",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 1.day,
      step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    invalid_evidence_values = [
      nil,
      evidence.to_h.merge(jti: SecureRandom.uuid),
      evidence.to_h.merge(sid: SecureRandom.uuid),
      evidence.to_h.merge(sub: "different-subject"),
      evidence.to_h.merge(client_id: "different-client"),
      evidence.to_h.merge(aud: ["different-audience"]),
      evidence.to_h.merge(acr: "urn:example:invalid"),
      evidence.to_h.merge(amr: ["secret"]),
      evidence.to_h.merge(auth_time: now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS - 1),
      evidence.to_h.merge(auth_time: now.to_i + 60),
    ]
    invalid_evidence_values.each do |candidate_values|
      candidate = candidate_values && StepUpEvidenceValue.new(**candidate_values)
      ClientToken.transaction(requires_new: true) do
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretRevocationCommitter::Denied) do
            ClientSecretRevocationCommitter.call!(
              actor_context: context, token: token, credential: credential, purge_after: 1.day,
              step_up_evidence: candidate,
            )
          end
        end
        assert_nil credential.reload.revoked_at
        assert_equal Float::INFINITY, credential.discard_at
        raise ActiveRecord::Rollback
      end
    end

    [
      { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED },
      { discard_at: ClientToken.database_now - 1.second },
    ].each do |session_state|
      ClientToken.transaction(requires_new: true) do
        ClientToken.where(id: token.id).update_all(session_state)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretRevocationCommitter::Denied) do
            ClientSecretRevocationCommitter.call!(
              actor_context: context, token: token, credential: credential, purge_after: 1.day,
              step_up_evidence: evidence,
            )
          end
        end
        assert_nil credential.reload.revoked_at
        raise ActiveRecord::Rollback
      end
    end
  end

  test "another owner's credential cannot be revoked with a valid scoped session" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:two)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretRevocationCommitter::Denied) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
          step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      Client.transaction(requires_new: true) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: credential, purge_after: 1.day,
          step_up_evidence: evidence,
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
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    [-1.second, 0.seconds, nil, 0, "1", [], {}, Float::INFINITY.seconds].each do |duration|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ArgumentError) do
          ClientSecretRevocationCommitter.call!(
            actor_context: context, token: client_tokens(:one), credential: credential, purge_after: duration,
            step_up_evidence: evidence,
          )
        end
      end
      assert_nil credential.reload.revoked_at
    end
  end

  test "last available login method protection is retained even with current Step-Up" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
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
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretRevocationCommitter::Denied) do
        ClientSecretRevocationCommitter.call!(
          actor_context: context, token: token, credential: client_secret_credentials(:one), purge_after: 1.day,
          step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 0.000001.seconds,
      step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    audit_ids = [SecureRandom.uuid, SecureRandom.uuid, "invalid-event-uuid"]

    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { audit_ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretRevocationCommitter.call!(
            actor_context: context, token: token, credential: credential, purge_after: 1.day,
            step_up_evidence: evidence,
          )
        end
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end

  test "anonymous other surface and absent or foreign session bindings cannot authorize revocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
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

    inputs.each do |actor_context, candidate_token, target|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretRevocationCommitter::Denied) do
          ClientSecretRevocationCommitter.call!(
            actor_context: actor_context, token: candidate_token, credential: target, purge_after: 1.day,
            step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
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
              step_up_evidence: evidence,
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
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
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
              step_up_evidence: evidence,
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
