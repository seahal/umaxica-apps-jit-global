# frozen_string_literal: true

require "test_helper"

class ClientSecretPresentationIssuerTest < ActiveSupport::TestCase
  test "manual presentation generates exactly the reserved set once and storage declaration activates it" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    assert_difference("ClientSecretCredential.count", 1) do
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      values = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)

      assert_equal 1, values.length
      assert_match ClientSecretCredential::SECRET_FORMAT, values.first
      assert_nil ClientSecretLookupQuery.call(secret: values.first)
      assert_nil issuance.reload.encrypted_payload
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::AlreadyPresented) do
          ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)
        end
      end
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)

      assert_equal issuance.id, ClientSecretLookupQuery.call(secret: values.first).issuance_id
    end
  end

  test "missing and corrupt payloads cannot replace candidates or activate an unpresented set" do
    [nil, "invalid encrypted payload"].each do |payload|
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
      candidate_ids = ClientSecretCredential.where(issuance_id: issuance.id).pluck(:public_id)
      issuance.reload.update!(encrypted_payload: payload)

      assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
        assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
          ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)
        end
        if payload.nil?
          assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
            ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
          end
        end
        assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
          ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
        end
      end
      assert_nil issuance.reload.presented_at
      assert_nil issuance.confirmed_at
      assert_equal candidate_ids, ClientSecretCredential.where(issuance_id: issuance.id).pluck(:public_id)

      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
      )

      assert_not_nil issuance.reload.canceled_at
      assert_nil issuance.encrypted_payload
      candidate = ClientSecretCredential.find_by!(public_id: candidate_ids.fetch(0))

      assert_nil candidate.confirmed_at
      assert_not_nil candidate.discard_at
      replacement = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )

      assert_not_equal issuance.id, replacement.id
      assert_equal 1, replacement.planned_count
    end
  end

  test "another issuance's authentic payload cannot present or confirm the target candidates" do
    operations =
      Array.new(2) do
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
        { context: context, token: token, issuance: issuance.reload }
      end
    source, target = operations
    target_issuance = target.fetch(:issuance)
    candidate_ids = ClientSecretCredential.where(issuance_id: target_issuance.id).pluck(:public_id)
    target_issuance.update!(encrypted_payload: source.fetch(:issuance).encrypted_payload)

    assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
        ClientSecretPresentationIssuer.call!(
          actor_context: target.fetch(:context), token: target.fetch(:token), issuance: target_issuance,
        )
      end
      assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
        ClientSecretStorageConfirmationCommitter.call!(
          actor_context: target.fetch(:context), token: target.fetch(:token), issuance: target_issuance,
        )
      end
    end
    assert_nil target_issuance.reload.presented_at
    assert_nil target_issuance.confirmed_at
    assert_equal candidate_ids, ClientSecretCredential.where(issuance_id: target_issuance.id).pluck(:public_id)
    values = ClientSecretPresentationIssuer.call!(
      actor_context: source.fetch(:context), token: source.fetch(:token), issuance: source.fetch(:issuance),
    )

    assert_equal 1, values.length
    assert_nil ClientSecretLookupQuery.call(secret: values.fetch(0))
    assert_not_nil source.fetch(:issuance).reload.presented_at
  end

  test "expired encrypted payload is rejected while its issuance authorization remains valid" do
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
    issuance.reload
    key = Rails.application.key_generator.generate_key(
      ClientSecretPresentationIssuer::PURPOSE, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"),
    )
    encryptor = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    payload = encryptor.decrypt_and_verify(issuance.encrypted_payload, purpose: ClientSecretPresentationIssuer::PURPOSE)
    expired_payload = encryptor.encrypt_and_sign(
      payload, purpose: ClientSecretPresentationIssuer::PURPOSE, expires_at: 1.second.ago,
    )
    issuance.update!(encrypted_payload: expired_payload)

    assert_operator issuance.expires_at, :>, Client.database_now
    assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
        ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)
      end
      assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
        ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
      end
    end
    assert_nil issuance.reload.presented_at
    assert_nil issuance.confirmed_at
    assert_nil ClientSecretLookupQuery.call(secret: payload.fetch("values").fetch(0))
  end

  test "unscoped or different browser cannot generate or present candidates" do
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
    other = ClientToken.create!(user: actor)
    [other, token].each do |browser|
      token.update!(last_step_up_at: nil) if browser == token
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::Denied) do
          ClientSecretPresentationIssuer.call!(actor_context: context, token: browser, issuance: issuance)
        end
      end
    end
    assert_nil issuance.reload.presented_at
  end
end
