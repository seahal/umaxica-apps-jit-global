# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityTotpNameCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(joined savepoint).each do |nesting|
    test "an outer OP #{nesting} transaction cannot authorize a TOTP rename" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      device = token.device_session
      credential = ClientTotpCredential.create_for_user!(
        user: actor, private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
        last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
      )
      evidence_at = token.reload.last_step_up_at
      OpBaseAppRecord.transaction do
        OpBaseAppRecord.transaction(requires_new: nesting == "savepoint") do
          assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
            IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title")
          end
        end
        raise ActiveRecord::Rollback
      end

      assert_nil credential.reload.title
      assert_equal evidence_at, token.reload.last_step_up_at
    ensure
      credential&.delete
      token&.delete
      device&.delete
      actor&.delete
    end
  end

  test "OP consumption commits before a failed Zenith TOTP rename" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
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
      assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title")
      end
    end

    assert observed_spent, "a separate OP connection must observe consumption before Zenith fails"
    assert_nil credential.reload.title
    assert_nil token.reload.last_step_up_at
  ensure
    credential&.delete
    token&.delete
    device&.delete
    actor&.delete
  end
end
