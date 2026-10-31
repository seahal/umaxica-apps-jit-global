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
    device = token.device_session_record!
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: fallback.public_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    observed_spent = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)

        reader =
          Thread.new do
            ClientToken.connection_pool.with_connection do
              ClientToken.find(token.id).last_step_up_at.nil?
            end
          end
        observed_spent = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end

    assert observed_spent, "a separate OP connection must see invalidation before the Zenith write"
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_nil token.reload.last_step_up_at
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    credential&.delete
    fallback&.delete
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
    device = token.device_session_record!
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: fallback.public_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    original_step_up_at = token.reload.last_step_up_at
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
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end

    assert ticket_write_seen
    assert_not source_write_seen
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_equal original_step_up_at, token.reload.last_step_up_at
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    credential&.delete
    fallback&.delete
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
    device = token.device_session_record!
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true, last_step_up_credential_ref: fallback.public_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    observed_spent = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"client_passkey_audit_outboxes"/i)

        reader =
          Thread.new do
            ClientToken.connection_pool.with_connection do
              ClientToken.find(token.id).last_step_up_at.nil?
            end
          end
        observed_spent = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith audit failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end

    assert observed_spent
    assert_equal ClientPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_not ClientPasskeyAuditOutbox.exists?(external_id: credential.external_id, event_type: "passkey.removed")
    assert_nil token.reload.last_step_up_at
    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_equal ClientPasskeyStatus::ACTIVE, credential.reload.status_id
  ensure
    ClientChronicle.where(subject_type: "Client", subject_id: actor.id.to_s).delete_all if actor
    ClientPasskeyAuditOutbox.where(external_id: credential.external_id).delete_all if credential
    credential&.delete
    fallback&.delete
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
    device = token.device_session_record!
    token.update!(
      last_step_up_at: OperatorToken.database_now, last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org", last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true, last_step_up_credential_ref: fallback.external_id,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.external_id,
    )
    observed_spent = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"operator_passkey_audit_outboxes"/i)

        reader =
          Thread.new do
            OperatorToken.connection_pool.with_connection do
              OperatorToken.find(token.id).last_step_up_at.nil?
            end
          end
        observed_spent = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith audit failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end

    assert observed_spent
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_not OperatorPasskeyAuditOutbox.exists?(external_id: credential.external_id, event_type: "passkey.removed")
    assert_nil token.reload.last_step_up_at
    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
  ensure
    OperatorChronicle.where(subject_type: "Operator", subject_id: actor.id.to_s).delete_all if actor
    OperatorPasskeyAuditOutbox.where(external_id: credential.external_id).delete_all if credential
    credential&.delete
    second&.delete
    fallback&.delete
    token&.delete
    device&.delete
    OperatorAuthorityLock.where(operator_id: actor.id).delete_all if actor
    actor&.delete
  end
end
