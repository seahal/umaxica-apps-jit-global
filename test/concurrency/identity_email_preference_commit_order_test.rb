# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityEmailPreferenceCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "OP consumption commits before a failed Zenith preference update" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session
    email = ClientEmail.create!(
      user: actor, address: "commit-order-#{SecureRandom.hex(12)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: email.public_id,
    )
    observed_spent = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_emails"/i)

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
      assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
        IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "promotional" => "0" })
      end
    end

    assert observed_spent, "a separate OP connection must observe consumption before Zenith fails"
    assert_predicate email.reload, :promotional?
    assert_nil token.reload.last_step_up_at
  ensure
    email&.delete
    token&.delete
    device&.delete
    actor&.delete
  end
end
