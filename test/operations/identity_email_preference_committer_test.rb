# frozen_string_literal: true

require "test_helper"

class IdentityEmailPreferenceCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "unbound and other-email Step-Up cannot change an Email preference" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = ClientEmail.create!(
      user: actor, address: "first-target-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    second = ClientEmail.create!(
      user: actor, address: "second-target-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    first.finalize_binding!
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email: first, preferences: { "promotional" => "0" })
    end
    token.update!(last_step_up_resource_ref: first.public_id)

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email: second, preferences: { "promotional" => "0" })
    end
    assert_predicate first.reload, :promotional?
    assert_predicate second.reload, :promotional?
    assert_predicate token.reload.last_step_up_at, :present?
    IdentityEmailPreferenceCommitter.call!(actor:, token:, email: first, preferences: { "promotional" => "0" })

    assert_not first.reload.promotional?
    assert_nil token.reload.last_step_up_at
  end

  test "a superseded device token cannot authorize an Email preference change" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "superseded-device-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
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
    device = token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "promotional" => "0" })
    end
    assert_predicate email.reload, :promotional?
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a revoked device cannot authorize an Email preference change" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "revoked-device-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
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
    token.device_session_record!.revoke!

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "promotional" => "0" })
    end
    assert_predicate email.reload, :promotional?
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a failed OP consumption sees the old email preference and preserves it" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "ordering-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
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

    assert_predicate email.reload, :promotional?
    observed = nil
    failure =
      lambda do |**|
        observed = ClientEmail.find(email.id).promotional?
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "injected OP consumption failure"
      end

    token.stub(:consume_step_up_evidence!, failure) do
      assert_raises(IdentityEmailPreferenceCommitter::Denied) do
        IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "promotional" => "0" })
      end
    end

    assert observed
    assert_predicate email.reload, :promotional?
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a Zenith write failure after OP consumption keeps the email unchanged and spends evidence" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "write-failure-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
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
    failed = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_emails"/i)

        failed = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
        IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "promotional" => "0" })
      end
    end

    assert failed
    assert_predicate email.reload, :promotional?
    assert_nil token.reload.last_step_up_at
  end

  test "a changed preference spends Step-Up once and a no-op keeps a new Step-Up" do
    actor, token, email = authorized_email

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "1" },
    )

    assert_not email.reload.promotional?
    assert_predicate email, :notifiable?
    assert_nil token.reload.last_step_up_at
    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token: token.reload, email:, preferences: { "promotional" => "1" },
      )
    end
    assert_not email.reload.promotional?

    grant_email_step_up!(actor, token.reload, email)
    no_op_evidence = token.reload.attributes
    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "1" },
    )

    assert_equal no_op_evidence, token.reload.attributes
  end

  test "locked preferences, unsupported keys and foreign email retain evidence" do
    actor, token, email = authorized_email
    email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    grant_email_step_up!(actor, token, email)
    original = [email.reload.promotional, email.notifiable]
    evidence = token.reload.attributes

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "0" },
    )

    assert_equal original, [email.reload.promotional, email.notifiable]
    assert_equal evidence, token.reload.attributes
    assert_raises(ArgumentError) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "unexpected" => "x" })
    end

    foreign_actor, _foreign_token, = authorized_email
    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor: foreign_actor, token:, email:, preferences: { "promotional" => "0" },
      )
    end
    assert_equal evidence, token.reload.attributes
  end

  private

  def authorized_email
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "preferences-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    grant_email_step_up!(actor, token, email)
    [actor, token, email]
  end

  def grant_email_step_up!(_actor, token, email)
    now = ClientToken.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: email.public_id,
    )
  end
end
