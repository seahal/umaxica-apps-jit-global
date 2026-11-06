# frozen_string_literal: true

require "test_helper"

class ClientSecretPresentationIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @created_client_ids = []
  end

  teardown do
    client_ids = @created_client_ids
    client_refs = Client.where(id: client_ids).pluck(:public_id)
    ClientSecretAuditOutbox.where(client_ref: client_refs).delete_all
    ClientSecretCredential.where(client_id: client_ids).delete_all
    ClientSecretIssuance.where(client_id: client_ids).delete_all
    OpAppGrant.where(client_token_id: ClientToken.where(user_id: client_ids)).delete_all
    ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: client_ids).delete_all
    ClientDeviceSession.where(user_id: client_ids).delete_all
    ClientAuthorityLock.where(client_id: client_ids).delete_all
    ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
    ClientPreference.where(client_id: client_ids).destroy_all
    ClientAccount.where(user_id: client_ids).delete_all
    Client.where(id: client_ids).delete_all
  end

  test "a revoked device cannot prepare a Secret presentation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    token.device_session_record!.revoke!

    assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretPresentationIssuer::Denied) do
        ClientSecretPresentationIssuer.prepare!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.encrypted_payload
  end

  test "a superseded device token cannot deliver a prepared Secret presentation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    device = token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretPresentationIssuer::Denied) do
        ClientSecretPresentationIssuer.call!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.presented_at
    assert_predicate issuance.encrypted_payload, :present?
  end

  test "manual presentation generates exactly the reserved set once and storage declaration activates it" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
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
    assert_difference("ClientSecretCredential.count", 1) do
      ClientSecretPresentationIssuer.prepare!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
      values = ClientSecretPresentationIssuer.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )

      assert_equal 1, values.length
      assert_match ClientSecretCredential::SECRET_FORMAT, values.first
      assert_nil ClientSecretLookupQuery.call(client: actor, secret: values.first)
      assert_nil issuance.reload.encrypted_payload
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::AlreadyPresented) do
          ClientSecretPresentationIssuer.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
      end
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )

      assert_equal issuance.id, ClientSecretLookupQuery.call(client: actor, secret: values.first).issuance_id
    end
  end

  test "missing and corrupt payloads cannot replace candidates or activate an unpresented set" do
    [nil, "invalid encrypted payload"].each do |payload|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
      candidate_ids = ClientSecretCredential.where(issuance_id: issuance.id).pluck(:public_id)
      issuance.reload.update!(encrypted_payload: payload)

      assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
        assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
          ClientSecretPresentationIssuer.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
        if payload.nil?
          assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
            ClientSecretPresentationIssuer.prepare!(
              actor_context: context, token: token, issuance: issuance,
              step_up_evidence: evidence,
            )
          end
        end
        assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
      end
      assert_nil issuance.reload.presented_at
      assert_nil issuance.confirmed_at
      assert_equal candidate_ids, ClientSecretCredential.where(issuance_id: issuance.id).pluck(:public_id)

      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
        step_up_evidence: evidence,
      )

      assert_not_nil issuance.reload.canceled_at
      assert_nil issuance.encrypted_payload
      candidate = ClientSecretCredential.find_by!(public_id: candidate_ids.fetch(0))

      assert_nil candidate.confirmed_at
      assert_not_nil candidate.discard_at
      replacement = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
        step_up_evidence: evidence,
      )

      assert_not_equal issuance.id, replacement.id
      assert_equal 1, replacement.planned_count
    end
  end

  test "another issuance's authentic payload cannot present or confirm the target candidates" do
    operations =
      Array.new(2) do
        actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
        { context: context, token: token, issuance: issuance.reload, evidence: evidence }
      end
    source, target = operations
    target_issuance = target.fetch(:issuance)
    candidate_ids = ClientSecretCredential.where(issuance_id: target_issuance.id).pluck(:public_id)
    target_issuance.update!(encrypted_payload: source.fetch(:issuance).encrypted_payload)

    assert_no_difference ["ClientSecretCredential.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretPresentationIssuer::PayloadUnavailable) do
        ClientSecretPresentationIssuer.call!(
          actor_context: target.fetch(:context), token: target.fetch(:token), issuance: target_issuance,
          step_up_evidence: target.fetch(:evidence),
        )
      end
      assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
        ClientSecretStorageConfirmationCommitter.call!(
          actor_context: target.fetch(:context), token: target.fetch(:token), issuance: target_issuance,
          step_up_evidence: target.fetch(:evidence),
        )
      end
    end
    assert_nil target_issuance.reload.presented_at
    assert_nil target_issuance.confirmed_at
    assert_equal candidate_ids, ClientSecretCredential.where(issuance_id: target_issuance.id).pluck(:public_id)
    values = ClientSecretPresentationIssuer.call!(
      actor_context: source.fetch(:context), token: source.fetch(:token), issuance: source.fetch(:issuance),
      step_up_evidence: source.fetch(:evidence),
    )

    assert_equal 1, values.length
    assert_nil ClientSecretLookupQuery.call(client: source.fetch(:context).subject, secret: values.fetch(0))
    assert_not_nil source.fetch(:issuance).reload.presented_at
  end

  test "expired encrypted payload is rejected while its issuance authorization remains valid" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
        ClientSecretPresentationIssuer.call!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
      assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
        ClientSecretStorageConfirmationCommitter.call!(
          actor_context: context, token: token, issuance: issuance,
          step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.presented_at
    assert_nil issuance.confirmed_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: payload.fetch("values").fetch(0))
  end

  test "unscoped or different browser cannot generate or present candidates" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    other = ClientToken.create!(authentication_epoch: 0, user: actor)

    assert_no_difference("ClientSecretCredential.count") do
      assert_raises(ClientSecretPresentationIssuer::Denied) do
        ClientSecretPresentationIssuer.prepare!(
          actor_context: context, token: token, issuance: issuance, step_up_evidence: nil,
        )
      end
    end
    [evidence.with(sid: "foreign-grant"), evidence.with(aud: ["foreign-audience"])].each do |candidate_evidence|
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::Denied) do
          ClientSecretPresentationIssuer.call!(
            actor_context: context, token: token, issuance: issuance, step_up_evidence: candidate_evidence,
          )
        end
      end
    end
    assert_no_difference("ClientSecretCredential.count") do
      assert_raises(ClientSecretPresentationIssuer::Denied) do
        ClientSecretPresentationIssuer.prepare!(
          actor_context: context, token: other, issuance: issuance, step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.presented_at
  end
end
