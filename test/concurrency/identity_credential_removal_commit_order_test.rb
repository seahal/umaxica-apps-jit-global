# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityCredentialRemovalCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "OP invalidation commits before a failed Zenith TOTP removal" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    fallback = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = OpBaseAppRecord.database_now
    token.update!(
      root_login_established_at: evidence_now, established_authentication_method: "passkey",
      last_step_up_method: "passkey",
    )
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    observed_invalidation = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)

        reader =
          Thread.new do
            ClientToken.connection_pool.with_connection do
              ClientToken.find(token.id).last_step_up_method.nil?
            end
          end
        observed_invalidation = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityCredentialRemovalCommitter::DependencyFailure) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: evidence,
        )
      end
    end

    assert observed_invalidation, "a separate OP connection must see invalidation before the Zenith write"
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_nil token.reload.last_step_up_method
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    credential&.delete
    fallback&.delete
    grant&.delete
    token&.delete
    device&.delete
    ClientAuthorityLock.where(client_id: actor.id).delete_all if actor
    actor&.delete
  end

  test "OP invalidation failure leaves the TOTP and Step-Up unchanged" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    fallback = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = OpBaseAppRecord.database_now
    token.update!(
      root_login_established_at: evidence_now, established_authentication_method: "passkey",
      last_step_up_method: "passkey",
    )
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    original_attribution = token.reload.last_step_up_method
    ticket_write_seen = false
    source_write_seen = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        sql = event.fetch(:sql)
        source_write_seen = true if sql.match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)
        next unless sql.match?(/\A\s*UPDATE\s+"client_tokens"/i)

        ticket_write_seen = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Ticket write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityCredentialRemovalCommitter::DependencyFailure) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: evidence,
        )
      end
    end

    assert ticket_write_seen
    assert_not source_write_seen
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_equal original_attribution, token.reload.last_step_up_method
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    credential&.delete
    fallback&.delete
    grant&.delete
    token&.delete
    device&.delete
    ClientAuthorityLock.where(client_id: actor.id).delete_all if actor
    actor&.delete
  end

  test "Passkey audit failure preserves the key after OP invalidation commits" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    fallback = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
    )
    credential = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "removed-key", uv_verified_at: Time.current,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = OpBaseAppRecord.database_now
    token.update!(
      root_login_established_at: evidence_now, established_authentication_method: "passkey",
      last_step_up_method: "passkey",
    )
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    observed_invalidation = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"client_passkey_audit_outboxes"/i)

        reader =
          Thread.new do
            ClientToken.connection_pool.with_connection do
              ClientToken.find(token.id).last_step_up_method.nil?
            end
          end
        observed_invalidation = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith audit failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityCredentialRemovalCommitter::DependencyFailure) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: evidence,
        )
      end
    end

    assert observed_invalidation
    assert_equal ClientPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_not ClientPasskeyAuditOutbox.exists?(external_id: credential.external_id, event_type: "passkey.removed")
    assert_nil token.reload.last_step_up_method
    assert_equal evidence.jti, grant.reload.oidc_jti
    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: credential, current_session: token, step_up_evidence: evidence,
    )
    assert_not ClientPasskey.exists?(id: credential.id)
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    ClientPasskeyAuditOutbox.where(external_id: credential.external_id).delete_all if credential
    credential&.delete
    fallback&.delete
    grant&.delete
    token&.delete
    device&.delete
    ClientAuthorityLock.where(client_id: actor.id).delete_all if actor
    actor&.delete
  end

  test "ORG Passkey audit failure preserves the key after OP invalidation commits" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    fallback = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
    )
    second = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "second-key", uv_verified_at: Time.current,
    )
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "removed-key", uv_verified_at: Time.current,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    evidence_now = OpBaseOrgRecord.database_now
    token.update!(
      root_login_established_at: evidence_now, established_authentication_method: "passkey",
      last_step_up_method: "passkey",
    )
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    observed_invalidation = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"operator_passkey_audit_outboxes"/i)

        reader =
          Thread.new do
            OperatorToken.connection_pool.with_connection do
              OperatorToken.find(token.id).last_step_up_method.nil?
            end
          end
        observed_invalidation = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith audit failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityCredentialRemovalCommitter::DependencyFailure) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: evidence,
        )
      end
    end

    assert observed_invalidation
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_not OperatorPasskeyAuditOutbox.exists?(external_id: credential.external_id, event_type: "passkey.removed")
    assert_nil token.reload.last_step_up_method
    assert_equal evidence.jti, grant.reload.oidc_jti
    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: credential, current_session: token, step_up_evidence: evidence,
    )
    assert_not OperatorPasskey.exists?(id: credential.id)
  ensure
    OperatorChronicle.where(subject_type: "Operator", subject_id: actor.id.to_s).delete_all if actor
    OperatorPasskeyAuditOutbox.where(external_id: credential.external_id).delete_all if credential
    credential&.delete
    second&.delete
    fallback&.delete
    grant&.delete
    token&.delete
    device&.delete
    OperatorAuthorityLock.where(operator_id: actor.id).delete_all if actor
    actor&.delete
  end

  %w(joined savepoint).each do |nesting|
    test "an outer OP #{nesting} transaction cannot remove a TOTP credential" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      fallback = actor.client_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
      )
      credential = ClientTotpCredential.create_for_user!(
        user: actor, private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      evidence_now = OpBaseAppRecord.database_now
      token.update!(
        root_login_established_at: evidence_now, established_authentication_method: "passkey",
        last_step_up_method: "passkey",
      )
      token.rotate_refresh_token!(now: evidence_now)
      device = token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
      )
      grant.issue_refresh_token!(now: evidence_now)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      original_attribution = token.reload.last_step_up_method

      OpBaseAppRecord.transaction do
        OpBaseAppRecord.transaction(requires_new: nesting == "savepoint") do
          assert_raises(IdentityCredentialRemovalCommitter::TransactionConflict) do
            IdentityCredentialRemovalCommitter.call!(
              actor: actor, credential: credential, current_session: token,
              step_up_evidence: evidence,
            )
          end
        end
        raise ActiveRecord::Rollback
      end

      assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
      assert_equal original_attribution, token.reload.last_step_up_method
      assert_equal evidence.jti, grant.reload.oidc_jti
    ensure
      ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
      credential&.delete
      fallback&.delete
      grant&.delete
      token&.delete
      device&.delete
      ClientAuthorityLock.where(client_id: actor.id).delete_all if actor
      actor&.delete
    end
  end

  %w(joined savepoint).each do |nesting|
    test "an outer OP #{nesting} transaction cannot remove an ORG passkey" do
      actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      fallback = actor.staff_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "fallback-key", uv_verified_at: Time.current,
      )
      credential = actor.staff_passkeys.create!(
        webauthn_id: SecureRandom.uuid, public_key: "removed-key", uv_verified_at: Time.current,
      )
      token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
      evidence_now = OpBaseOrgRecord.database_now
      token.update!(
        root_login_established_at: evidence_now, established_authentication_method: "passkey",
        last_step_up_method: "passkey",
      )
      token.rotate_refresh_token!(now: evidence_now)
      device = token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-org-ww")
      grant = OpOrgGrant.create!(
        authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
      )
      grant.issue_refresh_token!(now: evidence_now)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      original_attribution = token.reload.last_step_up_method

      OpBaseOrgRecord.transaction do
        OpBaseOrgRecord.transaction(requires_new: nesting == "savepoint") do
          assert_raises(IdentityCredentialRemovalCommitter::TransactionConflict) do
            IdentityCredentialRemovalCommitter.call!(
              actor: actor, credential: credential, current_session: token,
              step_up_evidence: evidence,
            )
          end
        end
        raise ActiveRecord::Rollback
      end

      assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
      assert_equal original_attribution, token.reload.last_step_up_method
      assert_equal evidence.jti, grant.reload.oidc_jti
    ensure
      OperatorChronicle.where(subject_type: "Operator", subject_id: actor.id.to_s).delete_all if actor
      OperatorPasskeyAuditOutbox.where(external_id: credential.external_id).delete_all if credential
      credential&.delete
      fallback&.delete
      grant&.delete
      token&.delete
      device&.delete
      OperatorAuthorityLock.where(operator_id: actor.id).delete_all if actor
      actor&.delete
    end
  end
end
